# HydroFloods.R — 开发笔记


## XGB 后处理模型的函数设计（`R/xgboost.R`, `R/xgboost_validate.R`）

仿 R 自带 **fit / predict / summary** 习惯的三元组：
`train_xgboost`（fit）→ `predict_xgboost`（predict）→ `summary_xgboost`（评估表现）。

### 模型族（feature 消融对比）
`xgb_features(data_full, leads)` 是 **训练与预测共用** 的特征构造器（保证特征一致、消除重复）：

| model           | 特征                      | 含义                       | 结构    |
| --------------- | ------------------------- | -------------------------- | ------- |
| Hydro           | 原始 `Q_sim`              | 传统水文模型基线（无 XGB） | 单序列  |
| MetXGB          | `P, PET`                  | 纯气象驱动                 | 单模型  |
| HydroMetXGB     | `P, PET, Q_sim`           | 气象 + 水文                | 单模型  |
| QlagXGB         | `Q_t-lead`                | 纯滞后流量                 | 逐 lead |
| HydroMetQlagXGB | `P, PET, Q_sim, Q_t-lead` | 全特征                     | 逐 lead |
| HydroMetQlagMultiXGB | `P, PET, Q_sim, Qobs(t-τ:t-τ-3), dQobs, mean3` | 多时刻前期流量 | 逐 lead |

逐 lead 的模型族用 `add_previous()` 生成滞后流量；Multi 默认使用论文最终
`back03` 定义，`multi_back = 3`。单模型族 `lead = "-"`。

### kfold 集合（kfold 包重构后的新 API）
- `kfold_xgboost(X, Y, ...)` 返回 `kfold` 对象：`$data`（X, Y）、`$index`（5 折留出索引）、`$model`（5 个子模型 list）。**不再有顶层 `$ypred` / `$gof`**。
- `train_xgboost(validation = "holdout", train_ratio = 0.7)` 按时间顺序以前 70% 训练、后 30% 验证，并保持相同的 `kfold` 对象结构。
- `predict.kfold(fit, newdata, mode)`：一次给出 5 折各自预测 + 集合平均 `$ensemble`。`mode` 决定 train/valid/test 语义：
  - `train`：屏蔽各折自己的留出行 → 样本内拟合；`valid`：仅留出行 → OOF（不泄漏）；`test`：用 `newdata` 全量预测（样本外）。
- `GOF.kfold(fit)` 给 train+valid 拟合优度，`GOF(fit, test = list(X, Y))` 给 test；`kfold` 列含各折 + `ensemble`。

### 统一长表 + 共享评估
- `predict_xgboost(object, newdata, leads, mode)` 输出 **长表** `[mode, site, time, Q_obs, model, lead, kfold, Q_sim]`，含 Hydro 基线（`kfold = "-"`），XGB 各族取集合平均（`kfold = "ensemble"`）。一个函数 + `mode` 覆盖 train/valid/test。
  - `model` 列必须显式带上（QlagXGB 与 HydroMetQlagXGB 共用 `lead`，不能由 `lead` 反推）。
  - train/valid 走 kfold 内部训练集（`newdata` 须传 `object$data_full`），test 用 `newdata` 特征。
- `xgb_map(object, X, f, leads)`：遍历 5 个模型族并对齐 `(fit, 特征)`。
- `summary_xgboost(object, newdata = NULL, leads = seq_along(object$HydroMetQlagXGB))`：
  - train/valid 恒返回（从 `object` 内部算）；传 `newdata` 追加 test。
  - **GOF 直接由 `pred` 长表逐 `(model, lead, mode)` 算**（`pred[!is.na(Q_sim), GOF(Q_obs, Q_sim), .(model, lead, kfold, mode)]`），与 `GOF.kfold` 的 ensemble 行等价，省去 `gather_gof`。
  - `flood_pass` 算洪水合格率（`eval_Qmax`）；率定期划分一次，train/valid 共用。
  - `leads` **从 object 推断**，不写死 `1:12`——否则验证用的 leads 与训练不一致会取到 `NULL` 子模型而报错。
  - 返回 `listk(pred, gof, info_pass, info_flood)`；`newdata` 无观测（`Q_obs` 全 NA）时 `warning` 并跳过 test。

### 关键约定
- **标量在前的 `cbind` 会丢失 data.table 类**（退化为 data.frame，`rbind(..., fill=TRUE)` 失效）；`pred` 必须保持 data.table（Figure3 用 `pred[...]` 取数），故加 `mode` 列用 `ans[, mode := mode]` 而非 `dplyr::mutate`。
- 数据集 `version3_洪水摘录表_OnlyEvents` 的观测止于 2023-10；用 `t0=2023-12-31` 切分时验证期无观测，验证为空属正常（step2 改用 `year_end = max(有观测年份) - 1` 来留出验证期）。
- `R/xgboost_param_score.R` 是废弃代码，勿参考。
