plot_FloodEvents_Qsim3 <- function(
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

  # info_eval <- dat[, eval_Qmax(Q_obs, Q_sim), by = .(group, group_name)] %>%
  #     arrange(passed, group_name)
  # n_passed <- sum(info_eval$passed)
  # n_total <- nrow(info_eval)
  # str_passed <- sprintf("%d/%d Passed", n_passed, n_total)
  # gof <- dat[, GOF(Q_obs, Q_sim)]
  # fmt_gof2 <- "*NSE* = {str_num(NSE,2)}, *KGE* = {str_num(KGE,2)}, *R^2* = {str_num(R2, 2)}"
  # if (show_passed) fmt_gof2 <- sprintf("%s, {str_passed}", fmt_gof2)
  # title <- with(gof, glue(fmt_gof2)) %>% str_mk()
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
      legend.margin = margin(t = -15, b = -10, 0, 0),
      axis.title.y = element_text(face = "bold", size = 15),
      axis.text.x = element_text(angle = 25, vjust = 1, hjust = 1),
      strip.text = element_text(margin = margin(t = 0, b = 2, 0, 0)),
      plot.title = element_markdown(),
    ) +
    scale_x_datetime(date_labels = "%m-%d %H") +
    labs(x = NULL, y = expression(bold("Streamflow (m"^"3" * "/s)")), colour = NULL)
}
