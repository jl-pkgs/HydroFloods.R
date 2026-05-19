module ModernHydroApp

using ModernHydroModels, YAML

function julia_main()::Cint
  printstyled("""
  ┌─────────────────────────────────────────────────────────┐
  │   ModernHydroModels v0.1.0, 20260429                    │
  │   A Modern Hydrological Forecasting Application         │
  │                                                         │
  │   Copyright (c) 2026  Dongdong Kong                     │
  │   kongdd.sysu@gmail.com                                 │
  │   China University of Geosciences (Wuhan)               │
  └─────────────────────────────────────────────────────────┘
  """, color=:green)

  cfg_path = length(ARGS) > 0 ? ARGS[1] : "config.yaml"
  if !isfile(cfg_path)
    println(stderr, "ERROR: Config file not found: $cfg_path")
    println(stderr, "Usage: forecast <config.yaml>")
    return 1
  end
  cfg = YAML.load_file(cfg_path)
  run_forecast(cfg)
  return 0
end

end # module
