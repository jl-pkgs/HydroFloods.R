# 验证 XGB 收紧后 train/valid gap 是否收窄、早停是否生效 (单站快验证)
# 用法: arf --vanilla --no-banner scripts/test_xgb_params.R 2>/dev/null
# 先 load_all 本地 kfold, 再 source main_pkgs (其 load_all(".") 才会把
# HydroFloods 的 kfold_xgboost 导入绑到本地 kfold, 而非已安装版本)
devtools::load_all("/mnt/z/GitHub/cug-hydro/kfold.R")
source("scripts/main_pkgs.R")

# --- 取单站率定期数据 (同 step2_xgboost.Rmd) ---
root <- "/mnt/z/GitHub/jl-pkgs/ModernHydroModels.jl" %>% path.mnt()
dir_root <- glue("{root}/Project_Shiyan2025/OUTPUT/version3_洪水摘录表_OnlyEvents")
f_forcing <- glue("{root}/apps/data/十堰_Forcing_hourly_ALL_v20260417_basins24.csv")
forcing <- fread(f_forcing) %>% select(-Q, -R, -Z, -area_km2, -Tair)

model <- models[5]
SITE <- sites[2]
df <- dir2(glue("{dir_root}/{model}"), "Output.*.csv") %>%
  map(fread) %>% rbindlist() %>% merge(forcing)

data_full <- df[site == SITE, ]
year_end <- max(data_full[!is.na(Q_obs), year(time)]) - 1
data_calib <- data_full[year(time) < year_end]

# --- 训练 + 检查 gap 与早停轮数 ---
xgb <- train_xgboost(data_calib)
fit <- xgb$HydroMetQlagXGB[[1]]

fprintf("[%s | %s] lead 1 HydroMetQlagXGB\n", model, SITE)
print(fit$gof) # 比较 type=="train" vs "valid" 的 NSE gap
iters <- map_dbl(fit$model, ~ as.integer(xgb.attr(.x, "best_iteration"))) # 每折早停轮数, 应 << 500
fprintf("best_iteration (5 folds): %s\n", paste(iters, collapse = ", "))
