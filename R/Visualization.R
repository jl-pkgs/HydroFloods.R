Floods_Visualization <- function(
  fout,
  outdir = "Project_Shiyan2025/OUTPUT/version2_洪水摘录表",
  prefix = "Figure", subfix = "",
  SITE = "", config_all = NULL,
  show_floods = TRUE, show = TRUE, extend = 3
)
{
  f_flood_obs <- ifelse(show_floods, glue("{outdir}/{prefix}_FloodEvents_Qobs{subfix}.svg"), NULL)
  f_flood_sim <- glue("{outdir}/{prefix}_FloodEvents_Qsim{subfix}.svg")
  f_ts_all <- glue("{outdir}/{prefix}_ALL_TimeSeries{subfix}.svg")

  d <- fread(fout)
  d %<>% .[year(time) >= 2015, .(time, P, Q_obs, Q_sim)] %>%
    mutate(year = year(time))

  ## 加载设置
  c(data, info_flood) %<-% flood_divide(d, config_all, SITE, extend = extend, 
    fout = f_flood_obs, show = show)
  print(info_flood)
  nrow <- ceiling(nrow(info_flood) / 4)

  p <- plot_FloodEvents_Qsim(data, prcp.max, q.max)
  write_fig(p, f_flood_sim, 12, 2.5 * nrow, show = show)

  ## 全部时间序列
  p <- plot_TimeSeries_Qsim(d, prcp.max, q.max)
  write_fig(p, f_ts_all, 10, 10, show = show)
  data
}
