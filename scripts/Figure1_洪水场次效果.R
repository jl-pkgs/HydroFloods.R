#! /usr/bin/Rscript --no-init-file
# Dongdong Kong ----------------------------------------------------------------
# Copyright (c) 2025 Dongdong Kong. All rights reserved.
source("scripts/main_pkgs.R")
models <- c("m05_ihacres_7p_1s", "m07_gr4j_4p_2s", "m09_susannah1_6p_2s", "m28_xinanjiang_12p_4s", "XAJ")

Figure1_Qsim_1site <- function(res, model, SITE, LEAD = "lead_03", outdir="./Figures") {
  l = res[[SITE]]
  fout = glue("{outdir}/Figure1_Qsims_{SITE}_{model}_{LEAD}.svg")

  xgb <- l$xgb
  pred <- get_pred(xgb)
  # info_pass = cal_pass_rate(xgb) 
  c(data_obs, info_flood) %<-% flood_divide(xgb$data_full, SITE, extend = 3) # hydro
  nrow <- ceiling(nrow(info_flood) / 4)
  dat_obs <- data_obs[, .(group_name, time, P, Q_obs)]

  dat_sim <- melt_list(list(
    Hydro = pred$Hydro[, .(time, Q_sim)],
    HydroMetXGB = pred$HydroMetXGB[, .(time, Q_sim)],
    HydroMetQlagXGB = pred$HydroMetQlagXGB[lead == LEAD, .(time, Q_sim)]
  ), "model") %>% merge(dat_obs) %>%
    mutate(model = factor(model, c("Hydro", "HydroMetXGB", "HydroMetQlagXGB")))

  c(Q_min, Q_peak, q.max, prcp.max) %<-% get_config(SITE)
  p <- plot_FloodEvents_Qsim_models(dat_obs, dat_sim, prcp.max, q.max)

  print(fout)
  write_fig(p, fout, 12, 2.5 * nrow, show = FALSE)
}

Figure1_Qsim_1model <- function(model, ...) {
  load(glue("./OUTPUT/res_{model}.rda")) # res
  foreach(SITE = sites, i = icount()) %do% {
    Figure1_Qsim_1site(res, model, SITE, ...)
  }
}

# InitCluster(6)

