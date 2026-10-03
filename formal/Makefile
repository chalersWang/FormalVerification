# ============================================================================
# DT82S_Pro NPU formal 示例 —— 顶层入口
# 用法（在工程根目录执行）：
#   make sim     编译并运行 VCS 仿真
#   make vcf     运行 Synopsys VC Formal (FPV)
#   make jg      运行 Cadence JasperGold (FPV)
#   make all     仿真 + 两套 formal
#   make clean   清理
# ============================================================================

sim:
	$(MAKE) -C sim all

vcf:
	cd formal/vc_formal && ./run_vcformal.csh

jg:
	cd formal/jaspergold && ./run_jg.csh

all: sim vcf jg

clean:
	$(MAKE) -C sim clean
	rm -rf formal/vc_formal/vcst_* formal/vc_formal/vcf.log formal/vc_formal/*.log \
	       formal/vc_formal/simv* formal/vc_formal/csrc \
	       formal/jaspergold/jgproject formal/jaspergold/jg_session* formal/jaspergold/*.log

.PHONY: sim vcf jg all clean