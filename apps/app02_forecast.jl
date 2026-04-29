using ModernHydroModels, YAML

cfg = YAML.load_file("apps/config_GuShan.yaml")
result = run_forecast(cfg)
