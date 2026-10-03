# ============================================================================
# VC Formal (FPV) 流程 —— INT8 MAC 示例
# 由 run_vcformal.csh 调用：  vcf -f formal/vc_formal/run.tcl -verdi
# 命令名与官方示例 doc/vcst/examples/FPV 一致。
# ============================================================================

# 1) 应用模式：FPV（Formal Property Verification）
set_fml_appmode FPV

set design mac_int8

# 2) 编译设计 + SVA（flist/formal.f 内含 mac_int8.sv 与 mac_int8_sva.sv，含 bind）
read_file -top $design -format sverilog -sva \
          -vcs {-f flist/formal.f}

# 3) 时钟定义（周期 100 时间单位，初相 0）
create_clock clk -period 100 -initial 0

# 4) 复位定义（低有效）
create_reset rst_n -low

# 5) 跑一段仿真使设计离开复位态，并保存复位状态
sim_run -stable
sim_save_reset

# 6) 单属性证明时限（墙钟时间）
set_fml_var fml_max_time 5M

# 7) 运行形式属性验证（block 模式）
check_fv -block