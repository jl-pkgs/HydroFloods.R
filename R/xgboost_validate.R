# 验证期检验: 每个 lead 用 5 个 kfold 子模型预测, 并给出集合平均(mean)
# 集合写法参考 predict_xgb (R/xgboost_forecast.R)

# 5 个 kfold 子模型集合预测, 返回 [k01..k05, mean]
predict_kfold <- function(models, X) {
  X <- as.matrix(X)
  p <- sapply(models, \(m) predict(m, X, validate_features = FALSE))
  cbind(
    as.data.table(p) %>% set_names(sprintf("k%02d", seq_len(ncol(p)))),
    mean = rowMeans(p)
  )
}

#' 与 train_xgboost 配对的预测
#'
#' 与 [train_xgboost()] 配对: 在 `newdata` 上对每个 lead 用 5 个 kfold 子模型预测,
#' 并给出集合平均(`mean`). 特征构造与训练共用 `xgb_features()`, 保证一致.
#' @param object [train_xgboost()] 的返回
#' @param newdata 新数据(含 `Q_obs`, `P`, `Q_sim` 等), 通常为验证期 `data_valid`
#' @param leads 预见期, 默认由 `object` 推断 (与训练时一致)
#' @return 长表 `[site, time, model, lead, Q_obs, kfold, Q_sim]`. model 取值
#'   Hydro(原始 Q_sim 基线) / MetXGB / HydroMetXGB / HydroMetQlagXGB / QlagXGB;
#'   验证期无观测时返回空表.
#' @export
predict_xgboost <- function(object, newdata, leads = seq_along(object$HydroMetQlagXGB)) {
  X <- xgb_features(newdata, leads)
  meta <- X$data[, .(site, time, Q_obs)]

  one <- function(fit, Xi, model, lead) {
    if (nrow(Xi) == 0) return(NULL)
    cbind(meta, model, lead, predict_kfold(fit$model, Xi)) %>%
      melt(id = c("site", "time", "Q_obs", "model", "lead"),
        variable.name = "kfold", value.name = "Q_sim", variable.factor = FALSE)
  }
  # 逐 lead 的模型族 (HydroMetQlagXGB / QlagXGB)
  family <- function(model, fits, feats) {
    map(names(feats), \(nm) one(fits[[nm]], feats[[nm]], model, nm))
  }
  # 传统水文模型 Hydro 基线: 原始 Q_sim (无 XGB 订正, 无 kfold)
  hydro <- X$data[, .(site, time, Q_obs, model = "Hydro", lead = "-", kfold = "-", Q_sim)]
  c(
    list(hydro),
    list(one(object$MetXGB, X$MetXGB, "MetXGB", "-")),
    family("QlagXGB", object$QlagXGB, X$QlagXGB),
    list(one(object$HydroMetXGB, X$HydroMetXGB, "HydroMetXGB", "-")),
    family("HydroMetQlagXGB", object$HydroMetQlagXGB, X$HydroMetQlagXGB)
  ) %>% rbindlist(use.names = TRUE)
}

#' 洪水场次合格率 (cal_pass_rate / summary_xgboost 共用)
#' @param pred 含 `time, model, lead, kfold, Q_obs, Q_sim` 列的长表;
#' @param d_full 划分洪水场次的全序列
eval_floods <- function(pred, d_full) {
  SITE <- d_full$site[1]
  c(data_flood, info_flood) %<-% flood_divide(d_full, SITE)
  d_flood <- data_flood[, .(group, group_name, time)]
  n_flood <- d_flood$group_name %>% unique_length()

  info_pass <- merge(d_flood, pred, by = "time") %>%
    .[, eval_Qmax(Q_obs, Q_sim), .(model, lead, kfold, group, group_name)] %>%
    .[passed == TRUE, .(perc_pass = .N / n_flood), .(model, lead, kfold)] %>%
    arrange(model, lead, kfold)
  listk(info_pass, info_flood)
}

#' 模型表现检验 (拟合优度 + 洪水合格率)
#'
#' 在 `newdata` 上检验 [train_xgboost()] 模型, 5 个 kfold 子模型与集合平均(`mean`)
#' 并列对比. `newdata = NULL` 时使用训练数据 (`object$data_full`), 即率定期(样本内)
#' 检验; 传入 `data_valid` 则为验证期(样本外)检验.
#' @inheritParams predict_xgboost
#' @export
summary_xgboost <- function(object, newdata = NULL, leads = seq_along(object$HydroMetQlagXGB)) {
  if (is.null(newdata)) newdata <- object$data_full
  pred <- predict_xgboost(object, newdata, leads)
  if (nrow(pred) == 0) {
    warning(newdata$site[1], ": 验证期无观测(Q_obs), 跳过检验")
    return(listk(pred, gof = NULL, info_pass = NULL, info_flood = NULL))
  }
  # 拟合优度: 每个 model / lead / kfold (含 Hydro 基线)
  gof <- pred[!is.na(Q_sim), GOF(Q_obs, Q_sim), .(model, lead, kfold)]
  c(info_pass, info_flood) %<-% eval_floods(pred, newdata)
  listk(pred, gof, info_pass, info_flood)
}
