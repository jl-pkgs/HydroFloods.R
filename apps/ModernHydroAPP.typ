#import "@preview/modern-cug-report:0.1.3": *
#show: doc => template(doc, footer: "ModernHydroModels", header: "")


= 用户手册 


本程序中的 Julia 模型部分已经被打包为独立可执行程序，用户不需要安装 Julia 环境，只需要配置 R 语言环境，并安装配套 R 包。// <!-- omit in toc -->

#figure(
  image("app_main.png", width: 100%),
  caption: [
    共143次代码提交，初步完成了所需功能。
  ]
) <fig_>

#pagebreak()
= 1 R语言环境配置

#box-red()[
  用户需自行安装 R 语言环境，并将 `Rscript.exe` 所在目录添加到系统环境变量 `PATH`。
]

```R
install.packages(c("pacman", "pak"))
pak::pkg_install("local::pkgs/HydroFloods_0.1.1.tar.gz")
# `pak` 会自动读取 R 包 `DESCRIPTION` 文件中的依赖关系，并安装所需依赖包。
```

= 2 使用示例
==  2.1 输入数据要求

程序需要两个输入文件：历史率定数据 `X1` 和近实时 / 预报强迫数据 `X2`。

```text
apps/X1_孤山.csv
apps/X2_孤山.csv
```
输入文件示例如下：当前示例默认使用 P 和 PET_Romanenko 作为模型强迫输入，使用 R 作为水文模型模型率定的观测径流深；Q 用于结果展示和 XGBoost 后处理。
```csv
time,area_km2,Z,Q,R,P,PET_FAO98,PET_PT1972,PET_Romanenko,Tair
2014-04-01T00:00:00,322,25.38,0.139,0.0016,0.0,0.0967,0.1063,0.2468,15.07
2014-04-01T01:00:00,322,25.38,0.139,0.0016,0.0,0.0929,0.1051,0.2322,14.56

```


变量说明如下：

#table(
columns: (1.8fr, 4fr),
[变量], [说明],
[time], [时间, h],
[area_km2], [流域面积，km²],
[Q], [实测流量，m³/s],
[R], [实测径流深，mm/h],
[P], [降水量，mm],
[`PET_Romanenko`], [当前示例默认使用的潜在蒸散发输入,mm。],
[`PET_FAO98`], [备用，当前示例默认流程不直接使用。],
[`PET_PT1972`], [备用，当前示例默认流程不直接使用。],
[`Tair`], [气温，当前示例默认流程不直接使用。],
)
== 2.2 配置文件说明

配置信息：`config_GuShan.yaml`

```yaml
## apps/config_GuShan.yaml
app: /home/kong/julia_apps/bin/ModernHydro # Julia ModernHydroModels路径

# ── 数据路径 ─────────────────────────────────────────────────────────
forcing_calib    : "apps/X1_孤山.csv"   # 历史率定数据（X1）
forcing_forecast : "apps/X2_孤山.csv"   # 近实时 + 预报强迫数据（X2）

# ── 站点 / 模型 ──────────────────────────────────────────────────────
# model可选：XAJ, GR4J, m05_ihacres_7p_1s, m07_gr4j_4p_2s, m09_susannah1_6p_2s, m28_xinanjiang_12p_4s
model       : "XAJ"  
site        : "孤山" # 站点名称（用于输出文件命名）
dir_root    : "apps" # 输出目录（不存在则自动创建）

# ── 率定设置 ─────────────────────────────────────────────────────────
force_calib : false  # true=强制重新率定；false=有缓存则直接复用
maxn        : 3000        # 优化迭代次数（越大越精确，但耗时越长）
n_warm      : 90          # X2 头部预热步数（用于无重叠情景）

# ── 预报设置 ─────────────────────────────────────────────────────────
t0    : "2023-10-01 00:00:00" # 预报起点（本地时间）；留空则取 X2 最后时刻
n_fc  : 24                    # t0=X2末尾时自动延伸的预报时长（小时）
ratio : 0.0                   # 未来降水系数：0=填零，>0则 ratio×近期均值

# ── XGBoost 后处理设置 ───────────────────────────────────────────────
xgb_run         : true    # true=运行XGBoost后处理；false=只运行水文模型
xgb_force_calib : false  # true=重新训练XGB；false=读取已有XGB模型
xgb_nlead       : 24 # 预报时长，当前选择未来24小时

```

运行脚本：`ModernHydroAPP.R`。
#box-red()[
  用户运行时通常只需修改 YAML 配置文件，不需要修改该脚本。
]

app路径要在yaml文件中指定
```yaml
app: /home/kong/julia_apps/bin/ModernHydro
```

#pagebreak()

运行命令：
```sh
# !/bin/bash
# Copyright (c) 2025 Dongdong Kong & JiaQi Shi
Rscript apps/ModernHydroAPP.R apps/config_GuShan.yaml 
```

以 `site = "孤山"`、`model = "XAJ"` 为例，程序文件输出如下：
#table(
  columns: (2.8fr, 4fr),
  align: (left, left),
  [文件], [说明],
  [`孤山_XAJ_simulate_calib.csv`], [率定期水文模型模拟结果。],
  [`孤山_XAJ_forecast.csv`], [预报期水文模型结果。],
  [`孤山_XAJ_forecast_win.csv`], [水文模型实时预报窗口期结果。],
  [`孤山_XAJ_forecast_win_xgb.csv`], [XGBoost修正后的实时预报窗口期结果。],
  [`孤山_XAJ_model_hydro.jld2`], [水文模型缓存文件。],
  [`孤山_XAJ_model_xgb.rds`], [XGBoost模型缓存文件。]
)

图件输出如下：

#table(
  columns: (2.8fr, 4.4fr),
  align: (left, left),
  inset: 6pt,
  [文件], [说明],
  [`Figure_calib_孤山_*.svg`], [率定期图件，包括全时序模拟结果、洪水事件划分结果和洪水场次模拟结果。],
  [`Figure_forecast_孤山_*.svg`], [预报期图件，包括全时序模拟结果、洪水事件划分结果和洪水场次模拟结果。],
  [`Figure_forecast_孤山_ForecastWindow.svg`], [起报时刻附近的实时预报窗口图，展示降水、实测流量、水文模型预报及XGBoost修正结果。],
)
#figure(
  image("app_output.png", width: 50%),
  caption: [
    程序输出文件示例。
  ],
) <fig_>


#pagebreak()

= 3 模型结果

== 3.1 率定阶段（输出3幅图，`Figure_calib_孤山_*.svg`）

#figure(
  image("孤山/Figure_calib_孤山_ALL_TimeSeries.svg", width: 100%),
  caption: [
    率定期全时序模拟结果
  ]
) <fig_>

#figure(
  image("孤山/Figure_calib_孤山_FloodEvents_Qobs.svg", width: 110%),
  caption: [
    率定期洪水事件划分
  ],
) <fig_>

#figure(
  image("孤山/Figure_calib_孤山_FloodEvents_Qsim.svg", width: 100%),
  caption: [
    率定期洪水场次模拟结果
  ],
) <fig_>

== 3.2 预报阶段（输出3幅图，`Figure_forecast_孤山_*.svg`）

#figure(
  image("孤山/Figure_forecast_孤山_ALL_TimeSeries.svg", width: 100%),
  caption: [
    预报阶段全时序模拟结果
  ],
) <fig_>

#figure(
  image("孤山/Figure_forecast_孤山_FloodEvents_Qobs.svg", width: 110%),
  caption: [
    预报阶段洪水事件划分
  ],
) <fig_>

#figure(
  image("孤山/Figure_forecast_孤山_FloodEvents_Qsim.svg", width: 100%),
  caption: [
    预报阶段洪水场次模拟结果
  ],
) <fig_>

== 3.3 实时预报与偏差矫正（输出一幅图，`Figure_forecast_孤山_ForecastWindow.svg`）

#figure(
  image("孤山/Figure_forecast_孤山_ForecastWindow.svg", width: 110%),
  caption: [
    实时预报与偏差矫正
  ]
) <fig_>


#pagebreak()

== 开发者手册 // <!-- omit in toc -->
= 4 代码编译为可执行文件

#box-red[
  这样用户不需要安装Julia环境，就可以直接运行这个应用程序。
]

```julia
# https://julialang.github.io/PackageCompiler.jl/dev/apps.html
using PackageCompiler
using Pkg

app_dir = joinpath(@__DIR__, "..")
# out_dir = joinpath(@__DIR__, "build")
out_dir = "/home/kong/julia_apps" # TODO: change path

Pkg.activate(app_dir)
Pkg.instantiate()

# 打包为独立可执行程序（接收方无需安装 Julia）
# 输出：ForecastApp_dist/bin/forecast
@time create_app(app_dir, out_dir;
    executables = ["ModernHydro" => "julia_main"],
    force = true
)
```
