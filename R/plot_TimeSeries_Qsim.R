#' @export
plot_TimeSeries_Qsim <- function(d, prcp.max = 50, q.max = 250) {
  ggplot(d, aes(time, Q_obs)) +
    geom_prcpRunoff(
      aes(prcp = P),
      params_prcp = list(color = col_prcp, fill = col_prcp),
      prcp.coef = q.max / prcp.max,
      qmax = q.max,
      color = col_runoff, linewidth = 0.1
    ) +
    geom_line(aes(y = Q_obs), color = "black") +
    geom_line(aes(y = Q_sim), color = "red") +
    geom_gof2(aes(obs = Q_obs, sim = Q_sim),
      y = 0.76, vjust = 0,
      label.format = fmt_gof, size = 5, show.bias = FALSE, eval.flood = FALSE
    ) +
    facet_wrap(~year, scales = "free_x", ncol = 2) +
    my_theme +
    theme(
      axis.title.y = element_text(face = "bold", size = 15),
      plot.margin = margin(t = 0, r = 0, b = 0, l = 0),
      panel.spacing.y = unit(-0.1, "cm"),
      strip.text = element_text(face = "bold", hjust = 0, vjust = -0.2),
      # axis.text.x = element_text(angle = 25, vjust = 1, hjust = 1)
    ) +
    scale_x_datetime(date_labels = "%b") +
    labs(x = NULL, y = expression(bold("Streamflow (m"^"3" * "/s)")))
}
