# HydroFloods.R — 开发笔记

## 运行 R：用 `arf` 代替 `Rscript`

本机没有 `Rscript`，用 `arf`（Rust 编写的跨平台 R 控制台）跑脚本。

```bash
arf --vanilla --no-banner -e '<R 表达式>'
```

- `--vanilla` 不加载用户配置，`--no-banner` 去掉横幅，`-e` 求值后退出。
- **stderr 噪音多**：`arf` 把包注册信息、`proj_create` 警告、以及 **xgboost C 层堆栈** 打到 stderr。
  验证输出时用 `2>/dev/null`，或 `2>&1 | grep -v "Registered\|proj_create\|predict.ranger\|^ *from"`，否则真正的 `cat`/`print` 会被淹没。
- 包开发循环：`arf --vanilla --no-banner -e 'devtools::document(quiet=TRUE); devtools::load_all(quiet=TRUE); <测试>'`。
  改 `R/` 里的 `#' @export`/函数后，先 `document()` 再 `load_all()`；删函数记得手动 `rm man/<fn>.Rd`。
- **避坑**：xgboost 2.x 在 **0 行矩阵** 上 `predict` 会报 `Input pointer misalignment`（看似内存对齐 bug，实为空输入）。
  调 predict 前用 `if (nrow(Xi) == 0) return(NULL)` 守卫即可，与对齐无关。

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

逐 lead 的族用 `add_previous()` 生成的滞后流量 `Q_t-lead`；单模型族 `lead = "-"`。

### kfold 集合
- `kfold_xgboost`（kfold 包）返回 5 折：`$model` 是 5 个子模型的 list，`$ypred` 是 OOF 预测，`$gof` 含每折 train/test + `all`。
- `predict_kfold(models, X)`：5 个子模型分别预测 → 列 `k01..k05` + 集合平均 `mean`。集合平均通常 NSE 最优。

### 统一长表 + 共享评估
- `predict_xgboost` 输出 **长表** `[site, time, model, lead, Q_obs, kfold, Q_sim]`，含 Hydro 基线。
  `model` 列必须显式带上（QlagXGB 与 HydroMetQlagXGB 共用 `lead`，不能由 `lead` 反推）。
- `eval_floods(pred, d_full)` 是共享评估器：按 `.(model, lead, kfold)` 算洪水合格率（`eval_Qmax`）+ 场次信息。
- `summary_xgboost(object, newdata = NULL, leads = seq_along(object$HydroMetQlagXGB))`：
  - `newdata = NULL` → 用 `object$data_full`（率定期/样本内）；传 `data_valid` → 验证期（样本外）。**一个函数覆盖率定期与验证期**（原 `cal_pass_rate` 已删，功能合并于此）。
  - `leads` **从 object 推断**，不写死 `1:12`——否则验证用的 leads 与训练不一致会取到 `NULL` 子模型而报错。
  - 返回 `listk(pred, gof, info_pass, info_flood)`；`newdata` 无观测（`Q_obs` 全 NA）时 `warning` 并返回空表。

### 关键约定
- 长表统一 `melt(..., variable.factor = FALSE)`，便于和标量列拼接。
- **标量在前的 `cbind` 会丢失 data.table 类**（退化为 data.frame，`rbind(..., fill=TRUE)` 失效），改用 `rbindlist(list(...), use.names = TRUE, fill = TRUE)`。
- 数据集 `version3_洪水摘录表_OnlyEvents` 的观测止于 2023-10；用 `t0=2023-12-31` 切分时验证期无观测，验证为空属正常（step2 改用 `year_end = max(有观测年份) - 1` 来留出验证期）。
- `R/xgboost_param_score.R` 是废弃代码，勿参考。
