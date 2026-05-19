using ModernHydroModels, YAML
cfg_path = length(ARGS) > 0 ? ARGS[1] : "apps/config_GuShan.yaml"
cfg = YAML.load_file(cfg_path)
run_forecast(cfg)
