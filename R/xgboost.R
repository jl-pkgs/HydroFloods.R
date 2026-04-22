#' add_previous
#' @param d with the variable of `Q_obs`
#' @export
add_previous <- function(d, nlead = 12) {
  Qs <- previous_tn(d$Q_obs, nlead)[, -1] %>%
    as.data.table() %>%
    rename_with(\(x) paste0("Q_", x))
  cbind(d, Qs)
}

#' @import xgboost
#' @export
train_xgboost <- function(d_full, leads = 1:12, ...) {
  model <- function(X, Y, ...) {
    kfold_xgboost(X, Y,
      nrounds = 200, early_stopping_rounds = 20, # learning_rate = 0.1,
      ..., max_depth = 3, min_child_weight = 5, subsample = 1
    )
  }

  input <- d_full %>% add_previous()
  data <- input[!is.na(Q_obs), ]
  vars_Q <- names(input) %>% .[grep("Q_t-", .)]

  Y <- select(data, Q_obs)
  leads <- leads %>% set_names(., .)

  X <- select(data, P, PET = PET_Romanenko, Q_sim)
  r_HydroMetXGB <- model(X, Y)

  res_HydroMetQlagXGB <- map(leads, function(lead) {
    runningId(lead)
    X <- select(data, P, PET = PET_Romanenko, Q_sim, all_of(vars_Q[lead]))
    r <- model(X, Y)
  })
  list(data = data, HydroMetXGB = r_HydroMetXGB, HydroMetQlagXGB = res_HydroMetQlagXGB)
}


## 检验洪水的合格率
#' @export
cal_pass_rate <- function(res_xgb, d_full) {
  input <- res_xgb$data # d <- d_full[!is.na(Q_obs), ]

  ## flood_events 信息
  c(data_flood, info_flood) %<-% flood_divide(d_full, SITE)
  d_flood <- data_flood[, .(group, group_name, site, time, Q_obs)]
  n_flood <- d_flood$group_name %>% unique_length()

  lst <- list(
    Hydro = get_pred_Hydro(data_flood),
    HydroMetXGB = get_pred_HydroMetXGB(res_xgb$HydroMetXGB, input),
    HydroMetQlagXGB = get_pred_HydroMetQlagXGB(res_xgb$HydroMetQlagXGB, input)
  ) %>% map(\(x) merge(d_flood, x, by = "time"))

  info_pass <- map(lst, function(dat) {
    info <- dat[, eval_Qmax(Q_obs, Q_sim), .(group, group_name, lead)]
    info[passed == TRUE, .(perc_pass = .N / n_flood), .(lead)]
  }) %>% melt_list("model") %>% arrange(model, lead)

  gof <- list(
    Hydro = input[, GOF(Q_obs, Q_sim)],
    HydroMetXGB = res_xgb$HydroMetXGB$gof[kfold == "all", ],
    HydroMetQlagXGB = tidy_gof(res_xgb$HydroMetQlagXGB) %>% melt_list("lead")
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
