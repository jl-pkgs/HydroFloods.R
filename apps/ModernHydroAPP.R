# %% 
pacman::p_load(
  Ipaper, data.table, dplyr, lubridate,
  HydroFloods, toml,
  gg.layers, JuliaCall
)
devtools::load_all()

toml <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(toml)) toml <- "./apps/config_GuShan.toml"
cfg <- read_toml(toml)

# %% 
app <- cfg[["app"]]
# app = "/home/kong/julia_apps/bin/ModernHydro"
if (file.exists(app)) {
  cmd <- sprintf('%s "%s"', app, toml)
  system(cmd) # julia side
} else {
  julia_setup()
  julia_library("ModernHydroModels")
  # R 具名 list 经 JuliaCall 变成 Symbol 键的 Dict，run_forecast 用 String 键索引，故转一次
  julia_assign("cfg_r", cfg)
  julia_eval("run_forecast(Dict(string(k) => v for (k, v) in cfg_r))")
}

# %% 后处理矫正
xgb_forecast_main(cfg)

# %% 绘图
site <- cfg[["site"]]
model <- cfg[["model"]]
dir_root <- cfg[["dir_root"]]
t0_dt <- lubridate::ymd_hms(cfg[["t0"]], tz = "UTC")

fs <- build_filelist(site, model, dir_root)

# 率定期模拟图
Floods_Visualization(fs[["simulation_calib"]],
  SITE = site, show_floods = TRUE, show = FALSE,
  outdir = sprintf("%s/%s", dir_root, site),
  prefix = sprintf("Figure_calib_%s", site), subfix = ""
)

# 预报期模拟图
Floods_Visualization(fs[["fc"]],
  SITE = site, show_floods = TRUE, show = FALSE,
  outdir = sprintf("%s/%s", dir_root, site),
  prefix = sprintf("Figure_forecast_%s", site), subfix = ""
)

# 预报窗口图
f_fc <- fs[["fc"]]
fout_xgb <- fs[["out"]]
f_fig <- sprintf("%s/Figure_forecast_%s_ForecastWindow.svg", dirname(f_fc), site)
p <- plot_Forecast(t0_dt, f_fc, fout_xgb, window_past = "7 days", window_fc = "1 day")
Ipaper::write_fig(p, f_fig, 10, 4, show = FALSE)
