#' @import ggplot2 ggtext
#' @importFrom scales alpha
#' @importFrom gg.layers theme_dual_axis
NULL

symbol_right <- gg.layers:::symbol_right
symbol_wrong <- gg.layers:::symbol_wrong

col_prcp <- "blue" # "#3e89be"
# col_runoff <- "black" # "darkorange"
# col_prcp <- alpha("blue", 0.55) # "#3e89be"
col_runoff <- "black" # "darkorange"

my_theme <-
  theme_bw(base_size = 14) +
  theme_dual_axis(col_runoff, col_prcp) +
  theme(
    # legend.position.inside = c(0, 1),
    # legend.justification = c(0, 1),
    legend.background = element_blank(),
    legend.key = element_blank(),
    panel.grid.major = element_line(linewidth = 0.4),
    panel.grid.minor = element_blank(),
    # axis.ticks = element_blank(),
    axis.text = element_text(color = "black"),
    # axis.text.x = element_text(angle = 60, hjust = 1),
    strip.background = element_blank(),
    strip.text = element_text(face = "bold", hjust = 0)
  )

fmt_gof <- "*NSE* = {str_num(NSE,2)}, *R^2* = {str_num(R2, 2)}"

plot_FloodEvents_Qobs <- function(dat, info_flood, prcp.max = 50, q.max = 250, ..., ncol = 4) {
  info_flood %<>% mutate(
    label_max = sprintf("Qmax = %.0f", Q_max),
    label_day = sprintf("Days = %.1f", days)
  )
  ncpx <- 0.52
  ggplot(dat, aes(x = time, y = Q_obs)) +
    geom_line() +
    geom_prcpRunoff(
      aes(prcp = P),
      params_prcp = list(color = col_prcp, fill = col_prcp),
      prcp.coef = q.max / prcp.max,
      qmax = q.max,
      color = col_runoff, linewidth = 0.1
    ) +
    geom_richtext_npc(
      data = info_flood, aes(label = label_day),
      npcx = ncpx, npcy = 1.0, hjust = 0, vjust = 1, size = 4, color = "black", fontface = "bold"
    ) +
    geom_richtext_npc(
      data = info_flood, aes(label = label_max),
      npcx = ncpx, npcy = 0.85, hjust = 0, vjust = 1, size = 4, color = "black", fontface = "bold"
    ) +
    scale_color_manual(values = c("darkgreen", "purple", "red")) +
    facet_wrap(~group_name, scales = "free", ncol = ncol) + # group_name
    my_theme +
    theme(
      legend.position = "top",
      legend.margin = margin(t = -5, b = -10, 0, 0),
      axis.title.y = element_text(face = "bold", size = 15),
      axis.text.x = element_text(angle = 25, vjust = 1, hjust = 1),
      strip.text = element_text(margin = margin(t = 0, 0, 0, 0))
    ) +
    scale_x_datetime(date_labels = "%m-%d %H") +
    labs(x = NULL, y = expression(bold("Streamflow (m"^"3" * "/s)")), colour = NULL)
}
