# Formal 验证执行流程（DT82S_Pro NPU 基础算子）

本文以本工程 `mac_int8` 为例，给出形式化属性验证（FPV, Formal Property Verification）
的标准执行流程，覆盖 Synopsys VC Formal 与 Cadence JasperGold 两套工具。
文中命令均来自工具官方示例（VC Formal 取自 `vc_static` 安装目录
`doc/vcst/examples/FPV`），已按本工程目录适配。

## 0. 什么是 FPV 与为什么要做

- 仿真（dynamic）：对**特定输入序列**验证，覆盖率受限，边界条件难打满（例如本例正/负饱和需 13 万拍才触发一次）。
- 形式化（formal）：用数学方法对**所有输入序列**做穷举，证明断言永远成立；若失败，工具给出一条**反例（CEX）**波形，可直接定位缺陷。

FPV 尤其适合：数据通路等价性（如本例乘累加器 vs 参考模型）、握手协议、控制状态机、溢出/边界条件——这些正是 NPU 基础算子与接口最易出错处。

## 1. 通用流程（六步）

```
┌ 1 准备    ┐   →  ┌ 2 编译   ┐   →  ┌ 3 时钟/复位 ┐  →  ┌ 4 约束    ┐  →  ┌ 5 证明   ┐  →  ┌ 6 分析   ┐
│ 环境+RTL  │      │ 精化     │      │ 与复位态    │     │ (assume)  │     │ (prove)  │     │ 结果/CEX │
└───────────┘      └──────────┘      └─────────────┘     └───────────┘     └──────────┘     └──────────┘
```

### 1.1 准备环境与 RTL

```csh
# Synopsys
module load vc_static/2025.06-SP2-4-C
# Cadence
module load jasper
```

确保：DUT 与 SVA 语法正确（可先过 VCS 编译）、复位完备、无未初始化寄存器。

### 1.2 编译 / 精化（read + elaborate）

把 RTL 与 SVA 一起编译，绑定断言（`bind`），确定顶层 `mac_int8`。

### 1.3 时钟 / 复位 / 复位态

- 声明时钟 `clk`。
- 声明复位 `rst_n`（低有效）及有效电平/异步属性。
- 工具会先跑若干拍仿真把设计**稳定**到复位解除后的状态，作为证明的起点。

### 1.4 约束（assume）

对本例：输入 `a/b/in_valid/out_ready/acc_clr` 全部合法，**无需额外约束**，证明最强。
复杂工程中，需用 `assume` 约束非法输入/协议前条件，避免"伪反例"。

### 1.5 证明（prove）

工具对每条断言做穷举证明，输出 **proven（证明）/ falsified（被反例推翻）/ bounded（有界通过，未归纳）**。

### 1.6 分析结果与调试

- **proven**：该属性对全部输入序列成立。
- **falsified + CEX**：打开反例波形（Verdi / JasperGold GUI）定位根因。
- **bounded/未证**：加覆盖点找不可达、补约束、或加抽象（cut point / blackbox）。

## 2. Synopsys VC Formal 流程

### 2.1 一键运行

```csh
cd formal/vc_formal
./run_vcformal.csh        # 内部：module load vc_static/2025.06-SP2-4-C; cd ../..; vcf -f formal/vc_formal/run.tcl -verdi
```

### 2.2 `run.tcl` 关键命令逐条解释

| 命令 | 作用 |
|------|------|
| `set_fml_appmode FPV` | 进入形式属性验证模式 |
| `read_file -top mac_int8 -format sverilog -sva -vcs {-f flist/formal.f}` | 编译 RTL+SVA（含 bind） |
| `create_clock clk -period 100 -initial 0` | 定义时钟 |
| `create_reset rst_n -low` | 定义低有效复位 |
| `sim_run -stable` | 跑仿真使设计稳定 |
| `sim_save_reset` | 保存复位后状态作为证明起点 |
| `set_fml_var fml_max_time 5M` | 单属性证明时限 |
| `check_fv -block` | 运行证明 |

### 2.3 结果与调试

- 证明结果打印在 `vcf.log` 与运行目录下的报告文件中。
- 加了 `-verdi`：反例直接在 Verdi 中打开 `vcf_signoff_db/` `*_rtdb` 查看波形。
- 覆盖点结果确认 `c_ovf_pos/c_ovf_neg` 等是否 **hit**（保证断言非空洞）。

## 3. Cadence JasperGold 流程

### 3.1 一键运行

```csh
cd formal/jaspergold
./run_jg.csh              # 内部：module load jasper; cd ../..; jg -batch formal/jaspergold/jg.tcl
```

### 3.2 `jg.tcl` 关键命令逐条解释

| 命令 | 作用 |
|------|------|
| `analyze -sv09 rtl/mac_int8.sv rtl/mac_int8_sva.sv` | 编译 |
| `elaborate -top mac_int8` | 精化并指定顶层 |
| `clock clk` | 定义时钟 |
| `reset !rst_n` | 定义复位（`!` 表示低有效） |
| `prove -all` | 证明全部断言 |
| `report -ab -this_run` | 输出结果摘要 |

### 3.3 结果与调试

- `prove -all` 结束自动打印每属性 `proven/falsified`。
- 反例在 `jgproject/` 下，可用 `jg` GUI（`jg -gui`）打开 session 查看波形与扇入。

## 4. 结果判读与常见问题

| 现象 | 含义 / 处理 |
|------|-------------|
| 全部 A1~A7 **proven**，C1~C4 **hit** | ✅验证通过（本例期望结果） |
| `a_mac_equiv` falsified | DUT 与参考模型不等价，按 CEX 波形定位算术/饱和错误 |
| `a_no_drop` falsified | 握手背压丢数据，检查 `in_ready/out_valid` 逻辑 |
| 某断言 **bounded** 未归纳 | 加覆盖点看是否不可达；补 `assume`；或做归纳加强 |
| 反例触发在复位期 | 检查 `create_reset`/`reset` 电平与 `sim_save_reset` 是否正确 |
| 覆盖点 **unreachable** | 说明该状态不可达（可能约束过强或设计无法到达），需甄别 |

## 5. 与仿真的关系（推荐流程）

1. **先仿真**（`make sim`）：快速功能回归 + 验证 SVA 本身不误报。
2. **再 formal**（`make vcf` / `make jg`）：对关键断言穷举证明，查仿真打不到的边界。
3. 迭代：formal 发现的 CEX → 加进仿真定向用例；仿真的新场景 → 转成断言再 formal 证明。