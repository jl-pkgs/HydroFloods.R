#' XGBoost 参数敏感性测试：生成参数组、批量运行、计算评分并绘制 Figure4
source("scripts/main_pkgs.R")
devtools::load_all()
source("scripts/Figure4_xgb参数测试.R", encoding = "UTF-8")

model <- "XAJ"
SITE <- "县河"
sites <- c(SITE)

root <- "/mnt/z/GitHub/jl-pkgs/ModernHydroModels.jl" %>% path.mnt()
dir_root <- glue("{root}/Project_Shiyan2025/OUTPUT/version3_洪水摘录表_OnlyEvents")

f_forcing <- glue("{root}/apps/data/十堰_Forcing_hourly_ALL_v20260417_basins24.csv")
forcing <- fread(f_forcing) %>% select(-Q, -R, -Z, -area_km2, -Tair)

out_root <- "./OUTPUT/test_xgboost_v2"
out_fig <- "Figures/test_xgboost_v2"
dir.create(out_root, showWarnings = FALSE, recursive = TRUE)

par_grid <- make_xgb_par_grid(
  max_depth = c(2, 3),
  min_child_weight = c(5, 7, 9, 11, 13, 15, 20),
  eta = NULL, subsample = 1, lambda = NULL,
  nrounds = 200, early_stopping_rounds = 20
)

print(dim(par_grid))
print(head(par_grid))

pars_grid <- grid_to_pars(par_grid)
fwrite(par_grid, file.path(out_root, "parameter_grid.csv"))

df <- read_output(glue("{dir_root}/{model}")) %>% merge(forcing)

system.time({
  for (par_name in names(pars_grid)) {
    run_xgb_test(model, par_name, pars_grid[[par_name]],
      overwrite = FALSE, df = df, out_root = out_root)
  }
})

score <- build_xgb_score_table(
  model = model, SITE = SITE, out_root = out_root,
  fout = file.path(out_root, "parameter_score_alllead.csv")
)

print(score[seq_len(min(20, nrow(score))), .(
  rank, par_name, valid_nse_mean, valid_nse_min,
  pass_mean, pass_min, gap_mean, gap_max, rough2_mean, rank_score
)])

Figure4_xgb_par(
  f_score = file.path(out_root, "parameter_score_alllead.csv"),
  outdir = out_fig,
  top_n = Inf, label_n = 10, matrix_n = 10, overwrite = TRUE
)


Figure1_pid <- function(PID, model = "XAJ", SITE = "县河", LEAD = "lead_03",
  ftab = "Figures/test_xgboost_v2/Figure4_XGB参数方案编号表.csv",
  out_root = "./OUTPUT/test_xgboost_v2", outdir = "Figures/test_xgboost_v2/Figure1_top4") {
  tab <- fread(ftab)
  r <- tab[pid == PID][1]
  par_lab <- glue("{PID}_md{r$max_depth}_mcw{r$min_child_weight}")
  load(file.path(out_root, r$par_name, glue("res_{model}.rda")))
  Figure1_Qsim_1site(res, glue("{model}_{par_lab}"), SITE, LEAD = LEAD, outdir = outdir)
}

pids <- c("P001", "P002", "P003", "P004")
walk(pids, Figure1_pid)



# ===== v3 局部补充测试：根据 v2 结果扩展 =====

out_root <- "./OUTPUT/test_xgboost_v3"
out_fig <- "Figures/test_xgboost_v3"
dir.create(out_root, showWarnings = FALSE, recursive = TRUE)

g_md3 <- make_xgb_par_grid(
  max_depth = 3, min_child_weight = c(11, 13, 15, 17, 20),
  eta = NULL, subsample = c(1, 0.95, 0.9), lambda = c(1, 1.5, 2),
  nrounds = 200, early_stopping_rounds = 20
)

g_md2 <- make_xgb_par_grid(
  max_depth = 2, min_child_weight = c(5, 7, 9, 15, 20),
  eta = NULL, subsample = c(1, 0.95), lambda = c(1, 1.5),
  nrounds = 200, early_stopping_rounds = 20
)

par_grid <- unique(rbindlist(list(g_md3, g_md2), fill = TRUE), by = "par_name")

print(dim(par_grid))
print(head(par_grid))

pars_grid <- grid_to_pars(par_grid)
fwrite(par_grid, file.path(out_root, "parameter_grid.csv"))

system.time({
  for (par_name in names(pars_grid)) {
    run_xgb_test(model, par_name, pars_grid[[par_name]],
      overwrite = FALSE, df = df, out_root = out_root)
  }
})

score <- build_xgb_score_table(
  model = model, SITE = SITE, out_root = out_root,
  fout = file.path(out_root, "parameter_score_alllead.csv")
)

print(score[seq_len(min(20, nrow(score))), .(
  rank, par_name, valid_nse_mean, valid_nse_min,
  pass_mean, pass_min, gap_mean, gap_max,
  rough2_mean, rough2_p90, rank_score
)])

Figure4_xgb_par(
  f_score = file.path(out_root, "parameter_score_alllead.csv"),
  outdir = out_fig,
  top_n = Inf, label_n = 10, matrix_n = 10, overwrite = TRUE
)

Figure1_pid <- function(PID, model = "XAJ", SITE = "县河", LEAD = "lead_03",
  ftab = "Figures/test_xgboost_v3/Figure4_XGB参数方案编号表.csv",
  out_root = "./OUTPUT/test_xgboost_v3", outdir = "Figures/test_xgboost_v3/Figure1_top4") {
  tab <- fread(ftab)
  r <- tab[pid == PID][1]
  par_lab <- glue("{PID}_md{r$max_depth}_mcw{r$min_child_weight}")
  load(file.path(out_root, r$par_name, glue("res_{model}.rda")))
  Figure1_Qsim_1site(res, glue("{model}_{par_lab}"), SITE, LEAD = LEAD, outdir = outdir)
}

pids <- c("P001", "P002", "P003", "P004")
walk(pids, Figure1_pid)