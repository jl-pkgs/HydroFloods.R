pacman::p_load(
  Ipaper, data.table, dplyr, lubridate,
  zeallot, HydroFloods
)
# devtools::load_all()
# pak::pkg_install("jl-pkgs/HydroFloods.R")

xgb_forecast_yaml("./apps/config_GuShan.yaml")

# cfg <- yaml::read_yaml("./apps/config_GuShan.yaml")
# str(cfg)
# # force_calib <- cfg[["xgb_force_calib"]]
# nlead <- cfg[["xgb_nlead"]]
# site <- cfg[["site"]]
# model <- cfg[["model"]]
# dir_root <- cfg[["dir_root"]]
# pred_xgb <- xgb_forecast(site, model, dir_root, nlead = 24, force_calib = FALSE)

## TODO: 绘图的脚本加到这里
