#' @import xgboost
NULL

train_xgboost <- function(d_full, leads = 1:12, ...) {
  model <- function(X, Y, ...) {
    kfold_xgboost(X, Y,
      nrounds = 200, early_stopping_rounds = 20, # learning_rate = 0.1,
      ..., max_depth = 3, min_child_weight = 5, subsample = 1
    )
  }

  vars_Q <- names(d_full) %>% .[grep("Q_t-", .)]
  d <- d_full[!is.na(Q_obs), ]
  Y <- select(d, Q_obs)
  leads <- leads %>% set_names(., .)

  X <- select(d, P, PET = PET_Romanenko, Q_sim)
  r_HydroMetXGB <- model(X, Y, ...)

  res_HydroMetQlagXGB <- foreach(lead = leads, i = icount()) %do% {
    runningId(i)
    X <- select(d, P, PET = PET_Romanenko, Q_sim, all_of(vars_Q[lead]))
    r <- model(X, Y, ...)
  }
  list(data = d, HydroMetXGB = r_HydroMetXGB, HydroMetQlagXGB = res_HydroMetQlagXGB)
}


## 检验洪水的合格率
cal_pass_rate <- function(res, d_full) {
  d <- res$data # d <- d_full[!is.na(Q_obs), ]

  ## flood_events 信息
  c(data, info_flood) %<-% flood_divide(d_full, SITE)
  d_flood <- data[, .(group, group_name, site, time, Q_obs)]

  d_Hydro <- get_pred_Hydro(data)
  d_HydroMetXGB <- get_pred_HydroMetXGB(res$HydroMetXGB, d)
  d_HydroMetQlagXGB <- get_pred_HydroMetQlagXGB(res$HydroMetQlagXGB, d)

  lst <- list(Hydro = d_Hydro, HydroMetXGB = d_HydroMetXGB, HydroMetQlagXGB = d_HydroMetQlagXGB) %>%
    map(\(x) merge(d_flood, x, by = "time"))

  n_flood <- d_flood$group_name %>% unique_length()
  info_pass <- map(lst, function(dat){
    info <- dat[, eval_Qmax(Q_obs, Q_sim), .(group, group_name, lead)]
    info[passed == TRUE, .(perc_pass = .N / n_flood), .(lead)]
  }) %>% melt_list("model") %>% arrange(model, lead)

  gof <- list(
    Hydro = data[, GOF(Q_obs, Q_sim)], 
    HydroMetXGB = res$HydroMetXGB$gof[kfold == "all", ],
    HydroMetQlagXGB = tidy_gof(res$HydroMetQlagXGB) %>% melt_list("lead")
  )
  listk(info_pass, info_flood, gof)
}

tidy_gof <- \(lst) map(lst, \(l) l$gof[kfold == "all", ])


get_pred_HydroMetQlagXGB <- function(res, d) {
  dat <- map(res, "ypred") %>%
    do.call(cbind, .) %>%
    as.data.table() %>%
    set_names(sprintf("lead_%02d", 1:length(res)))

  cbind(time = d$time, dat) %>%
    melt("time", variable.name = "lead", value.name = "Q_sim")
}

get_pred_HydroMetXGB <- function(res, d) {
  dat <- res$ypred %>%
    as.data.table() %>%
    set_names("Q_sim")
  cbind(time = d$time, lead = "-", dat)
}

get_pred_Hydro <- function(d) {
  d[, .(time, lead = "-", Q_sim)]
}
