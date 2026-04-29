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
