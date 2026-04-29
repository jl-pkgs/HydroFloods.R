using ModernHydroModels
using RTableTools, Dates, RCall, YAML


function init_R()
  R"""
  pacman::p_load(Ipaper, data.table, dplyr, lubridate, ggplot2, gg.layers, HydroFloods)
  devtools::load_all("/mnt/z/GitHub/jl-pkgs/ModernHydroModels.jl/ext/HydroFloods.R")
  """
end

function plot_simulation(f_qout::String, site::String, dir_root::String, prefix::String)
  outdir = "$dir_root/$site"
  R"Floods_Visualization($f_qout, SITE=$site, show_floods=TRUE, show=FALSE, outdir=$outdir, prefix=$prefix, subfix='')"
end

function plot_forecast(t0_dt::DateTime, f_fc::String, fs_r; window_past="7 days", window_fc="1 day")
  outdir = dirname(f_fc)
  site = basename(dirname(f_fc))
  f_out = "$outdir/Figure_forecast_$(site)_ForecastWindow.svg"
  fout_xgb = fs_r[:out]

  R"""
  p  <- plot_Forecast($t0_dt, $f_fc, $fout_xgb, window_past = $window_past, window_fc = $window_fc)
  Ipaper::write_fig(p, $f_out, 10, 4, show = FALSE)
  """
end

function FiguresALL(cfg)
  cfg_nt = Dict2NT(cfg)
  (; site, model, dir_root) = cfg_nt

  t0_dt = parse_datetime(cfg["t0"]) # UTC时间
  fs = build_filelist(site, model, dir_root)
  fs_r = R"build_filelist($site, $model, $dir_root)" |> rcopy

  init_R()
  plot_simulation(fs["simu_calib"], site, dir_root, "Figure_calib_$site")
  plot_simulation(fs["fc"], site, dir_root, "Figure_forecast_$site")
  plot_forecast(t0_dt, fs["fc"], fs_r)
end

## 0. 准备测试数据（正式使用时由用户自行准备好数据文件）──────────────────────────────
d = fread("apps/Forcing_GuShan_Lumped.csv")
n_calib = round(Int, nrow(d) * 0.7)
fwrite(d[1:n_calib, :], "apps/X1_孤山.csv")
fwrite(d[n_calib+1:end, :], "apps/X2_孤山.csv")

## 1. Run Hydro
cfg = YAML.load_file("apps/config_GuShan.yaml")
result = run_forecast(cfg);

## 2. xgb 偏差矫正
if cfg["xgb_run"]
  init_R()
  R"xgb_forecast_yaml('./apps/config_GuShan.yaml', verbose=FALSE)"
end

FiguresALL(cfg) # 3 绘图
"Finished"
