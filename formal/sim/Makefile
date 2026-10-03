# ============================================================================
# VCS 仿真脚本 —— INT8 MAC 示例
# 用法：在 sim 目录下执行
#   make comp   只编译
#   make run    只运行（需先 make comp）
#   make all    编译 + 运行
#   make gui    编译并打开 Verdi/DVE 调试
#   make clean  清理
#
# 说明：所有 filelist / RTL 路径均相对工程根目录，编译在工程根目录下进行。
# ============================================================================
VCS   = vcs
TOP   = tb_mac_int8
ROOT  = ..
FLIST = flist/sim.f

comp:
	cd $(ROOT) && $(VCS) -full64 -sverilog -debug_access+all \
	    -f $(FLIST) -top $(TOP) -l sim/comp.log -o sim/simv

run:
	cd $(ROOT) && ./sim/simv -l sim/run.log
	
all: comp run

gui:
	cd $(ROOT) && $(VCS) -full64 -sverilog -debug_access+all \
	    -f $(FLIST) -top $(TOP) -l sim/comp.log -o sim/simv -gui

clean:
	rm -rf simv simv.daidir csrc ucli.key *.log *.vcd *.fsdb novas.* *.vpd

.PHONY: comp run all gui clean