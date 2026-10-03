//==============================================================================
// mac_int8_sva.sv
// mac_int8 的 SVA 断言 + 参考模型（通过 bind 方式接入，不改动 DUT）
//
// 核心思想：
//   用一个 64bit 真值参考模型，逐周期与 DUT 比较累加结果与溢出标志。
//   仿真只能抽样验证，formal 工具则对"所有输入序列"做穷举证明。
//==============================================================================
module mac_int8_sva #(
    parameter int ACC_WIDTH = 32,
    parameter bit SATURATE  = 1'b1
)(
    input logic                        clk,
    input logic                        rst_n,
    input logic                        in_valid,
    input logic                        in_ready,
    input logic signed [7:0]           a,
    input logic signed [7:0]           b,
    input logic                        acc_clr,
    input logic                        out_valid,
    input logic                        out_ready,
    input logic signed [ACC_WIDTH-1:0] result,
    input logic                        ovf
);

localparam longint MAX_VAL = (64'sd1 << (ACC_WIDTH-1)) - 1; // 2^(W-1)-1
localparam longint MIN_VAL = -(64'sd1 << (ACC_WIDTH-1));    // -2^(W-1)

localparam logic signed [ACC_WIDTH-1:0] MAX_I = {1'b0, {(ACC_WIDTH-1){1'b1}}};
localparam logic signed [ACC_WIDTH-1:0] MIN_I = {1'b1, {(ACC_WIDTH-1){1'b0}}};

logic               accept;
logic signed [63:0] ref_acc;   // 参考累加器（每步与 DUT 相同地饱和/回绕）
logic signed [63:0] ref_sum;
logic               ref_ovf;

assign accept  = in_valid && in_ready;
assign ref_sum = (acc_clr ? 64'sd0 : ref_acc) + ($signed(a) * $signed(b));

//------------------------------------------------------------------------------
// 参考模型：64bit 真值累加，饱和逻辑与 DUT 一一对应
//------------------------------------------------------------------------------
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    ref_acc <= '0;
    ref_ovf <= 1'b0;
  end else if (accept) begin
    if (SATURATE) begin
      if (ref_sum > MAX_VAL) begin
        ref_acc <= MAX_VAL; ref_ovf <= 1'b1;
      end else if (ref_sum < MIN_VAL) begin
        ref_acc <= MIN_VAL; ref_ovf <= 1'b1;
      end else begin
        ref_acc <= ref_sum; ref_ovf <= 1'b0;
      end
    end else begin
      ref_acc <= $signed(ref_sum[ACC_WIDTH-1:0]);
      ref_ovf <= 1'b0;
    end
  end
end

//------------------------------------------------------------------------------
// 断言（全部为 should-prove 属性，formal 工具对这些属性做穷举证明）
//------------------------------------------------------------------------------

// A1 复位解除后，累加器/溢出/输出有效 均为初始值
a_reset: assert property (@(posedge clk) $rose(rst_n)
             |-> (result == '0) && !ovf && !out_valid);

// A2 核心等价：DUT 累加结果 == 参考模型（任意输入序列）
a_mac_equiv: assert property (@(posedge clk) disable iff (!rst_n)
             (result == ref_acc[ACC_WIDTH-1:0]));

// A3 溢出标志等价
a_ovf_equiv: assert property (@(posedge clk) disable iff (!rst_n)
             (ovf == ref_ovf));

// A4 饱和边界：溢出时结果必为 MAX 或 MIN
a_ovf_bounds: assert property (@(posedge clk) disable iff (!rst_n)
             (ovf |-> (result == MAX_I) || (result == MIN_I)));

// A5 握手：无数据丢失（背压时结果与 valid 均保持）
a_no_drop: assert property (@(posedge clk) disable iff (!rst_n)
             ((out_valid && !out_ready) |=> out_valid && $stable(result)));

// A6 握手：accept 后下一拍输出有效
a_out_valid_after_accept: assert property (@(posedge clk) disable iff (!rst_n)
             (accept |=> out_valid));

// A7 累加器仅在 accept 时更新
a_result_latch: assert property (@(posedge clk) disable iff (!rst_n)
             (!accept |=> $stable(result)));

//------------------------------------------------------------------------------
// 覆盖点（证明可及性：确认这些状态可达，指导约束/激励）
//------------------------------------------------------------------------------
c_ovf_pos:    cover property (@(posedge clk) disable iff (!rst_n) (ovf && result == MAX_I));
c_ovf_neg:    cover property (@(posedge clk) disable iff (!rst_n) (ovf && result == MIN_I));
c_back_to_back:cover property (@(posedge clk) disable iff (!rst_n)
                (in_valid && in_ready && out_valid && out_ready));
c_clr:        cover property (@(posedge clk) disable iff (!rst_n) (acc_clr && accept));

endmodule

// 绑定到 DUT（参数需与 mac_int8 实例保持一致）
bind mac_int8 mac_int8_sva #(.ACC_WIDTH(32), .SATURATE(1)) u_mac_sva (.*);
