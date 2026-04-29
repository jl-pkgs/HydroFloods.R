# https://julialang.github.io/PackageCompiler.jl/dev/apps.html
using PackageCompiler
using Pkg

app_dir = joinpath(@__DIR__, "..")
# out_dir = joinpath(@__DIR__, "build")
out_dir = "/home/kong/julia_apps"

# 解析依赖（首次需要联网下载 ModernHydroModels）
Pkg.activate(app_dir)
Pkg.instantiate()

# 打包为独立可执行程序（接收方无需安装 Julia）
# 输出：ForecastApp_dist/bin/forecast
@time create_app(app_dir, out_dir;
    executables = ["ModernHydro" => "julia_main"],
    force = true
)

# ── 生成物说明 ───────────────────────────────────────────────────────────────
# ForecastApp_dist/
#   bin/forecast        ← 可执行文件，发给用户直接运行
#   lib/                ← Julia runtime + 所有依赖（一并打包发送）
#
# 用法：./ForecastApp_dist/bin/forecast config_GuShan.yaml
#
# ── 旧版 sysimage（仅加速本地，不可分发）────────────────────────────────────
# pkg = "ModernHydroModels"
# lib = "$(pkg)_v0.1.0.dll"
# Pkg.activate("..")
# @time create_sysimage([pkg]; sysimage_path=lib)
