# XGB 后处理: 预测 (predict_xgboost) + 表现检验 (summary_xgboost)
#
# 三种情景 (`mode` 列), 由 kfold 的 `predict.kfold` 提供 train/valid/test 语义:
#   - train: 各折对已见行的集合预测 (率定期, 样本内拟合)
#   - valid: 各折对留出行的 OOF 拼接 (率定期, 交叉验证, 不泄漏)
#   - test : 5 折对全新 newdata 的集合预测 (验证期, 样本外)
# 三者均取集合平均 (`$ensemble`); GOF 直接由 pred 长表逐 (model, lead) 计算.

# 遍历 4 个 XGB 模型族, 对齐 fit 与特征 X, 逐 (fit, Xi, model, lead) 调用 f 并 rbind
xgb_map <- function(object, X, f, leads = seq_along(object$HydroMetQlagXGB)) {
  nms <- names(object$HydroMetQlagXGB)[leads] # 与训练一致的 lead 子集
  rbindlist(c(
    list(f(object$MetXGB, X$MetXGB, "MetXGB", "-")),
    list(f(object$HydroMetXGB, X$HydroMetXGB, "HydroMetXGB", "-")),
    map(nms, \(nm) f(object$QlagXGB[[nm]], X$QlagXGB[[nm]], "QlagXGB", nm)),
    map(nms, \(nm) f(object$HydroMetQlagXGB[[nm]], X$HydroMetQlagXGB[[nm]], "HydroMetQlagXGB", nm))
  ), use.names = TRUE, fill = TRUE)
}

arrange_xgb <- function(d) {
  d %>%
    mutate(mode = factor(mode, c("train", "valid", "test"))) %>%
    arrange(model, lead, mode)
}

#' 与 train_xgboost 配对的集合预测
#'
#' 对每个 (模型族, lead) 用 5 个 kfold 子模型预测, 取集合平均 (`$ensemble`).
#' 特征构造与训练共用 `xgb_features()`, 保证一致.
#' @param object [train_xgboost()] 的返回
#' @param newdata 预测数据. `mode = "test"` 用其特征 (样本外);
#'   `mode = "train"/"valid"` 走 kfold 内部训练集, 故须传 `object$data_full`.
#' @param leads 预见期, 默认由 `object` 推断 (与训练一致)
#' @param mode `"train"` / `"valid"` / `"test"`, 透传给 [kfold::predict.kfold()]
#' @return 长表 `[mode, site, time, Q_obs, model, lead, kfold, Q_sim]`;
#'   含 Hydro 基线 (`kfold = "-"`), XGB 各族取集合平均 (`kfold = "ensemble"`).
#' @export
predict_xgboost <- function(object, newdata, leads = seq_along(object$HydroMetQlagXGB),
                            mode = "test") {
  X <- xgb_features(newdata, leads)
  meta <- X$data[, .(site, time, Q_obs)]
  one <- function(fit, Xi, model, lead) {
    if (nrow(Xi) == 0) return(NULL)
    nd <- if (mode == "test") as.matrix(Xi) # train/valid 走 kfold 内部训练集
    Q_sim <- predict(fit, nd, mode = mode)$ensemble
    cbind(meta, model, lead, kfold = "ensemble", Q_sim)
  }
  hydro <- X$data[, .(site, time, Q_obs, model = "Hydro", lead = "-", kfold = "-", Q_sim)]
  ans <- rbind(hydro, xgb_map(object, X, one, leads), fill = TRUE)
  setcolorder(ans[, mode := mode], "mode")
  ans
}

# 单情景洪水合格率: pred 与已划分洪水场次 d_flood 对齐, 按 (model, lead, kfold) 算合格率
flood_pass <- function(pred, d_flood, mode) {
  n_flood <- d_flood$group_name %>% unique_length()
  merge(d_flood, pred, by = "time") %>%
    .[, eval_Qmax(Q_obs, Q_sim), .(model, lead, kfold, group, group_name)] %>%
    .[passed == TRUE, .(perc_pass = .N / n_flood, n_flood = n_flood), .(model, lead, kfold)] %>%
    arrange(model, lead, kfold) %>%
    mutate(mode = mode)
}

#' 模型表现检验: train / valid / test 一次给全
#'
#' train / valid 恒返回 (率定期, 由 `object` 内部 kfold 计算);
#' 传入 `newdata` 时追加 test (验证期, 样本外集合预测).
#' @param object [train_xgboost()] 的返回
#' @param newdata 验证期数据 (训练时未用); `NULL` 则只出 train/valid
#' @param leads 预见期, 默认由 `object` 推断
#' @return `listk(pred, gof, info_pass, info_flood)`:
#'   - `pred`: train/valid/test 集合预测长表 (含 Hydro 基线)
#'   - `gof` : 逐 `(model, lead, mode)` 拟合优度
#'   - `info_pass` : 逐 `(model, lead, mode)` 洪水合格率
#'   - `info_flood`: 各情景洪水场次信息 (率定期 train/valid 共用一次划分)
#' @export
summary_xgboost <- function(object, newdata = NULL,
                            leads = seq_along(object$HydroMetQlagXGB)) {
  pred <- rbind(
    predict_xgboost(object, object$data_full, leads, mode = "train"),
    predict_xgboost(object, object$data_full, leads, mode = "valid")
  )
  has_test <- !is.null(newdata)
  if (has_test) {
    pred_test <- predict_xgboost(object, newdata, leads, mode = "test")
    if (pred_test[, all(is.na(Q_obs))]) {
      warning(newdata$site[1], ": 验证期无观测(Q_obs), 跳过 test")
      has_test <- FALSE
    } else {
      pred <- rbind(pred, pred_test)
    }
  }

  # GOF: 各情景逐 (model, lead) 用集合序列直接算 (含 Hydro 基线)
  gof <- pred[!is.na(Q_sim), GOF(Q_obs, Q_sim), .(model, lead, kfold, mode)] %>% arrange_xgb()

  # 洪水合格率: 率定期划分一次 (train/valid 共用), 验证期单独划分
  SITE <- object$data_full$site[1]
  c(d_calib, flood_calib) %<-% flood_divide(object$data_full, SITE)
  d_calib <- d_calib[, .(group, group_name, time)]
  info_pass <- rbind(
    flood_pass(pred[mode == "train"], d_calib, "train"),
    flood_pass(pred[mode == "valid"], d_calib, "valid")
  )
  info_flood <- list(train = flood_calib, valid = flood_calib)

  if (has_test) {
    c(d_test, flood_test) %<-% flood_divide(newdata, SITE)
    info_pass <- rbind(info_pass, flood_pass(pred[mode == "test"], d_test[, .(group, group_name, time)], "test"))
    info_flood$test <- flood_test
  }
  listk(pred, gof, info_pass = arrange_xgb(info_pass), info_flood)
}
