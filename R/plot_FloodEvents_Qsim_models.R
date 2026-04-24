#' plot_FloodEvents_Qsim_models
#' @param dat_obs 观测的时间序列数据，必须包含 `time` 和 `Q_obs`, `group_name`
#' @param dat_sim 模拟的时间序列数据，必须包含 `time`、`Q_sim`, `Q_obs`和 `model` 三列
#' @export
plot_FloodEvents_Qsim_models <- function(
  dat_obs, dat_sim, prcp.max = 50, q.max = 250, ...,
  colors = NULL,
  ncol = 4, show_passed = TRUE
) {
  time_end <- max(dat_sim$time)
  dat_obs <- dat_obs[time <= time_end]

  models <- dat_sim$model %>% unique_sort()
  nmodel <- length(models)
  if (is.null(colors)) {
    colors <- RColorBrewer::brewer.pal(length(models), "Set1")
  }

  add_gof <- function(gap = 0.13) {
    lapply(1:nmodel, \(i){
      MODEL <- models[i]
      data <- dat_sim[model == MODEL]
      geom_gof2(
        data = data, aes(obs = Q_obs, sim = Q_sim, color = MODEL),
        y = 0.95 - (i - 1) * gap, vjust = 1,
        label.format = fmt_gof, size = 4.5, show.bias = FALSE, eval.flood = TRUE
      )
    })
  }

  add_lines <- function() {
    lapply(1:nmodel, \(i){
      geom_line(data = dat_sim[model == models[i]], aes(y = Q_sim, color = models[i]))
    })
  }

  ## 准备标题
  str_passed_all <- sapply(1:nmodel, \(i) {
    MODEL <- models[i]
    data <- dat_sim[model == MODEL]
    info_eval <- data[, eval_Qmax(Q_obs, Q_sim), by = .(group_name)]
    n_passed <- sum(info_eval$passed)
    n_total <- nrow(info_eval)
    sprintf("<span style='color:%s'>**%s**: %d/%d Passed</span>", colors[i], MODEL, n_passed, n_total)
  })
  title <- paste(str_passed_all, collapse = "   |   ") %>% str_mk()

  groups <- "Qsim"
  ggplot(dat_obs, aes(x = time, y = Q_obs)) +
    geom_line() +
    # geom_line(aes(y = Q_sim, color = groups[1])) +
    geom_prcpRunoff(
      aes(prcp = P),
      params_prcp = list(color = col_prcp, fill = col_prcp),
      prcp.coef = q.max / prcp.max,
      qmax = q.max,
      color = col_runoff, linewidth = 0.1
    ) +
    add_lines() +
    add_gof() +
    # scale_color_manual(values = c("darkgreen", "purple", "red")[3]) +
    scale_color_manual(values = colors) +
    facet_wrap(~group_name, scales = "free", ncol = ncol) + # group_name
    my_theme +
    theme(
      legend.position = "bottom",
      legend.margin = margin(t = -10, b = -2, 0, 0),
      legend.text = element_text(size = 13),
      axis.title.y = element_text(face = "bold", size = 15),
      axis.text.x = element_text(angle = 25, vjust = 1, hjust = 1),
      strip.text = element_text(margin = margin(t = 0, b = 2, 0, 0)),
      plot.title = element_markdown(),
    ) +
    scale_x_datetime(date_labels = "%m-%d %H") +
    labs(x = NULL, y = expression(bold("Streamflow (m"^"3" * "/s)")), colour = NULL, title = title)
}
