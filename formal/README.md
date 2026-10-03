# DT82S_Pro NPU — Formal 验证示例工程（INT8 MAC 乘累加单元）

本工程提供一个**最小但完整**的 formal（形式化）验证示例，用于演示 NPU NE 模块
基础算子（乘累加 MAC）的验证流程。同一套 RTL + SVA，可同时跑 **Synopsys VC Formal**
与 **Cadence JasperGold** 两套工具，并配有一个 VCS 仿真 testbench 用于功能回归与断言交叉验证。

## 一、示例工程说明

### 1.1 被测对象（DUT）

`rtl/mac_int8.sv` — 一个 INT8 有符号**饱和乘累加单元**：

```
acc = acc + a * b            （有符号，acc_clr 清零）
```

- `ACC_WIDTH=32`：累加器位宽（可参数化）
- `SATURATE=1`：每步累加结果饱和到 `[-2^31, 2^31-1]`，越界时置 `ovf`
- 1 级流水，标准 valid/ready 握手，支持背压（下游未就绪时结果保持，不丢数据）

| 端口 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `clk` / `rst_n` | in | 1 | 时钟 / 低有效异步复位 |
| `in_valid` / `in_ready` | in/out | 1 | 输入握手 |
| `a` / `b` | in | 8 | INT8 有符号乘数 |
| `acc_clr` | in | 1 | 累加器清零（与输入同拍生效） |
| `out_valid` / `out_ready` | out/in | 1 | 输出握手 |
| `result` | out | 32 | 累加结果（有符号） |
| `ovf` | out | 1 | 本步饱和溢出标志 |

**时序**：本拍 `accept(=in_valid & in_ready)` 成立 → 下一拍 `result`/`ovf` 更新、`out_valid=1`；
`out_valid=1` 且 `out_ready=0` 时结果与 valid 均保持（背压不丢数据）。

### 1.2 断言（`rtl/mac_int8_sva.sv`）

SVA 以 **bind** 方式附着到 DUT，不改动 RTL。核心是引入一个 **64bit 真值参考模型**，
逐周期与 DUT 比较，从而把"功能正确性"转成可形式化证明的等价性属性：

| 编号 | 属性 | 含义 |
|------|------|------|
| A1 | `a_reset` | 复位解除后累加器/溢出/valid 为初值 |
| A2 | `a_mac_equiv` | **DUT 结果 == 参考模型（任意输入序列）** |
| A3 | `a_ovf_equiv` | 溢出标志与参考模型一致 |
| A4 | `a_ovf_bounds` | 溢出时结果必为 MAX 或 MIN |
| A5 | `a_no_drop` | 背压时结果不丢、valid 保持 |
| A6 | `a_out_valid_after_accept` | accept 后下一拍输出有效 |
| A7 | `a_result_latch` | 累加器仅在 accept 时更新 |
| C1~C4 | `c_*` | 覆盖点：正/负溢出、背靠背、清零（证明可及性） |

仿真只能对输入**抽样**验证；formal 工具则对"所有可能的输入序列"做**穷举证明**——这是本示例要传达的核心。

### 1.3 目录结构

```
format/
├── README.md              # 本说明
├── Makefile               # 顶层入口 (make sim / vcf / jg)
├── rtl/
│   ├── mac_int8.sv        # DUT
│   └── mac_int8_sva.sv    # SVA 断言 + 参考模型 + bind
├── tb/
│   └── tb_mac_int8.sv     # VCS 仿真 testbench（自校验）
├── flist/
│   ├── sim.f              # 仿真文件列表
│   └── formal.f           # formal 文件列表
├── sim/
│   └── Makefile           # VCS 仿真脚本
├── formal/
│   ├── vc_formal/
│   │   ├── run.tcl        # VC Formal FPV 流程
│   │   └── run_vcformal.csh  # 一键运行
│   └── jaspergold/
│       ├── jg.tcl         # JasperGold FPV 流程
│       └── run_jg.csh     # 一键运行
└── doc/
    └── formal_flow.md     # formal 验证执行流程（详细）
```

## 二、示例工程仿真脚本

### 2.1 环境

| 工具 | 模块 | 版本 |
|------|------|------|
| VCS | `vcs` | 2023.12-C |
| Verdi | `verdi` | 2023.12-C |
| VC Formal | `vc_static` | 2021.09（`vcf`） |
| JasperGold | `jasper` | 2021.12p002-C（`jg`） |

> 所有环境变量（模块 / license / 路径）统一由工程根目录下的 **`sourceme`** 配置，
> 依据项目 `code/verification/it/npu_it/sourceme` 与 `code/bin/setup.csh` 裁剪而来。

```csh
# 首次（每个新终端）在工程根目录加载环境
source sourceme
```

### 2.2 运行仿真

```bash
source sourceme            # 加载环境

# 方式一：顶层 Makefile
make sim

# 方式二：进入 sim 目录
cd sim
make all          # 编译 + 运行
# 或分步：
make comp         # 只编译 (vcs)
make run          # 只运行 (./simv)
```

仿真覆盖复位、基础乘累加、负值、**正/负饱和溢出**（各 13 万拍显式打满累加器触发饱和）、
以及 2 万拍随机+背压。自校验通过时打印：

```
[PASS] INT8 MAC 仿真全部通过 (err_cnt=0)
```

## 三、运行 Formal 验证

```bash
source sourceme            # 加载环境

# Synopsys VC Formal (FPV)
make vcf
# 或： cd formal/vc_formal && ./run_vcformal.csh

# Cadence JasperGold (FPV)
make jg
# 或： cd formal/jaspergold && ./run_jg.csh
```

- 两套工具都证明 `mac_int8_sva.sv` 中的 7 条断言（A1~A7），并尝试命中 4 个覆盖点。
- 全部属性应为 **proven**，覆盖点应 **hit**。
- 详细流程、结果解读与反例调试见 [`doc/formal_flow.md`](doc/formal_flow.md)。

## 四、注意事项

1. **参数一致性**：`mac_int8_sva.sv` 末尾的 `bind` 里 `.ACC_WIDTH(32), .SATURATE(1)`
   需与 DUT 实例参数一致；若修改 DUT 参数，请同步修改 bind。
2. **路径约定**：所有 filelist / RTL 路径均相对**工程根目录**；各脚本内部已 `cd` 到根目录，
   请按"在脚本所在目录执行"的方式运行。
3. 仿真 filelist（`sim.f`）**不含** SVA 文件；formal filelist（`formal.f`）含 SVA——二者刻意分离，
   分别验证"功能回归"与"断言可形式化证明"。