#' parse_xgb_time
#' @export
parse_xgb_time <- function(x) if (inherits(x, "POSIXct")) x else as.POSIXct(gsub("T", " ", x), tz = "Asia/Shanghai")

#' 从已有 res 文件读取 XGB 后处理模型
#' @export
read_xgb_from_res <- function(f_res, site_model) {
  if (grepl("\\.rds$", f_res)) {
    res <- readRDS(f_res); if ("res" %in% names(res)) res <- res$res
  } else {
    e <- new.env(); load(f_res, envir = e); res <- e$res
  }
  xgb <- res[[site_model]]$xgb
  qlag <- lapply(xgb$HydroMetQlagXGB, \(z) z$model)
  names(qlag) <- sprintf("lead_%02d", seq_along(qlag))
  list(XGB = xgb$HydroMetXGB$model, XGBQlag = qlag)
}

#' 用 window 的 analysis 段重新率定 XGB 后处理模型
#' @export
train_xgb_from_analysis <- function(d, horizon = 24) {
  d <- as.data.table(copy(d)); d[, time := parse_xgb_time(time)]; setorder(d, site, time)
  dat <- d[period == "analysis"]; dat[, PET_Romanenko := PET]
  xgb <- train_xgboost(dat, leads = seq_len(horizon))
  qlag <- lapply(xgb$HydroMetQlagXGB, \(z) z$model)
  names(qlag) <- sprintf("lead_%02d", seq_along(qlag))
  list(XGB = xgb$HydroMetXGB$model, XGBQlag = qlag)
}

#' 准备 XGBoost forecast 后处理模型
#' force_calib = TRUE 表示用 analysis 段重新率定；FALSE 表示读取已有 res。
#' @export
calib_xgb_forecast <- function(d, f_res = NULL, site_model = NULL, horizon = 24, force_calib = FALSE) {
  if (force_calib) train_xgb_from_analysis(d, horizon) else read_xgb_from_res(f_res, site_model)
}

#' 构造 forecast 段 XGB 输入
#' @export
make_xgb_forecast_input <- function(d, horizon = 24, t0 = NULL) {
  d <- as.data.table(copy(d)); d[, time := parse_xgb_time(time)]; setorder(d, site, time)
  if (is.null(t0)) t0 <- max(d[period == "analysis", time], na.rm = TRUE)
  q0 <- d[period == "analysis" & time <= parse_xgb_time(t0) & !is.na(Q_obs)][.N, Q_obs]
  x <- d[period == "forecast" & time > parse_xgb_time(t0)][1:horizon, .(site, time, P, PET, Q_sim)]
  x[, `:=`(lead = sprintf("lead_%02d", seq_len(.N)), Qlag = q0)]
  x
}

#' 一组 kfold XGB 模型预测
#' @export

predict_xgb_folds <- function(models, x, vars) {
  X <- as.matrix(x[, ..vars]); storage.mode(X) <- "double"; colnames(X) <- NULL
  as.numeric(sapply(models, \(m) predict(m, X, validate_features = FALSE)))
}

#' forecast 段逐时刻后处理
#' @export
predict_xgb_forecast <- function(models, xnew) {
  rbindlist(lapply(seq_len(nrow(xnew)), function(i) {
    x <- xnew[i]
    p1 <- predict_xgb_folds(models$XGB, x, c("P", "PET", "Q_sim"))
    p2 <- predict_xgb_folds(models$XGBQlag[[x$lead]], x, c("P", "PET", "Q_sim", "Qlag"))

    out <- data.table(site = x$site, time = x$time, lead = x$lead, XAJ = x$Q_sim)
    out[, sprintf("XGB_k%02d", seq_along(p1)) := as.list(p1)]; out[, XGB_mean := mean(p1)]
    out[, sprintf("XGBQlag_k%02d", seq_along(p2)) := as.list(p2)]; out[, XGBQlag_mean := mean(p2)]
    out
  }))
}
#' XAJ window 的 XGBoost 后处理主函数
#' xaj_window 包含 PET。
#' @export
run_xgb_forecast <- function(xaj_window, f_res = NULL, site_model = NULL, fout = "OUTPUT/XAJ_XGB_forecast.csv", horizon = 24, t0 = NULL, force_calib = FALSE) {
  d <- if (is.character(xaj_window)) fread(xaj_window) else copy(xaj_window)
  d[, time := parse_xgb_time(time)]
  models <- calib_xgb_forecast(d, f_res, site_model, horizon, force_calib)
  pred <- predict_xgb_forecast(models, make_xgb_forecast_input(d, horizon, t0))
  dir.create(dirname(fout), recursive = TRUE, showWarnings = FALSE); fwrite(pred, fout)
  pred
}