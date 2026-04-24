# source("scripts/main_vis.R")
pacman::p_load(
  Ipaper, data.table, dplyr, lubridate, stringr,
  ggplot2, gg.layers
)

my_theme <- theme_bw(base_size = 13) +
  theme(
    axis.text = element_text(color = "black"),
    strip.background = element_blank(),
    strip.text = ggtext::element_markdown(
      face = "bold", hjust = 0, size = 12,
      margin = margin(b = 1, t = 1)
    ),
    # strip.text = element_text(),
    axis.minor.ticks.x.bottom = element_line(linewidth = 0.1),
    axis.minor.ticks.y.left = element_line(linewidth = 0.1),
    axis.minor.ticks.length = rel(0.7),
    # axis.minor.ticks.x.bottom = element_line()
    panel.grid.major = element_line(linewidth = 0.2),
    panel.grid.minor = element_line(linewidth = 0.1)
  )

build_lab <- function(res) {
  # sites <- c("松柏（二）", "县河", "房县", "延坝", "孤山")
  n_flood <- map(res, "info_flood") %>% map(\(x) dim(x)[1L])
  d_flood <- data.table(site = factor(names(res), sort(sites)), n_flood = unlist(n_flood))

  d_lab <- d_flood[, .N, .(site)] %>%
    arrange(site) %>%
    merge(d_flood) %>%
    mutate(
      label = sprintf("(%s) %s: n_flood = %s", letters[seq_along(site)], site, n_flood))
  d_lab$label_mk = label_mk(d_lab$label) %>% unlist()
  d_lab
}
