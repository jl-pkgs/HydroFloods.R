pacman::p_load(
  Ipaper, data.table, dplyr, lubridate,
  zeallot
)
devtools::load_all()
cfg <- yaml::read_yaml("./apps/config_GuShan.yaml")


# force_calib <- cfg[["xgb_force_calib"]]
nlead <- cfg[["xgb_nlead"]]
site <- cfg[["site"]]
model <- cfg[["model"]]
dir_root <- cfg[["dir_root"]]

prefix = sprintf("%s/%s_%s", dir_root, site, model)
f_fc_win <- sprintf("%s_window.csv", prefix)  # [in ] 输入数据，
f_calib <- sprintf("%s_calib.csv", prefix)    # [in ] 率定数据
f_out <- sprintf("%s_window_xgb.csv", prefix) # [out] 输出数据

f_xgb <- "OUTPUT/res_XAJ.rda"
pred_xgb <- run_xgb_forecast(site, f_fc_win, f_xgb,
  f_calib = f_calib,
  fout = f_out, nlead = nlead, force_calib = FALSE
)
