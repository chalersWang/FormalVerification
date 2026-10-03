#!/bin/csh -f
# ============================================================================
# 运行 Synopsys VC Formal (FPV) —— INT8 MAC 示例
# 用法：在 formal/vc_formal 目录下执行  ./run_vcformal.csh
# ============================================================================

# 1) 环境由工程根目录下的 sourceme 提供（模块 / license / 路径）
#    请先在工程根目录执行：  source sourceme

# 2) 回到工程根目录（filelist / RTL 路径均相对工程根）
cd ../..

# 3) 运行 VC Formal，执行 formal/vc_formal/run.tcl
#    -verdi : 便于在 Verdi 中打开/调试反例（CEX）
vcf -f formal/vc_formal/run.tcl -verdi