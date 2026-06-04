# %% 
source("scripts/main_pkgs.R")
library(patchwork)

# %%
I = 5
MODEL = models[I]
f = glue("OUTPUT/V20260603/res_{MODEL}.rda")
load(f)
# , labeller = labeller(site = labels)
methods <- c("Hydro", "MetXGB", "QlagXGB", "HydroMetXGB", "HydroMetQlagXGB")[-c(2, 3)]

gof <- map(res, \(l) l$summary$gof) %>% rbindlist(idcol = "site") %>%
  filter(model %in% methods) %>% 
  mutate(
    model = factor(model, levels = methods),
    lead = as.integer(str_extract(lead, "\\d+")),
    label = sprintf("%.2f", NSE),
  ) %>%
  arrange(site, model, lead, mode) %>% 
  select(-kfold)

# %% 
x_hydro = 0
dat_hydro = gof[model %in% c("Hydro") & mode %in% c("train", "test")]
Figure1 <- function(gof, title = NULL) {
  p <- ggplot(gof[model %!in% c("Hydro", "HydroMetXGB"), ], aes(lead, NSE, color = model, linetype = mode, shape = mode)) +
    geom_vline(xintercept = 1, linewidth = 0.15, color = "grey95", linetype = 1) + 
    geom_line() +
    geom_point() +
    geom_hline(data = dat_hydro, aes(yintercept = NSE, color = model, linetype = mode)) +
    geom_point(data = dat_hydro, aes(x = x_hydro, y = NSE, color = model)) +
    # scale_alpha_manual(values = c(0.5, 1)) +
    facet_wrap(~site) +
    my_theme +
    theme(
      legend.position = "top",
      legend.margin = margin(t = -2, b = -6, 0, 0),
    ) +
    scale_x_continuous(
      breaks = seq(0, 12, 2), minor_breaks = seq(0, 12, 1),
      guide = guide_axis(minor.ticks = TRUE),
      limits = c(0, 12),
      # expand = expansion(mult = c(0.05, 0.05))
    ) +
    scale_y_continuous(
      # label = scales::label_percent(),
      guide = guide_axis(minor.ticks = TRUE)
      # expand = expansion(mult = c(0.04, 0.1))
    ) +
    guides(
      linetype = guide_legend(keywidth = unit(1.0, "cm"), override.aes = list(size = 2)),
      color = guide_legend(override.aes = list(shape = NA))
    ) + 
    coord_cartesian(ylim = c(0.6, 1)) +
    labs(x = "Leading time (hours)", color = NULL, shape = NULL, title = title, linetype = NULL)
  p
}

p <- Figure1(gof)
write_fig(p, glue("FigureS1_{MODEL}_NSE_V2.pdf"), 10, 6, show = FALSE)
