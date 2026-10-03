//==============================================================================
// mac_int8.sv
// INT8 饱和乘累加单元 —— DT82S_Pro NPU NE 基础算子 Formal 验证示例 DUT
//
// 功能：acc = acc + a*b（有符号乘累加），acc_clr 清零累加器。
//   - SATURATE=1 : 每步累加结果饱和到 [-2^(W-1), 2^(W-1)-1]，溢出置 ovf
//   - SATURATE=0 : 每步累加结果按 2^W 回绕，ovf 恒为 0
//   - 1 级流水：输入握手 (in_valid/in_ready)，输出握手 (out_valid/out_ready)
//
// 时序：本拍 accept(=in_valid&in_ready) 时，下一拍 result/ovf 更新、out_valid=1；
//       下游未就绪(!out_ready) 时结果保持，不丢数据。
//===========================================================================
module mac_int8 #(
  parameter int  ACC_WIDTH = 32,   // 累加器位宽
  parameter bit  SATURATE  = 1'b1  // 1=饱和  0=回绕
)(
  input  logic                        clk,
  input  logic                        rst_n,        // 低有效异步复位

  // 输入握手
  input  logic                        in_valid,
  output logic                        in_ready,
  input  logic signed [7:0]           a,            // INT8 有符号乘数 A
  input  logic signed [7:0]           b,            // INT8 有符号乘数 B
  input  logic                        acc_clr,      // 清零累加器（与输入同拍生效）

  // 输出握手
  output logic                        out_valid,
  input  logic                        out_ready,
  output logic signed [ACC_WIDTH-1:0] result,       // 累加结果（有符号）
  output logic                        ovf            // 本步饱和溢出标志
);

  localparam int SUM_WIDTH = ACC_WIDTH + 2;

  localparam logic signed [ACC_WIDTH-1:0] INT_MAX = {1'b0, {(ACC_WIDTH-1){1'b1}}}; // 2^(W-1)-1
  localparam logic signed [ACC_WIDTH-1:0] INT_MIN = {1'b1, {(ACC_WIDTH-1){1'b0}}}; // -2^(W-1)     
  
  // 有符号乘积：8x8 最多 16bit，扩到 18bit 防溢出
  logic signed [17:0] product;

  // 累加器（有符号）与内部控制
  logic signed [ACC_WIDTH-1:0] acc;
  logic                        ovf_r;
  logic                        accept;

  // 扩展位宽求和，检测是否越界
  logic signed [SUM_WIDTH-1:0] sum_ext;
  logic signed [ACC_WIDTH-1:0] acc_nxt;
  logic                        ovf_comb;
  
  assign product = $signed(a) * $signed(b);

  // 无待发结果，或下游就绪时，可以接收新数据（单级流水，无 skid）
  assign in_ready = (!out_valid) || out_ready;
  assign accept   = in_valid && in_ready;

  // 求和：acc_clr 时从 0 开始，否则在 acc 上累加；乘积符号扩展到 SUM_WIDTH
  assign sum_ext  = $signed(acc_clr ? {ACC_WIDTH{1'b0}} : acc)
                  + $signed({{(SUM_WIDTH-18){product[17]}}, product});
                  
  always_comb begin
    if (sum_ext > $signed({{(SUM_WIDTH-ACC_WIDTH){INT_MAX[ACC_WIDTH-1]}}, INT_MAX})) begin
      acc_nxt  = INT_MAX;
      ovf_comb = 1'b1;
    end else if (sum_ext < $signed({{(SUM_WIDTH-ACC_WIDTH){INT_MIN[ACC_WIDTH-1]}}, INT_MIN})) begin
      acc_nxt  = INT_MIN;
      ovf_comb = 1'b1;
    end else begin
      acc_nxt  = sum_ext[ACC_WIDTH-1:0];
      ovf_comb = 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc       <= '0;
      ovf_r     <= 1'b0;
      out_valid <= 1'b0;
    end else begin
      if (accept) begin
        acc   <= SATURATE ? acc_nxt : sum_ext[ACC_WIDTH-1:0];
        ovf_r <= SATURATE ? ovf_comb : 1'b0;
      end
      out_valid <= accept || (out_valid && !out_ready);
    end
  end

  assign result = acc;
  assign ovf    = ovf_r;

endmodule