#! /usr/bin/Rscript --no-init-file

pacman::p_load(Ipaper, data.table, dplyr, lubridate, purrr, glue, kfold)
devtools::load_all(".")

models <- c("m05_ihacres_7p_1s", "m07_gr4j_4p_2s", "m09_susannah1_6p_2s",
  "m28_xinanjiang_12p_4s", "XAJ")
sites <- c("松柏（二）", "县河", "房县", "延坝", "孤山")

root <- path_mnt("/mnt/z/GitHub/jl-pkgs/ModernHydroModels.jl")
dir_root <- glue("{root}/Project_Shiyan2025/OUTPUT/version3_洪水摘录表_OnlyEvents")
out_dir <- "./OUTPUT/XGboost_aux"
f_aux <- "/share/GitHub/CUG-hydro/Shijiaqi/Paper_Figures/DATA/SM_GRACE_monthly_basins_2012_2024.csv"

dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
read_output <- \(indir) rbindlist(lapply(dir2(indir, "Output.*.csv"), fread), fill = TRUE)

train_xgboost_aux <- function(data_full, leads = 1:12,
  aux_vars = c("SM_storage_lag1", "GRACE_TWSA_lag1", "mon_sin", "mon_cos"), ...) {

  model <- \(X, Y, ...) kfold_xgboost(X, Y, nrounds = 200, early_stopping_rounds = 20,
    ..., max_depth = 3, min_child_weight = 5, subsample = 1)

  input <- data_full %>% add_previous(nlead = length(leads))
  data <- input[!is.na(Q_obs)]
  vars_Q <- names(input)[grep("Q_t-", names(input))]
  aux_vars <- intersect(aux_vars, names(data))
  Y <- data[, .(Q_obs)]
  names(leads) <- sprintf("lead_%02d", seq_along(leads))

  get_X <- function(vars) {
    X <- data[, ..vars]
    if ("PET_Romanenko" %in% names(X)) setnames(X, "PET_Romanenko", "PET")
    X
  }

  vars_base <- c("P", "PET_Romanenko", "Q_sim", aux_vars)
  HydroMetXGB <- model(get_X(vars_base), Y)
  HydroMetQlagXGB <- map(leads, \(lead) model(get_X(c(vars_base, vars_Q[lead])), Y))

  listk(data_full, data = data,
    features = list(
      HydroMetXGB = names(get_X(vars_base)),
      HydroMetQlagXGB = map(leads, \(lead) names(get_X(c(vars_base, vars_Q[lead]))))
    ),
    HydroMetXGB, HydroMetQlagXGB)
}

forcing <- fread(glue("{root}/apps/data/十堰_Forcing_hourly_ALL_v20260417_basins24.csv"))
forcing[, c("Q", "R", "Z", "area_km2", "Tair") := NULL]

aux <- fread(f_aux)
aux[, ym := as.IDate(ym)]
aux <- aux[, .(site, ym_lag1 = ym, SM_storage_lag1 = SM_storage,
  GRACE_TWSA_lag1 = GRACE_TWSA)]

forcing[, time := as.POSIXct(time, tz = "UTC")]
forcing[, time_local := with_tz(time, "Asia/Shanghai")]
forcing[, ym := as.IDate(format(floor_date(time_local, "month"), "%Y-%m-01"))]
forcing[, ym_lag1 := as.IDate(format(as.Date(ym) %m-% months(1), "%Y-%m-01"))]
forcing[, `:=`(mon_sin = sin(2 * pi * month(time_local) / 12),
  mon_cos = cos(2 * pi * month(time_local) / 12), rid = .I)]

forcing_aux <- merge(forcing, aux, by = c("site", "ym_lag1"), all.x = TRUE, sort = FALSE)
setorder(forcing_aux, rid)
forcing_aux[, c("ym", "ym_lag1", "time_local", "rid") := NULL]

run_xgb_aux <- function(model, overwrite = FALSE) {
  fout <- glue("{out_dir}/res_{model}.rda")
  if (isfile(fout) && !overwrite) return()

  df <- read_output(glue("{dir_root}/{model}"))
  df[, time := as.POSIXct(time, tz = "UTC")]

  cols <- c("site", "time", "PET_Romanenko", "SM_storage_lag1",
    "GRACE_TWSA_lag1", "mon_sin", "mon_cos")
  df <- merge(df, forcing_aux[, ..cols], by = c("site", "time"), all.x = TRUE)

  res <- map(seq_along(sites), \(i) {
    SITE <- sites[i]
    fprintf("[%d] %s\n", i, SITE)
    data_full <- df[site == SITE]
    xgb <- train_xgboost_aux(data_full)
    info <- cal_pass_rate(xgb)
    listk(data_full, xgb, info)
  }) %>% set_names(sites)

  save(res, file = fout)
}

system.time(map(models, run_xgb_aux, overwrite = TRUE))



fig_dir <- "./Figures/XGboost_aux"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

Figure1_Qsim_1model <- function(model, ...) {
  load(glue("./OUTPUT/XGboost_aux/res_{model}.rda"))
  foreach(SITE = sites, i = icount()) %do% {
    Figure1_Qsim_1site(res, model, SITE, outdir = fig_dir, ...)
  }
}
map(models, \(model) Figure1_Qsim_1model(model))
