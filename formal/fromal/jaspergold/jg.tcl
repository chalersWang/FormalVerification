# ============================================================================
# JasperGold (FPV) 流程 —— INT8 MAC 示例
# 由 run_jg.csh 调用：  jg -batch formal/jaspergold/jg.tcl
# ============================================================================

# 1) 分析（编译）设计 + SVA（mac_int8_sva.sv 内含 bind）
analyze -sv09 \
    rtl/mac_int8.sv \
    rtl/mac_int8_sva.sv

# 2) 精化设计，指定顶层（bind 自动附着到 mac_int8 内部）
elaborate -top mac_int8

# 3) 时钟与复位（复位低有效）
clock clk
reset !rst_n

# 4) 运行形式属性验证：证明全部断言
prove -all

# 5) 输出证明结果摘要
report -ab -this_run