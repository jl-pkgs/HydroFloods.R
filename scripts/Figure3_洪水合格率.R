source("scripts/main_vis.R")


Figure3 <- function(model, overwrite = FALSE) {
  fout = glue("Figures/Figure3_洪水合格率_{model}.svg")
  (isfile(fout) && !overwrite) && return()

  load(glue("./OUTPUT/res_{model}.rda"))
  res <- map(res, "info") %>% set_names(sites)

  d_lab <- build_lab(res)
  dat_pass <- map(res, "info_pass") %>% melt_list("site")

  pdat <- dat_pass[lead != "-"] %>% mutate(
    x = as.integer(str_extract(as.character(lead), "\\d{2}")),
    label = sprintf("%.0f%%", perc_pass * 100)
  )
  labels <- d_lab[, setNames(label_mk, site)]

  d_hydro <- dat_pass[model == "Hydro"] %>%
    arrange(site) %>%
    mutate(
      label = sprintf("Hydro = %.0f%%", perc_pass * 100), vjust = c(c(1, 1) * 2.0, c(1, 1, 1) * -0.8)
    )

  lwd <- 0.5
  p <- ggplot(pdat, aes(x, perc_pass)) +
    geom_point() +
    geom_line() +
    geom_hline(
      data = d_hydro, aes(yintercept = perc_pass),
      linetype = 1, color = "blue", linewidth = 0.4,
    ) +
    geom_hline(yintercept = 0.6, linetype = 2, color = "red", linewidth = 0.2) +
    facet_wrap(~site, scales = "free", labeller = labeller(site = labels)) +
    geom_text(aes(label = label), vjust = -0.8, hjust = 0.2, size = 2.5) +
    geom_text(
      data = d_hydro, aes(x = 1, label = label, vjust = vjust),
      hjust = 0.15, size = 2.5, color = "blue", show.legend = FALSE
    ) +
    # geom_richtext_npc(
    #   data = d_lab, aes(label = label),
    #   npcx = 1, npcy = 1, hjust = 1, vjust = 1
    # ) +
    # geom_hline(data = dat[model == "HydroMetXGB"], aes(yintercept = perc_pass),
    #   linetype = 2, color = "blue") +
    my_theme +
    scale_x_continuous(
      breaks = seq(0, 12, 2), minor_breaks = seq(0, 12, 1),
      guide = guide_axis(minor.ticks = TRUE),
      limits = c(1, 12),
      expand = expansion(mult = c(0.05, 0.05))
    ) +
    scale_y_continuous(
      label = scales::label_percent(),
      guide = guide_axis(minor.ticks = TRUE),
      expand = expansion(mult = c(0.04, 0.1))
    ) +
    labs(x = "Leading time (hours)", y = "Percentage of Qualified (%)")

  write_fig(p, fout, 10, 5, show = FALSE)
}
