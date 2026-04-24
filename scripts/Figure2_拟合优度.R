source("scripts/main_vis.R")

Figure2 <- function(model, overwrite = FALSE) {
  fout <- glue("Figures/Figure2_NSE_{model}.svg")
  (isfile(fout) && !overwrite) && return()

  load(glue("./OUTPUT/res_{model}.rda"))
  res <- map(res, "info") %>% set_names(sites)

  gof_HydroMetQlagXGB <- map(res, \(x) x$gof$HydroMetQlagXGB) %>%
    melt_list("site") %>%
    mutate(
      label = sprintf("%.2f", NSE),
      type = factor(type, levels = c("test", "train"), labels = c("Validation", "Calibration"))
    )
  gof_HydroMetXGB <- map(res, \(x) x$gof$HydroMetXGB) %>% melt_list("site")

  gof_Hydro <- map(res, \(x) x$gof$Hydro) %>%
    melt_list("site") %>%
    mutate(label = sprintf("Hydro = %.2f", NSE))

  d_lab <- build_lab(res)
  labels <- d_lab[, setNames(label_mk, site)]
  # gof_HydroMetQlagXGB$site %>% levels

  p <- ggplot(gof_HydroMetQlagXGB, aes(lead, NSE, color = type)) +
    geom_line() +
    geom_point(aes(shape = type)) +
    geom_hline(
      data = gof_Hydro, aes(yintercept = NSE),
      linetype = 1, color = "blue", linewidth = 0.4,
    ) +
    geom_hline(yintercept = 0.9, linetype = 2, color = "red", linewidth = 0.2) +
    geom_text(
      data = gof_Hydro, aes(x = 1, label = label, color = NULL),
      vjust = -0.8, hjust = 0.2, size = 2.5, color = "blue", show.legend = FALSE
    ) +
    geom_text(
      data = gof_HydroMetQlagXGB[type == "Validation"],
      aes(label = label), vjust = -0.8, hjust = 0.2, size = 2.5, show.legend = FALSE
    ) +
    facet_wrap(~site, labeller = labeller(site = labels)) +
    my_theme +
    theme(
      legend.position = "top",
      legend.margin = margin(t = -2, b = -6, 0, 0),
    ) +
    scale_x_continuous(
      breaks = seq(0, 12, 2), minor_breaks = seq(0, 12, 1),
      guide = guide_axis(minor.ticks = TRUE),
      limits = c(1, 12),
      expand = expansion(mult = c(0.05, 0.05))
    ) +
    scale_y_continuous(
      # label = scales::label_percent(),
      guide = guide_axis(minor.ticks = TRUE)
      # expand = expansion(mult = c(0.04, 0.1))
    ) +
    labs(x = "Leading time (hours)", color = NULL, shape = NULL)

  print(fout)
  write_fig(p, fout, 10, 5, show = FALSE)
}

# Figure2(models[1], overwrite = TRUE)
