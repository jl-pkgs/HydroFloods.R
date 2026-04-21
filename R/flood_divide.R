# pacman::p_load(data.table, dplyr, lubridate)
#' @importFrom lubridate ddays
get_event_info <- function(date, Q, extend = ddays(5)) {
  if (length(extend) == 1) extend <- rep(extend, 2)

  date_beg <- min(date) - extend[1]
  date_end <- max(date) + extend[2]
  days <- difftime(date_end, date_beg, units = "days")

  data.table(date_beg, date_end, days,
    Q_min = min(Q, na.rm = TRUE),
    Q_max = max(Q, na.rm = TRUE),
    Q_mean = mean(Q, na.rm = TRUE)
  )
}

#' @param gap_max Default `5` days.
#' - `gaps` (in days) <= `gap_max` is regarded as the same event.
#' - `gaps > gap_max`, it will be regarded as two events.
#' @param extend Default `ddays(5)`. Extend `nday` in the left and right of a event
#'
#' @rdname flood_divide
#' @export
detect_groups <- function(df, inds, gap_max = 5, extend = ddays(5)) {
  gaps <- as.numeric(diff(df$date[inds]), units = "days")
  grps <- cumsum(c(0, gaps > gap_max)) # 分组
  info <- cbind(group = grps, df[inds, ]) # 分组
  info[, get_event_info(date, Q, extend), group]
}

#' detect_flood_events
#'
#' @param Q_min minimum discharge to detect flood events
#' @param Q_peak peak discharge to detect flood events
#'
#' @rdname flood_divide
#' @export
detect_flood_events <- function(
  date, Q, Q_min = 2, Q_peak = 10,
  gap_max = 5, extend = ddays(5), format = "%Y.%m"
) {
  df <- data.table(date, Q)
  inds <- df[, which(Q > Q_min)] #

  info_group <- detect_groups(df, inds, gap_max, extend) %>%
    .[Q_max > Q_peak, ]

  ## 数据压缩
  lgl <- rep(FALSE, nrow(df))
  for (i in 1:nrow(info_group)) {
    info <- info_group[i, ]
    lgl[date >= info$date_beg & date <= info$date_end] <- TRUE
  }

  # 由于已经扩展了5天，这里对洪水事件重新进行编号，不需要二次扩展
  inds <- which(lgl)
  info_group <- detect_groups(df, inds, gap_max, extend = 0)
  info_group %>%
    mutate(group = group + 1, group_name = format(date_beg, format), .after = "group") %>%
    mutate(days = as.numeric(days), label_days = sprintf("%.1f days", days), .after = "days")
  # listk(group = info_group, index = inds) #
}


#' @rdname flood_divide
#' @export
merge_flood2 <- function(df, info_flood) {
  if ("time" %in% names(df)) time <- df$time
  dat <- map(1:nrow(info_flood), function(i) {
    info <- info_flood[i, ]
    date_beg <- info$date_beg
    date_end <- info$date_end
    d <- df[time >= date_beg & time <= date_end]
    mutate(d, group_name = info$group_name, .before = 1)
  }) %>% Ipaper::melt_list("group")

  groups_bad <- dat[, .(P = sum(P, na.rm = TRUE)), .(group, group_name)][P <= 1, group_name]
  if (length(groups_bad) > 0) {
    SITE = df$site[1]
    message(glue("Removing {length(groups_bad)} bad flood events for site {SITE}:"))
    print(groups_bad)
    dat %<>% rm_bad_groups(groups_bad)
    info_flood %<>% rm_bad_groups(groups_bad)
  }
  list(data = dat, info_flood = info_flood)
}

#' @export
#' @rdname flood_divide
merge_flood <- function(df, info_flood) {
  merge_flood2(df, info_flood)$data
}

rm_bad_groups <- \(d, groups_bad) d[group_name %!in% groups_bad, ]


#' flood_divide
#' @param d A data.table with the variables of `time`, `Q_obs`
#' @export
flood_divide <- function(d, SITE, extend = 3, fout = NULL, show = FALSE) {
  f_config = path.mnt("/mnt/z/GitHub/jl-pkgs/ModernHydroModels.jl/Project_Shiyan2025/config_flood_events_十堰.yaml")
  config_all <- yaml::read_yaml(f_config)
  config <- if (is.null(config_all[[SITE]])) config_all$default else config_all[[SITE]]
  if (is.null(config)) {
    config <- list(Q_min = 15, Q_peak = 100, q.max = 250, prcp.max = 50)
  }
  c(Q_min, Q_peak, q.max, prcp.max) %<-% config

  ## 划分洪水场次
  extend <- c(1, 1) * dhours(extend) # `extend`定义洪水前后延时
  info_flood <- detect_flood_events(d$time, d$Q_obs,
    Q_min = Q_min, Q_peak = Q_peak,
    gap_max = 2, extend = extend, format = "%Y.%m.%d"
  )
  r <- merge_flood2(d, info_flood) # c(data, info_flood) %<-%

  ## 绘图
  nrow <- ceiling(nrow(r$info_flood) / 4)
  if (!is.null(fout)) {
    p <- plot_FloodEvents_Qobs(data, info_flood, prcp.max, q.max) # 观测洪水过程  可共用
    write_fig(p, fout, 12, 2.5 * nrow, show = show)
  }
  return(r)
}
