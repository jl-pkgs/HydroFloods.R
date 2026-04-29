#' @importFrom gg.layers geom_gof2
#' @export
plot_FloodEvents_Qsim <- function(dat, prcp.max = 50, q.max = 250, ..., ncol = 4, show_passed = TRUE) {
  # info_ratio <- dat[, lapply(.SD, mean, na.rm = TRUE),
  #   .(group, group_name), .SDcols = c("P", "R")] %>% mutate(ratio = R / P)
  info_eval <- dat[, eval_Qmax(Q_obs, Q_sim), by = .(group, group_name)] %>%
    # merge(info_ratio, by = c("group", "group_name")) %>%
    arrange(passed, group_name)
  n_passed <- sum(info_eval$passed)
  n_total <- nrow(info_eval)
  str_passed <- sprintf("%d/%d Passed", n_passed, n_total)

  gof <- dat[, GOF(Q_obs, Q_sim)]
  fmt_gof2 <- "*NSE* = {str_num(NSE,2)}, *KGE* = {str_num(KGE,2)}, *R^2* = {str_num(R2, 2)}"
  if (show_passed) fmt_gof2 <- sprintf("%s, {str_passed}", fmt_gof2)
  title <- with(gof, glue(fmt_gof2)) %>% str_mk()

  groups <- "Qsim"
  ggplot(dat, aes(x = time, y = Q_obs)) +
    geom_line(aes(color = "Qobs")) +
    geom_line(aes(y = Q_sim, color = groups[1])) +
    geom_prcpRunoff(
      aes(prcp = P),
      params_prcp = list(color = col_prcp, fill = col_prcp),
      prcp.coef = q.max / prcp.max,
      qmax = q.max,
      color = col_runoff, linewidth = 0.1
    ) +
    geom_gof2(aes(obs = Q_obs, sim = Q_sim, color = groups[1]),
      y = 0.95,
      label.format = fmt_gof, size = 4.5, show.bias = FALSE, eval.flood = TRUE
    ) +
    # scale_color_manual(values = c("darkgreen", "purple", "red")[3]) +
    scale_color_manual(values = c("black", "red")) +
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
    labs(
      x = NULL, y = expression(bold("Streamflow (m"^"3" * "/s)")), colour = NULL,
      title = title
    )
}
