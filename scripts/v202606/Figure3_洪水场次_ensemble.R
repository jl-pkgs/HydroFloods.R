#! /usr/bin/Rscript --no-init-file
# Dongdong Kong ----------------------------------------------------------------
# Copyright (c) 2026 Dongdong Kong. All rights reserved.
#
# 检查 ensemble mean 的洪水场次时间序列是否存在锯齿波动
source("scripts/main_pkgs.R")

# 从 summary$pred 长表取集合预测 (ensemble mean):
#   - Hydro 基线        : kfold = "-"
#   - XGB 集合平均(mean): kfold = "mean" (train 在率定期, test 在验证期, 拼成全序列)
#   - valid 的 OOF (kfold = "all") 此处不取
get_pred_ens <- function(pred, LEAD) {
  methods <- c("Hydro", "HydroMetXGB", "HydroMetQlagXGB")
  pred[kfold %in% c("-", "mean") & model %in% methods & lead %in% c("-", LEAD),
    .(time, model, Q_sim)] %>%
    mutate(model = factor(model, methods))
}

Figure3_ens_1site <- function(res, model, SITE, LEAD = "lead_03", outdir = "./Figures") {
  l <- res[[SITE]]
  fout <- glue("{outdir}/Figure3_ensemble_{SITE}_{model}_{LEAD}.svg")

  data_full <- rbind(l$data_calib, l$data_valid)
  c(data_obs, info_flood) %<-% flood_divide(data_full, SITE, extend = 3)
  nrow <- ceiling(nrow(info_flood) / 4)
  dat_obs <- data_obs[, .(group_name, time, P, Q_obs)]

  dat_sim <- get_pred_ens(l$summary$pred, LEAD) %>% merge(dat_obs)

  c(Q_min, Q_peak, q.max, prcp.max) %<-% get_config(SITE)
  p <- plot_FloodEvents_Qsim_models(dat_obs, dat_sim, prcp.max, q.max)

  print(fout)
  write_fig(p, fout, 12, 2.5 * nrow, show = FALSE)
}

Figure3_ens_1model <- function(model, ...) {
  load(glue("OUTPUT/V20260603/res_{model}.rda")) # res
  foreach(SITE = sites, i = icount()) %do% {
    Figure3_ens_1site(res, model, SITE, ...)
  }
}

# %%
.tmp <- foreach(model = models, i = icount()) %do% {
  runningId(i)
  Figure3_ens_1model(model)
}
# model <- models[5] # XAJ
# Figure3_ens_1model(model)
