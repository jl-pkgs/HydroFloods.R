# 构造 XGB 输入特征 (train_xgboost / predict_xgboost 共用, 保证特征一致)
# 返回有效观测行 data, 及 5 个模型族的特征:
#   - MetXGB          : 气象 P, PET
#   - HydroMetXGB     : P, PET, Q_sim
#   - QlagXGB         : 各 lead 的滞后流量 Q_t-lead
#   - HydroMetQlagXGB : 上述全部
#   - HydroMetQlagMultiXGB : 上述全部 + back03 前期流量、差值和均值
#' @importFrom kfold add_previous
xgb_features <- function(data_full, leads = 1:12, multi_back = 3L) {
  data_full <- arrange(data_full, site, time)
  input <- data_full %>% add_previous(nlead = max(leads) + multi_back)
  data <- input[!is.na(Q_obs), ]
  vars_Q <- names(input) %>% .[grep("Q_t-", .)]
  names(leads) <- sprintf("lead_%02d", seq_along(leads))

  make_multi <- function(lead) {
    vars <- paste0("Q_t-", lead + 0:multi_back)
    q <- data[, ..vars]
    setnames(q, sprintf("Qobs_lag%02d", 0:multi_back))
    q[, dQobs_lag1 := Qobs_lag00 - Qobs_lag01]
    q[, Qobs_lag_mean3 := rowMeans(.SD),
      .SDcols = c("Qobs_lag00", "Qobs_lag01", "Qobs_lag02")]
    cbind(select(data, P, PET = PET_Romanenko, Q_sim), q)
  }

  listk(data,
    MetXGB = select(data, P, PET = PET_Romanenko),
    HydroMetXGB = select(data, P, PET = PET_Romanenko, Q_sim),
    QlagXGB = map(leads, \(l) select(data, all_of(vars_Q[l]))),
    HydroMetQlagXGB = map(leads, \(l) select(data, P, PET = PET_Romanenko, Q_sim, all_of(vars_Q[l]))),
    HydroMetQlagMultiXGB = map(leads, make_multi)
  )
}

# 按时间顺序用前 train_ratio 训练、后 (1 - train_ratio) 验证。
# 返回 kfold 对象，直接复用现有 predict/summary 方法。
xgb_holdout <- function(X, Y, train_ratio = 0.7, ...) {
  if (train_ratio <= 0 || train_ratio >= 1) stop("`train_ratio` 必须在 0 和 1 之间。")
  X <- as.matrix(X)
  Y <- as.matrix(Y)
  ntrain <- floor(nrow(X) * train_ratio)
  index <- list(holdout = seq.int(ntrain + 1L, nrow(X)))
  model <- list(holdout = xgboost(X, Y, eval_set = index$holdout, ...))
  structure(list(data = list(X = X, Y = Y), index = index, model = model), class = "kfold")
}

#' 训练 XGB 洪水预报后处理模型
#'
#' 对 5 个模型族 (MetXGB / HydroMetXGB / QlagXGB / HydroMetQlagXGB /
#' HydroMetQlagMultiXGB) 分别训练, 特征由 `xgb_features()` 构造.
#' 配套预测见 [predict_xgboost()], 表现检验见 [summary_xgboost()].
#' HydroMetQlagMultiXGB 使用论文最终的 back03 方案。
#' @param data_full 训练数据, 含 `site, time, Q_obs, P, Q_sim, PET_Romanenko`
#' @param leads 预见期 (小时)
#' @param multi_back HydroMet-QlagMulti 使用的额外前期流量阶数，默认 3
#' @param validation 验证方式：5 折交叉验证或按时间顺序留出
#' @param train_ratio `validation = "holdout"` 时的训练比例，默认 0.7
#' @param nrounds 最大迭代次数
#' @param early_stopping_rounds 7:3 验证时的提前停止轮数
#' @param ... 透传给 `kfold_xgboost()` 或 XGBoost 留出训练
#' @return list: `data_full`, `data` (有效观测行), 及各模型族的 kfold 对象
#' @import xgboost
#' @importFrom kfold kfold_xgboost
#' @export
train_xgboost <- function(
  data_full, leads = 1:12, multi_back = 3L,
  validation = c("kfold", "holdout"), train_ratio = 0.7,
  nrounds = 200, early_stopping_rounds = 30, ...
) {
  validation <- match.arg(validation)
  X <- xgb_features(data_full, leads, multi_back)
  Y <- select(X$data, Q_obs)
  fit <- function(Xi) {
    if (validation == "kfold") {
      kfold_xgboost(Xi, Y, nrounds = nrounds, learning_rate = 0.1, ...,
        max_depth = 3, min_child_weight = 6,
        subsample = 0.8, min_split_loss = 1, reg_lambda = 2)
    } else {
      xgb_holdout(Xi, Y, train_ratio, nrounds = nrounds,
        early_stopping_rounds = early_stopping_rounds,
        learning_rate = 0.1, verbosity = 0, ...,
        max_depth = 3, min_child_weight = 6,
        subsample = 0.8, min_split_loss = 1, reg_lambda = 2)
    }
  }

  listk(data_full, data = X$data, multi_back, validation, train_ratio,
    MetXGB = fit(X$MetXGB),
    HydroMetXGB = fit(X$HydroMetXGB),
    QlagXGB = map(X$QlagXGB, fit),
    HydroMetQlagXGB = map(X$HydroMetQlagXGB, fit),
    HydroMetQlagMultiXGB = map(X$HydroMetQlagMultiXGB, fit)
  )
}
