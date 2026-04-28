using ModernHydroModels
import ModernHydroModels: init_R, plot_floods, plot_forecast_window
using RTableTools, Dates
using JLD2, RCall, YAML

function init_R()
  # R_PATH = joinpath(pkgdir(ModernHydroModels), "ext", "HydroFloods.R")
  R_PATH = "."
  R"""
  if (!requireNamespace("pacman", quietly=TRUE)) install.packages("pacman")
  pacman::p_load(Ipaper, data.table, dplyr, purrr, lubridate, ggplot2, gg.layers, xgboost, kfold)
  devtools::load_all($(R_PATH))
  """
end

function plot_floods(f_csv, site, outdir, prefix)
  R"Floods_Visualization($f_csv, SITE=$site, show_floods=TRUE, show=FALSE, outdir=$outdir, prefix=$prefix, subfix='')"
end

function plot_forecast_window(f_fc, t0_dt::DateTime, outdir, prefix;
  window_past="7 days", window_fc="1 day")
  t0_str = Dates.format(t0_dt, "yyyy-mm-dd HH:MM:SS")
  f_out = "$outdir/$(prefix)_ForecastWindow.svg"
  R"""
  d  <- data.table::fread($f_fc)
  d[, time := lubridate::ymd_hms(time)]
  t0 <- as.POSIXct($t0_str, tz = "UTC")
  p  <- plot_Forecast_Window(d, t0,
    window_past = lubridate::as.duration($window_past),
    window_fc   = lubridate::as.duration($window_fc))
  Ipaper::write_fig(p, $f_out, 10, 4, show = FALSE)
  """
end

# ── 构造测试用 X1/X2（正式使用时由用户自行准备好数据文件）──────────────────────
cfg = YAML.load_file("apps/config_GuShan.yaml")
cfg_nt = Dict2NT(cfg)
(; forcing_calib, forcing_forecast) = cfg_nt

##
mkpath(dirname(forcing_calib))
mkpath(dirname(forcing_forecast))


d = fread("apps/Forcing_GuShan_Lumped.csv")
n_calib = round(Int, nrow(d) * 0.7)
fwrite(d[1:n_calib, :], forcing_calib)
fwrite(d[n_calib+1:end, :], forcing_forecast)

# ── 运行预报 ───────────────────────────────────────────────────────────────────
result = run_forecast(cfg);
# @info "Result" result.scenario length(result.fluxes_fc.R_sim)

##
# ── 运行 XGBoost 后处理 ───────────────────────────────────────────────────────
if cfg["xgb_run"]
  init_R()
  force_calib = cfg["xgb_force_calib"]
  nlead = cfg["xgb_nlead"]

  (; site, model, dir_root) = cfg_nt
  f_fc_win = "$(dir_root)/$(site)_$(model)_window.csv"   # [in ] 输入数据，fc_win
  f_calib = "$(dir_root)/$(site)_$(model)_calib.csv"     # [in ] 率定数据
  f_out = "$(dir_root)/$(site)_$(model)_window_xgb.csv"  # [out] 输出数据

  f_xgb = "OUTPUT/res_XAJ.rds"
  R"""
  pred_xgb <- run_xgb_forecast($site, $f_fc_win, $f_xgb, 
   f_calib = $f_calib,
   fout=$f_out, nlead=$nlead, force_calib=FALSE)
  """
end

"Finished"
