#!/bin/csh -f
# ============================================================================
# 运行 Cadence JasperGold (FPV) —— INT8 MAC 示例
# 用法：在 formal/jaspergold 目录下执行  ./run_jg.csh
# ============================================================================

# 1) 环境由工程根目录下的 sourceme 提供（模块 / license / 路径）
#    请先在工程根目录执行：  source sourceme

# 2) 回到工程根目录
cd ../..

# 3) 运行 JasperGold，执行 formal/jaspergold/jg.tcl
jg -batch formal/jaspergold/jg.tcl