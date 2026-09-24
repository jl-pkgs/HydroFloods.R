# HydroFloods.R

<!-- badges: start -->
[![R-CMD-check](https://github.com/jl-pkgs/HydroFloods.R/workflows/R-CMD-check/badge.svg)](https://github.com/jl-pkgs/HydroFloods.R/actions)
<!-- badges: end -->

> ModernHydro山洪预报系统，需配合`ModernHydroModels.jl`一起使用。

## 修改配置文件
```yaml
# 预报配置文件 — 孤山站
app: /home/kong/julia_apps/bin/ModernHydro # Julia ModernHydroModels路径

# ── 数据路径 ───────────────────────────────────────────────────────────────────
forcing_calib:    "apps/X1_孤山.csv"   # 历史率定数据（X1）
forcing_forecast: "apps/X2_孤山.csv"   # 近实时 + 预报强迫数据（X2）

# ── 站点 / 模型 ────────────────────────────────────────────────────────────────
site:     "孤山"    # 站点名称（用于输出文件命名）
model:    "XAJ"       # 可选：XAJ / GR4J / m07_gr4j_4p_2s / m05_ihacres_7p_1s 等
dir_root: "apps" # 输出目录（不存在则自动创建）

# ── 预报设置 ───────────────────────────────────────────────────────────────────
t0:    "2023-10-01 00:00:00"  # 预报起点（本地时间）；留空 "" 则取 X2 最后时刻
n_fc:  24                     # t0=X2末尾时自动延伸的预报时长（小时）
ratio: 0.0                    # 未来降水系数：0=填零，>0 则 ratio × 近期均值

# ── 率定设置 ───────────────────────────────────────────────────────────────────
force_calib: false  # true=强制重新率定；false=有缓存则直接复用
maxn:   3000        # 优化迭代次数（越大越精确，但耗时越长）
n_warm: 90          # X2 头部预热步数（用于无重叠情景）

# ── XGBoost 后处理设置 ─────────────────────────────────────────────────────────
xgb_run: true
xgb_force_calib: false
xgb_nlead: 24 # 当前只做未来 12 小时
```

`HydroMet-QlagMulti` 使用 `P(t) + PET(t) + Q_sim(t)`、从
`Qobs(t-τ)` 到 `Qobs(t-τ-3)` 的四个前期流量、相邻流量差以及前三项均值。
它已作为现有 XGBoost 后处理流程中的第 5 个模型族参与训练、检验和预报。
`train_xgboost()` 默认使用 5 折交叉验证；论文式时间留出可设置
`validation = "holdout", train_ratio = 0.7`，即前 70% 训练、后 30% 验证。

## 一建运行
```bash
# Copyright (c) 2026 Dongdong Kong & JiaQi Shi
Rscript apps/ModernHydroAPP.R apps/config_GuShan.yaml 
# 注意文件路径可能需要修改
```

**模型精度**
![](Figures/Figure2_NSE.svg)

**洪峰合格率**
![](Figures/Figure3_洪水合格率.svg)
