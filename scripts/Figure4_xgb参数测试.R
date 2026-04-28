source("scripts/main_vis.R")
pacman::p_load(data.table, dplyr, ggplot2, glue, stringr, ggrepel)

parse_xgb_par_name <- function(d) {
  getv <- function(x, pat) str_match(x, pat)[, 2]
  eta_v <- getv(d$par_name, "eta(\\d+)")
  sub_v <- getv(d$par_name, "sub(\\d+)")
  lam_v <- getv(d$par_name, "lam(\\d+)")
  nr_v <- getv(d$par_name, "_n(\\d+)")

  d[, `:=`(
    max_depth = as.integer(getv(par_name, "md(\\d+)")),
    min_child_weight = as.integer(getv(par_name, "mcw(\\d+)")),
    eta = fifelse(is.na(eta_v), NA_real_, as.numeric(eta_v) / 100),
    subsample = fifelse(is.na(sub_v), NA_real_, fifelse(sub_v == "1", 1, as.numeric(sub_v) / 100)),
    lambda = fifelse(is.na(lam_v), NA_real_, fifelse(nchar(lam_v) > 1, as.numeric(lam_v) / 10, as.numeric(lam_v))),
    nrounds = fifelse(is.na(nr_v), NA_integer_, as.integer(nr_v))
  )]

  d[!is.na(subsample) & subsample < 0.2, subsample := subsample * 10]
  d
}

#' 绘制参数筛选散点图和前若干组评价矩阵
Figure4_xgb_par <- function(f_score, outdir = "Figures/test_xgboost", top_n = Inf,
  label_n = 10, matrix_n = 10, overwrite = FALSE) {
  fout_a <- glue("{outdir}/Figure4a_XGB参数筛选散点图.svg")
  fout_b <- glue("{outdir}/Figure4b_XGB前十方案评价矩阵.svg")
  ftab <- glue("{outdir}/Figure4_XGB参数方案编号表.csv")

  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  if (file.exists(fout_a) && file.exists(fout_b) && !overwrite) return(invisible(NULL))

  d <- fread(f_score)
  setorder(d, rank_score)
  d <- parse_xgb_par_name(copy(d))
  if (is.finite(top_n)) d <- d[1:min(top_n, .N)]
  d[, pid := sprintf("P%03d", seq_len(.N))]

  fwrite(d[, .(pid, par_name, max_depth, min_child_weight, eta, subsample, lambda, nrounds,
    valid_nse_mean, valid_nse_min, pass_mean, pass_min, gap_mean, gap_max,
    rough2_mean, rough2_p90, rank_score)], ftab)

  d[, grp := "Others"]
  d[1:min(label_n, .N), grp := "Top"]
  d_top <- d[grp == "Top"]

  p1 <- ggplot() +
    geom_point(data = d[grp == "Others"],
      aes(gap_mean, valid_nse_mean, size = pass_mean, shape = factor(max_depth)),
      colour = "grey70", fill = "grey85", stroke = 0.2, alpha = 0.85) +
    geom_point(data = d_top,
      aes(gap_mean, valid_nse_mean, size = pass_mean, shape = factor(max_depth)),
      colour = "#C00000", fill = "#F8766D", stroke = 0.25, alpha = 0.95) +
    geom_vline(xintercept = median(d$gap_mean, na.rm = TRUE), linetype = 2, linewidth = 0.25, color = "grey40") +
    geom_hline(yintercept = median(d$valid_nse_mean, na.rm = TRUE), linetype = 2, linewidth = 0.25, color = "grey40") +
    ggrepel::geom_text_repel(data = d_top, aes(gap_mean, valid_nse_mean, label = pid),
      size = 3, color = "black", box.padding = 0.2, point.padding = 0.15,
      min.segment.length = 0, max.overlaps = Inf, seed = 123, show.legend = FALSE) +
    my_theme +
    theme(legend.position = "right", legend.box = "vertical",
      legend.title = element_text(size = 10), legend.text = element_text(size = 9),
      axis.title = element_text(size = 12), axis.text = element_text(size = 10),
      plot.margin = margin(5.5, 8, 5.5, 5.5)) +
    scale_shape_manual(values = c("2" = 21, "3" = 24, "4" = 22)) +
    scale_size_continuous(range = c(1.8, 5.2), breaks = pretty(d$pass_mean, 4),
      labels = \(x) sprintf("%.0f%%", 100 * x)) +
    scale_x_continuous(expand = expansion(mult = c(0.05, 0.08))) +
    scale_y_continuous(expand = expansion(mult = c(0.05, 0.08))) +
    labs(x = "Gap mean: Calibration NSE - Validation NSE",
      y = "Validation NSE", shape = "Max depth", size = "Pass mean")

  print(fout_a)
  write_fig(p1, fout_a, 7.2, 4.6, show = FALSE)

  top <- d[1:min(matrix_n, .N)]
  mat <- top[, .(pid, `Valid NSE` = valid_nse_mean, `Valid min` = valid_nse_min,
    `Pass mean` = pass_mean, `Pass min` = pass_min,
    `Gap mean` = gap_mean, `Gap max` = gap_max,
    `Rough mean` = rough2_mean, `Rough p90` = rough2_p90, Score = rank_score)]

  dm <- melt(mat, id.vars = "pid", variable.name = "metric", value.name = "value")
  higher <- c("Valid NSE", "Valid min", "Pass mean", "Pass min")
  lower <- c("Gap mean", "Gap max", "Rough mean", "Rough p90", "Score")
  dm[, perf := NA_real_]
  dm[metric %in% higher, perf := value]
  dm[metric %in% lower, perf := -value]
  dm[, perf_std := (perf - min(perf, na.rm = TRUE)) /
    (max(perf, na.rm = TRUE) - min(perf, na.rm = TRUE) + 1e-9), by = metric]
  dm[, metric := factor(metric, levels = c(higher, lower))]
  dm[, pid := factor(pid, levels = rev(top$pid))]
  dm[, label := sprintf("%.3f", value)]
  dm[metric %in% c("Pass mean", "Pass min"), label := sprintf("%.1f%%", 100 * value)]
  dm[metric == "Score", label := sprintf("%.2f", value)]

  p2 <- ggplot(dm, aes(metric, pid, fill = perf_std)) +
    geom_tile(color = "white", linewidth = 0.35) +
    geom_text(aes(label = label), size = 2.4) +
    scale_fill_gradient(low = "#F2F2F2", high = "#4F81BD") +
    my_theme +
    theme(legend.position = "right", legend.title = element_text(size = 10),
      legend.text = element_text(size = 9), legend.key.height = unit(1.8, "cm"),
      legend.key.width = unit(0.35, "cm"), panel.grid = element_blank(),
      axis.title = element_blank(), axis.text.x = element_text(size = 8.5),
      axis.text.y = element_text(size = 9), plot.margin = margin(5.5, 8, 5.5, 5.5)) +
    scale_x_discrete(labels = c(`Valid NSE` = "Valid\nNSE", `Valid min` = "Valid\nmin",
      `Pass mean` = "Pass\nmean", `Pass min` = "Pass\nmin",
      `Gap mean` = "Gap\nmean", `Gap max` = "Gap\nmax",
      `Rough mean` = "Rough\nmean", `Rough p90` = "Rough\np90", Score = "Score")) +
    labs(fill = "Relative\nperformance")

  print(fout_b)
  write_fig(p2, fout_b, 8.0, 4.8, show = FALSE)
}