test_that("HydroMet-QlagMulti uses the paper back03 features", {
  d <- data.table(
    site = "A",
    time = as.POSIXct("2024-01-01", tz = "UTC") + 0:8 * 3600,
    Q_obs = 100 + 0:8,
    P = 1,
    PET_Romanenko = 2,
    Q_sim = 90 + 0:8
  )

  x <- HydroFloods:::xgb_features(d, leads = 1:3)$HydroMetQlagMultiXGB$lead_03
  expect_equal(names(x), c(
    "P", "PET", "Q_sim", "Qobs_lag00", "Qobs_lag01", "Qobs_lag02",
    "Qobs_lag03", "dQobs_lag1", "Qobs_lag_mean3"
  ))
  expect_equal(as.numeric(unlist(x[9, 4:7])), c(105, 104, 103, 102))
  expect_equal(x$dQobs_lag1[9], 1)
  expect_equal(x$Qobs_lag_mean3[9], 104)
})

test_that("forecast input uses four observations before t0", {
  d <- data.table(
    site = "A",
    time = as.POSIXct("2024-01-01", tz = "UTC") + 0:5 * 3600,
    period = c(rep("analysis", 4), rep("forecast", 2)),
    P = 0, PET = 1, Q_obs = c(10:13, NA, NA), Q_sim = 20:25
  )

  x <- build_xgb_Xt0(d, nlead = 2)
  expect_equal(x$Qlag, c(13, 13))
  expect_equal(x$Qobs_lag00, c(13, 13))
  expect_equal(x$Qobs_lag03, c(10, 10))
  expect_equal(x$Qobs_lag_mean3, c(12, 12))
})

test_that("holdout uses the last 30 percent for validation", {
  set.seed(1)
  X <- matrix(rnorm(80), 40, 2)
  Y <- matrix(rnorm(40), 40, 1)
  fit <- HydroFloods:::xgb_holdout(
    X, Y, train_ratio = 0.7,
    nrounds = 5, early_stopping_rounds = 2,
    learning_rate = 0.1, max_depth = 2, verbosity = 0
  )

  expect_s3_class(fit, "kfold")
  expect_equal(fit$index$holdout, 29:40)
  expect_equal(sum(is.finite(predict(fit, mode = "train")$ensemble)), 28)
  expect_equal(sum(is.finite(predict(fit, mode = "valid")$ensemble)), 12)
})
