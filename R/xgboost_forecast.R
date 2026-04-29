#' @export
check_input <- function(d) {
  if (!"PET" %in% names(d) && "PET_Romanenko" %in% names(d)) {
    d %<>% mutate(PET = PET_Romanenko)
  }
  if (!"PET_Romanenko" %in% names(d) && "PET" %in% names(d)) {
    d %<>% mutate(PET_Romanenko = PET)
  }
  if (!inherits(d$time, "POSIXct")) {
    d$time <- ymd_hms(d$time, tz = "Asia/Shanghai")
  }
  arrange(d, site, time)
}

#' 用 XAJ calib 历史模拟结果重新率定 XGB 后处理模型
#'
#' 准备 XGBoost forecast 后处理模型
#' force_calib = TRUE 表示用 XAJ calib 文件重新率定；FALSE 表示读取已有 res。
#' @export
calib_xgb <- function(f_xgb = NULL, f_calib = NULL, nlead = 12, force_calib = FALSE) {
  if (!isfile(f_xgb) || force_calib) {
    dat <- fread(f_calib) %>% check_input()
    xgb <- train_xgboost(dat, leads = seq_len(nlead))
    saveRDS(xgb, file = f_xgb)
  } else {
    xgb <- readRDS(f_xgb)
  }
  XGBQlag <- lapply(xgb$HydroMetQlagXGB, \(x) x$model)
  list(XGB = xgb$HydroMetXGB$model, XGBQlag = XGBQlag)
}

# forecast 段逐时刻后处理
#' @export
predict_xgb <- function(models, df_new) {
  # # 1个时刻 1个model kfold的结果 [nkfold]
  .predict_xgb <- function(models, Xti) {
    sapply(models, \(m) predict(m, as.matrix(Xti), validate_features = FALSE))
  }

  df_xbg <- df_new[, .(P, PET, Q_sim)]
  df_xgbQlag <- df_new[, .(P, PET, Q_sim, Qlag)]

  nfold <- length(models$XGB)
  names_xgb <- sprintf("XGB_k%02d", 1:nfold)
  names_xgbQlag <- sprintf("XGBQlag_k%02d", 1:nfold)

  lapply(seq_len(nrow(df_new)), function(i) {
    d <- df_new[i]
    p1 <- .predict_xgb(models$XGB, df_xbg[i, ])
    p2 <- .predict_xgb(models$XGBQlag[[d$lead]], df_xgbQlag[i, ])

    out <- data.table(Hydro = d$Q_sim)
    c(setNames(p1, names_xgb), setNames(p2, names_xgbQlag)) %>%
      as.list() %>%
      as.data.table() %>%
      mutate(
        XGB_mean = mean(as.numeric(p1)),
        XGBQlag_mean = mean(as.numeric(p2))
      )
  }) %>%
    rbindlist() %>%
    dt_round(digits = 2) %>%
    cbind(df_new[, .(site, time, lead, Hydro = Q_sim)], .)
}

# 构造 forecast 段 XGB 输入
#' @export
build_xgb_Xt0 <- function(d, nlead = 12) {
  d <- check_input(d)
  t0 <- d[period == "analysis", time] %>% max()
  qobs_t0 <- d[period == "analysis" & time <= t0 & !is.na(Q_obs)][.N, Q_obs]

  d[period == "forecast" & time > t0] %>%
    .[1:nlead, .(site, time, P, PET, Q_sim)] %>%
    mutate(
      lead = sprintf("lead_%02d", 1:nlead),
      Qlag = qobs_t0 # 率定期最后一个观测值作为 Qlag 输入
    )
}

#' @export
xgb_forecast <- function(site = "孤山", model = "XAJ", dir_root = "./apps/", 
  nlead = 12, force_calib = FALSE) 
{
  fs = build_filelist(site, model, dir_root) # filelist
  print2(fs)

  models <- calib_xgb(fs$xgb, fs$calib, nlead = nlead, force_calib = force_calib)

  d <- fread(fs$fc_win) %>% check_input() # about 1w
  input <- build_xgb_Xt0(d, nlead)
  pred <- predict_xgb(models, input)

  mkdir(dirname(fs$out))
  fwrite(pred, fs$out)
  pred
}


#' @export
xgb_forecast_yaml <- function(yaml, verbose = TRUE) {
  cfg = yaml::read_yaml(yaml)
  if (verbose) print2(cfg)

  xgb_forecast(
    site = cfg[["site"]],
    model = cfg[["model"]],
    dir_root = cfg[["dir_root"]],
    nlead = cfg[["xgb_nlead"]],
    force_calib = cfg[["xgb_force_calib"]]
  )
}

#' @export
build_filelist <- function(site = "孤山", model = "XAJ", dir_root = "./apps/") {
  prefix = sprintf("%s/%s/%s_%s", dir_root, site, site, model)
  mkdir(dirname(prefix))
  
  list(
    xgb = sprintf("%s_model_xgb.rds", prefix),   # 率定模型
    out = sprintf("%s_forcast_win_xgb.csv", prefix), # [out] 输出数据
    fc_win = sprintf("%s_forecast_win.csv", prefix),  # [in ] 输入数据，
    calib = sprintf("%s_simulate_calib.csv", prefix)    # [in ] 率定数据
  )
}
