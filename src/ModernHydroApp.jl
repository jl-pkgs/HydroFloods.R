module ModernHydroApp

using ModernHydroModels, TOML

function _main(args::Vector{String})::Cint
  print("""
  ┌─────────────────────────────────────────────────────────┐
  │   ModernHydroModels v0.1.0, 20260429                    │
  │   A Modern Hydrological Forecasting Application         │
  │                                                         │
  │   Copyright (c) 2026  Dongdong Kong                     │
  │   kongdd.sysu@gmail.com                                 │
  │   China University of Geosciences (Wuhan)               │
  └─────────────────────────────────────────────────────────┘
  """)

  cfg_path = length(args) > 0 ? args[1] : "config.toml"
  if !isfile(cfg_path)
    println(stderr, "ERROR: Config file not found: $cfg_path")
    println(stderr, "Usage: ModernHydro <config.toml>")
    return 1
  end
  cfg = TOML.parsefile(cfg_path)
  run_forecast(cfg)
  return 0
end

# PackageCompiler (compile.jl)
julia_main()::Cint = _main(ARGS)

end # module
