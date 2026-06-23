using ModernHydroModels, TOML

cfg_path = length(ARGS) > 0 ? ARGS[1] : "apps/config_GuShan.toml"
cfg = TOML.parsefile(cfg_path)

run_forecast(cfg)
