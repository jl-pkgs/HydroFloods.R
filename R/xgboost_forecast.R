#' @export
check_input <- function(d) {
  if (!"PET" %in% names(d) && "PET_Romanenko" %in% names(d)) {
    d %<>% mutate(PET = PET_Romanenko)
  }
  if (!"PET_Romanenko" %in% names(d) && "PET" %in% names(d)) {
    d %<>% mutate(PET_Romanenko = PET)
  }
  if (!inherits(d$time, "POSIXct")) {
    d$time <- ymd_hms(gsub("T", " ", d$time), tz = "Asia/Shanghai")
  }
  arrange(d, site, time)
}


#' 用 XAJ calib 历史模拟结果重新率定 XGB 后处理模型
#'
#' 准备 XGBoost forecast 后处理模型
#' force_calib = TRUE 表示用 XAJ calib 文件重新率定；FALSE 表示读取已有 res。
#' @export
calib_xgb_forecast <- function(
  site = NULL, f_xgb = NULL, f_calib = NULL,
  nlead = 12, force_calib = FALSE
) {
  if (!isfile(f_xgb) || force_calib) {
    dat <- fread(f_calib) %>% check_input()
    xgb <- train_xgboost(dat, leads = seq_len(nlead))
  } else {
    load(f_xgb)
    xgb <- res[[site]]$xgb
  }
  XGBQlag <- lapply(xgb$HydroMetQlagXGB, \(x) x$model)
  list(XGB = xgb$HydroMetXGB$model, XGBQlag = XGBQlag)
}

# 构造 forecast 段 XGB 输入
#' @export
make_xgb_forecast_input <- function(d, nlead = 12) {
  d <- check_input(d)
  t0 <- d[period == "analysis", time] %>% max()
  
  q0 <- d[period == "analysis" & time <= t0 & !is.na(Q_obs)][.N, Q_obs]
  # TODO: check
  x <- d[period == "forecast" & time > t0][1:nlead, .(site, time, P, PET, Q_sim)]
  x[, `:=`(lead = sprintf("lead_%02d", seq_len(.N)), Qlag = q0)]
  x
}

# 一组 kfold XGB 模型预测
#' @export
predict_xgb_folds <- function(models, x, vars) {
  X <- as.matrix(x[, ..vars])
  storage.mode(X) <- "double"
  colnames(X) <- NULL
  as.numeric(sapply(models, \(m) predict(m, X, validate_features = FALSE)))
}

# forecast 段逐时刻后处理
#' @export
predict_xgb_forecast <- function(models, xnew) {
  rbindlist(lapply(seq_len(nrow(xnew)), function(i) {
    x <- xnew[i]
    p1 <- predict_xgb_folds(models$XGB, x, c("P", "PET", "Q_sim"))
    p2 <- predict_xgb_folds(models$XGBQlag[[x$lead]], x, c("P", "PET", "Q_sim", "Qlag"))

    out <- data.table(site = x$site, time = x$time, lead = x$lead, Hydro = x$Q_sim)
    out[, sprintf("XGB_k%02d", seq_along(p1)) := as.list(p1)]
    out[, XGB_mean := mean(p1)]
    out[, sprintf("XGBQlag_k%02d", seq_along(p2)) := as.list(p2)]
    out[, XGBQlag_mean := mean(p2)]
    out
  }))
}

#' XAJ window 的 XGBoost 后处理主函数
#' xaj_window 必须已包含 PET 或 PET_Romanenko。
#' @export
run_xgb_forecast <- function(
  site = NULL, f_fcWin, f_xgb = NULL, f_calib = NULL,
  fout = "OUTPUT/XAJ_XGB_forecast.csv", nlead = 12, force_calib = FALSE
) {
  models <- calib_xgb_forecast(
    site = site, f_xgb = f_xgb, f_calib = f_calib,
    nlead = nlead, force_calib = force_calib
  )

  d <- fread(f_fcWin) %>% check_input()
  input <- make_xgb_forecast_input(d, nlead)

  pred <- predict_xgb_forecast(models, input)

  mkdir(dirname(fout))
  fwrite(pred, fout)
  pred
}
