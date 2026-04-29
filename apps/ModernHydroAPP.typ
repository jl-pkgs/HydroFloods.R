#import "@preview/modern-cug-report:0.1.3": *
#show: doc => template(doc, footer: "ModernHydroModels", header: "")


= 1 代码编译为可执行文件

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

= 2 R语言环境配置

#box-red()[
  用户需自行安装 R 语言环境，并把Rscript.exe文件添加到环境变量PATH。
]

```R
install.packages(c("pacman", "pak", "data.table", "dplyr", "lubridate", "yaml"))
pak::pkg_install("rpkgs/Ipaper")
pak::pkg_install("jl-pkgs/HydroFloods.R")
```

= 3 使用示例

```yaml

# ── 数据路径 ───────────────────────────────────────────────────────
forcing_calib:    "apps/X1_孤山.csv"   # 历史率定数据（X1）
forcing_forecast: "apps/X2_孤山.csv"   # 近实时 + 预报强迫数据（X2）

# ── 站点 / 模型 ────────────────────────────────────────────────────
site:     "孤山"    # 站点名称（用于输出文件命名）
model:    "XAJ"       # 可选：XAJ / GR4J / m07_gr4j_4p_2s / m05_ihacres_7p_1s 等
dir_root: "apps" # 输出目录（不存在则自动创建）

# ── 预报设置 ────────────────────────────────────────────────────
t0:    "2023-10-01 00:00:00"  # 预报起点（本地时间）；留空 "" 则取 X2 最后时刻
n_fc:  24                     # t0=X2末尾时自动延伸的预报时长（小时）
ratio: 0.0                    # 未来降水系数：0=填零，>0 则 ratio × 近期均值

# ── 率定设置 ─────────────────────────────────────────────────────
force_calib: false  # true=强制重新率定；false=有缓存则直接复用
maxn:   3000        # 优化迭代次数（越大越精确，但耗时越长）
n_warm: 90          # X2 头部预热步数（用于无重叠情景）


# ── XGBoost 后处理设置 ───────────────────────────────────────────────
xgb_run: true
xgb_force_calib: false
xgb_nlead: 24 # 当前只做未来 12 小时
```

= 4 模型结果

#figure(
  image("app01_output.png", width: 60%),
  caption: [
    程序输出示例。
  ],
) <fig_>


== 4.1 率定阶段（输出3幅图，）

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

== 4.2 预报阶段（输出3幅图，）

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

== 4.3 实时预报与偏差矫正

#figure(
  image("孤山/Figure_forecast_孤山_ForecastWindow.svg", width: 110%),
  caption: [
    实时预报与偏差矫正
  ]
) <fig_>
