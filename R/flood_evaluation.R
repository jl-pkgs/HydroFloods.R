# 水文预报规范2008

# 1. 洪峰
eval_Qmax <- function(Qobs, Qsim, ...) {
  sim <- max(Qsim, na.rm = TRUE)
  obs <- max(Qobs, na.rm = TRUE)
  err <- sim - obs

  err_permit <- diff(range(Qobs, na.rm = TRUE)) * 0.2 # 实测变幅的20%
  if (err_permit < 0.05 * obs) {
    err_permit <- 0.05 * obs
  }
  # abs(err) <= err_permit
  data.table(obs, sim, err, err_permit, passed = abs(err) <= err_permit)
}

# 2. 洪峰时间
eval_Qtime <- function(Qobs, Qsim, ...) {
  obs <- which.max(Qobs)
  sim <- which.max(Qsim)

  err <- sim - obs
  err_permit <- obs * 0.3

  if (err_permit < 1) {
    err_permit <- 1
  } else if (err_permit < 3) {
    err_permit <- 3
  } else {
    err_permit <- round(3)
  }
  # abs(err) <= err_permit
  data.table(obs, sim, err, err_permit, passed = abs(err) <= err_permit)
}

# 3. 径流深
eval_Runoff <- function(Qobs, Qsim, area) {
  obs <- sum(Qobs, na.rm = TRUE) %>% Q2R(area) # 径流深
  sim <- sum(Qsim, na.rm = TRUE) %>% Q2R(area) #

  err <- sim - obs
  err_permit <- obs * 0.2

  if (err_permit > 20) {
    err_permit <- 20.
  } else if (err_permit <= 3) {
    err_permit <- 3.
  }
  abs(err) <= err_permit
  data.table(obs, sim, err, err_permit, passed = abs(err) <= err_permit)
}

evaluation <- function(Qobs, Qsim, area) {
  Qmax <- eval_Qmax(Qobs, Qsim)
  Qtime <- eval_Qtime(Qobs, Qsim)
  R <- eval_Runoff(Qobs, Qsim, area)
  listk(Qmax, Qtime, R)
}

flood_evaluation <- function(Q_obs, Q_sim, time, info_flood, area = 322) {
  df = data.table(time, Q_obs, Q_sim)
  dat = merge_flood(df, info_flood)

  r = dat %>%
    group_by(group, group_name) %>%
    group_map(\(d, grp) {
      l = with(d, evaluation(Q_obs, Q_sim, area))
      map(l, \(x) cbind(grp, x))
    })

  perf = purrr::transpose(r) %>% map(rbindlist)
  perf_s = map(perf, \(d) d[, hydroTools::GOF(obs, sim)]) # %>% melt_list("index")

  ## 对洪峰进行限定
  # goal = perf_s$Qmax$MAE + R2Q(perf_s$R$MAE, area)
  listk(event = perf, event_summary = perf_s, all = hydroTools::GOF(Q_obs, Q_sim))
}

## 对合格率和洪水期NSE进行限定
