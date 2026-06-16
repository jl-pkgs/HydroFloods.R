# 构造 XGB 输入特征 (train_xgboost / predict_xgboost 共用, 保证特征一致)
# 返回有效观测行 data, 及 4 个模型族的特征:
#   - MetXGB          : 气象 P, PET
#   - HydroMetXGB     : P, PET, Q_sim
#   - QlagXGB         : 各 lead 的滞后流量 Q_t-lead
#   - HydroMetQlagXGB : 上述全部
#' @importFrom kfold add_previous
xgb_features <- function(data_full, leads = 1:12) {
  input <- data_full %>% add_previous(nlead = length(leads))
  data <- input[!is.na(Q_obs), ]
  vars_Q <- names(input) %>% .[grep("Q_t-", .)]
  names(leads) <- sprintf("lead_%02d", seq_along(leads))

  listk(data,
    MetXGB = select(data, P, PET = PET_Romanenko),
    HydroMetXGB = select(data, P, PET = PET_Romanenko, Q_sim),
    QlagXGB = map(leads, \(l) select(data, all_of(vars_Q[l]))),
    HydroMetQlagXGB = map(leads, \(l) select(data, P, PET = PET_Romanenko, Q_sim, all_of(vars_Q[l])))
  )
}

#' 训练 XGB 洪水预报后处理模型
#'
#' 对 4 个模型族 (MetXGB / HydroMetXGB / QlagXGB / HydroMetQlagXGB) 分别做
#' kfold 训练, 特征由 `xgb_features()` 构造. 配套预测见 [predict_xgboost()],
#' 表现检验见 [summary_xgboost()].
#' @param data_full 训练数据, 含 `site, time, Q_obs, P, Q_sim, PET_Romanenko`
#' @param leads 预见期 (小时)
#' @param ... 透传给 `kfold_xgboost()`
#' @return list: `data_full`, `data` (有效观测行), 及各模型族的 kfold 对象
#' @import xgboost
#' @importFrom kfold kfold_xgboost
#' @export
train_xgboost <- function(data_full, leads = 1:12, ...) {
  X <- xgb_features(data_full, leads)
  Y <- select(X$data, Q_obs)
  fit <- function(Xi) {
    kfold_xgboost(Xi, Y,
      nrounds = 200, early_stopping_rounds = 30, learning_rate = 0.1,
      ..., max_depth = 3, min_child_weight = 6,
      subsample = 0.8, gamma = 1, reg_lambda = 2
    )
  }

  listk(data_full, data = X$data,
    MetXGB = fit(X$MetXGB),
    HydroMetXGB = fit(X$HydroMetXGB),
    QlagXGB = map(X$QlagXGB, fit),
    HydroMetQlagXGB = map(X$HydroMetQlagXGB, fit)
  )
}
