read_output <- function(indir) {
  dir2(indir, "Output.*.csv") %>%
    map(fread) %>%
    rbindlist()
}

# 生成 XGBoost 参数组合；NULL 参数不传入模型，保留默认值
make_xgb_par_grid <- function(
  max_depth = c(2, 3), min_child_weight = c(5, 7, 9, 11, 13, 15, 20),
  eta = NULL, subsample = 1, lambda = NULL, nrounds = 200,
  early_stopping_rounds = 20, colsample_bytree = NULL, gamma = NULL
) {
  fmt <- function(x) gsub("\\.", "", as.character(x))
  args <- list(
    max_depth = max_depth, min_child_weight = min_child_weight, eta = eta,
    subsample = subsample, lambda = lambda, nrounds = nrounds,
    early_stopping_rounds = early_stopping_rounds,
    colsample_bytree = colsample_bytree, gamma = gamma
  )
  args <- args[!sapply(args, is.null)]
  g <- as.data.table(do.call(expand.grid, c(args, KEEP.OUT.ATTRS = FALSE)))
  g[, par_name := paste0(
    "md", max_depth, "_mcw", min_child_weight,
    if ("eta" %in% names(g)) paste0("_eta", fmt(eta)) else "_defaulteta",
    if ("subsample" %in% names(g)) paste0("_sub", fmt(subsample)) else "",
    if ("lambda" %in% names(g)) paste0("_lam", fmt(lambda)) else "", "_n", nrounds
  )]
  g
}

grid_to_pars <- function(par_grid) {
  cols <- setdiff(names(par_grid), "par_name")
  setNames(lapply(seq_len(nrow(par_grid)), \(i) as.list(par_grid[i, ..cols])), par_grid$par_name)
}

#' 单站点 XGBoost 订正模型训练
train_xgboost_par <- function(
  data_full, leads = 1:12, nrounds = 200, early_stopping_rounds = 20,
  max_depth = 3, min_child_weight = 5, eta = NULL, subsample = 1,
  colsample_bytree = NULL, lambda = NULL, gamma = NULL
) {
  model <- function(X, Y) {
    args <- list(
      X = X, Y = Y, nrounds = nrounds, early_stopping_rounds = early_stopping_rounds,
      max_depth = max_depth, min_child_weight = min_child_weight, subsample = subsample
    )
    if (!is.null(eta)) args$eta <- eta
    if (!is.null(colsample_bytree)) args$colsample_bytree <- colsample_bytree
    if (!is.null(lambda)) args$lambda <- lambda
    if (!is.null(gamma)) args$gamma <- gamma
    do.call(kfold_xgboost, args)
  }

  input <- data_full %>% add_previous()
  data <- input[!is.na(Q_obs), ]
  vars_Q <- names(input) %>% .[grep("Q_t-", .)]
  Y <- select(data, Q_obs)
  leads <- leads %>% set_names(., .)

  X <- select(data, P, PET = PET_Romanenko, Q_sim)
  r_HydroMetXGB <- model(X, Y)

  res_HydroMetQlagXGB <- map(leads, function(lead) {
    runningId(lead)
    X <- select(data, P, PET = PET_Romanenko, Q_sim, all_of(vars_Q[lead]))
    model(X, Y)
  })

  listk(data_full, data = data, HydroMetXGB = r_HydroMetXGB, HydroMetQlagXGB = res_HydroMetQlagXGB)
}

# 批量运行单组参数并保存结果
run_xgb_test <- function(model, par_name, par, overwrite = FALSE, df = NULL, out_root = "./OUTPUT/test_xgboost") {
  outdir <- glue("{out_root}/{par_name}")
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  fout <- glue("{outdir}/res_{model}.rda")
  if (isfile(fout) && !overwrite) {
    return()
  }

  if (is.null(df)) df <- read_output(glue("{dir_root}/{model}")) %>% merge(forcing)
  print(glue("{model} | {par_name}"))

  res <- map(seq_along(sites), function(i) {
    SITE <- sites[i]
    fprintf("[%d] %s \n", i, SITE)
    data_full <- df[site == SITE, ]
    xgb <- do.call(train_xgboost_par, c(list(data_full = data_full), par))
    info <- cal_pass_rate(xgb)
    listk(data_full, xgb, info)
  }) %>% set_names(sites)

  save(res, file = fout)
}

# 二阶差分 RMS；k=2 时对应离散二阶导 root square
rough_rms <- function(x, k = 2) {
  x <- x[is.finite(x)]
  if (length(x) <= k) {
    return(NA_real_)
  }
  for (i in seq_len(k)) x <- diff(x)
  sqrt(mean(x^2, na.rm = TRUE))
}

q90 <- function(x) {
  if (sum(is.finite(x)) == 0) {
    return(NA_real_)
  }
  as.numeric(quantile(x, 0.90, na.rm = TRUE))
}

score_one_xgb_par <- function(model, par_name, SITE = "县河", out_root = "./OUTPUT/test_xgboost") {
  load(glue("{out_root}/{par_name}/res_{model}.rda"))
  l <- res[[SITE]]
  info <- cal_pass_rate(l$xgb)

  gof <- as.data.table(info$gof$HydroMetQlagXGB)
  pass <- as.data.table(info$info_pass)
  gof <- gof[as.character(lead) != "-"]
  pass <- pass[as.character(lead) != "-" & model == "HydroMetQlagXGB"]

  train <- gof[mode == "train", .(train_nse = mean(NSE, na.rm = TRUE)), by = lead]
  valid <- gof[mode == "test", .(valid_nse = mean(NSE, na.rm = TRUE)), by = lead]
  dat_gof <- merge(train, valid, by = "lead")
  dat_gof[, gap := train_nse - valid_nse]

  pred <- get_pred(l$xgb)
  dat_obs <- flood_divide(l$xgb$data_full, SITE, extend = 3)[[1]][, .(group_name, time, Q_obs)]
  leads_all <- unique(as.character(pred$HydroMetQlagXGB$lead))

  rough <- rbindlist(lapply(leads_all, function(LEAD) {
    dat_sim <- pred$HydroMetQlagXGB[as.character(lead) == LEAD, .(time, Q_sim)]
    dat <- merge(dat_obs, dat_sim, by = "time")
    if (nrow(dat) == 0) {
      return(data.table())
    }
    out <- dat[, .(rough2 = rough_rms(Q_sim, k = 2)), by = group_name]
    out[, lead := LEAD]
    out
  }), fill = TRUE)

  data.table(
    par_name = par_name,
    valid_nse_mean = mean(dat_gof$valid_nse, na.rm = TRUE),
    valid_nse_min = min(dat_gof$valid_nse, na.rm = TRUE),
    gap_mean = mean(dat_gof$gap, na.rm = TRUE),
    gap_max = max(dat_gof$gap, na.rm = TRUE),
    pass_mean = mean(pass$perc_pass, na.rm = TRUE),
    pass_min = min(pass$perc_pass, na.rm = TRUE),
    rough2_mean = mean(rough$rough2, na.rm = TRUE),
    rough2_p90 = q90(rough$rough2)
  )
}

# 汇总参数组评价指标并排序
build_xgb_score_table <- function(
  model = "XAJ", SITE = "县河", out_root = "./OUTPUT/test_xgboost",
  fout = "./OUTPUT/test_xgboost/parameter_score_alllead.csv"
) {
  par_names <- dir(out_root, full.names = FALSE)
  par_names <- par_names[file.exists(file.path(out_root, par_names, glue("res_{model}.rda")))]

  score <- rbindlist(lapply(par_names, \(par_name) score_one_xgb_par(model, par_name, SITE, out_root)), fill = TRUE)
  score[, r_valid := frank(-valid_nse_mean)]
  score[, r_gap := frank(gap_mean)]
  score[, r_pass_mean := frank(-pass_mean)]
  score[, r_pass_min := frank(-pass_min)]
  score[, r_rough_mean := frank(rough2_mean)]
  score[, r_rough_p90 := frank(rough2_p90)]

  score[, rank_score := 0.25 * r_valid + 0.15 * r_gap +
    0.20 * r_pass_mean + 0.10 * r_pass_min +
    0.20 * r_rough_mean + 0.10 * r_rough_p90]

  score <- score[order(rank_score)]
  score[, rank := .I]
  fwrite(score, fout)
  score
}
