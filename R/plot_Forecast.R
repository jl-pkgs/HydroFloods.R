#' 预报窗口图：过去一周 + 未来n小时，凸显t0位置与预报时段
#'
#' @param d         data.table，含 time, P, Q_obs, Q_sim
#' @param t0        预报起点，POSIXct 或可被 as.POSIXct 解析的字符串
#' @param window_past 回溯时长（默认7天）
#' @param window_fc   预报时长（默认1天）
#' @export
plot_Forecast_Window <- function(
  d, t0,
  prcp.max = NULL, q.max = NULL, # NULL = 窗口内自动缩放
  window_past = days(7),
  window_fc = days(1)
) {
  t0 <- as.POSIXct(t0, tz = "UTC")
  d <- d[time >= t0 - window_past & time <= t0 + window_fc]

  # 按窗口内实际数据自动定标（保留10%余量）
  if (is.null(q.max)) q.max <- max(d$Q_obs, d$Q_sim, na.rm = TRUE) * 1.2
  if (is.null(prcp.max)) prcp.max <- max(d$P, na.rm = TRUE) * 1.5
  # 防止全零导致除零
  if (q.max <= 0) q.max <- 1
  if (prcp.max <= 0) prcp.max <- 1
  print(tail(d))

  ggplot(d, aes(x = time, y = Q_obs)) +
    annotate("rect",
      xmin = t0, xmax = t0 + window_fc, ymin = -Inf, ymax = Inf,
      fill = "blue", alpha = 0.1
    ) + # 预报时段底色
    geom_vline(xintercept = t0, linetype = "dashed", color = "darkblue", linewidth = 0.8) + # t0 分割线
    geom_prcpRunoff(aes(prcp = P),
      params_prcp = list(color = col_prcp, fill = col_prcp),
      prcp.coef = q.max / prcp.max, qmax = q.max,
      color = col_runoff, linewidth = 0.1
    ) +
    geom_line(aes(y = Q_obs), color = "black") +
    geom_line(aes(y = Q_sim, color = "Qsim")) +
    # GOF 仅在 t0 前的观测段计算
    geom_gof2(
      data = d[time <= t0], aes(obs = Q_obs, sim = Q_sim, color = "Qsim"),
      y = 0.95, label.format = fmt_gof, size = 4.5,
      show.bias = FALSE, eval.flood = FALSE
    ) +
    scale_color_manual(values = c("Qsim" = "red")) +
    my_theme +
    theme(
      axis.title.y = element_text(face = "bold", size = 15),
      axis.text.x = element_text(angle = 25, vjust = 1, hjust = 1),
      legend.position = "bottom",
      legend.margin = margin(t = -15, b = -10, 0, 0),
      plot.title = element_markdown(),
    ) +
    scale_x_datetime(date_labels = "%m-%d %H") +
    labs(x = NULL, y = expression(bold("Streamflow (m"^"3" * "/s)")), colour = NULL)
}
