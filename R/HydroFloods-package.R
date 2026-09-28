#' @keywords internal
#' @import glue
#' @importFrom dplyr mutate group_map group_by
#' @importFrom dplyr select starts_with rename_with all_of
#' @importFrom purrr map
#' @importFrom lubridate ymd_hms dhours
#' @importFrom Ipaper %!in% write_fig
#' @import data.table magrittr zeallot
#' @importFrom stringr str_extract
#' @import kfold
#' @import ggnewscale 
#' @importFrom dplyr arrange relocate mutate group_by group_map
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL


listk <- function(...) {
  cols <- as.list(substitute(list(...)))[-1]
  vars <- names(cols)
  Id_noname <- if (is.null(vars)) {
    seq_along(cols)
  } else {
    which(vars == "")
  }
  if (length(Id_noname) > 0) {
    vars[Id_noname] <- sapply(cols[Id_noname], deparse)
  }
  x <- setNames(list(...), vars)
  return(x)
}

#' @export
Q2R <- function(Q, area = dt * 3.6, dt = 1) {
  Q * dt * 3.6 / area
}

#' @export 
R2Q <- function(R, area = dt * 3.6, dt = 1) {
  (R * area) / (dt * 3.6)
}

movsum <- function(x, win_p = 24) {
  rollapply(x,
    width = win_p, FUN = \(x) sum(x, na.rm = TRUE),
    fill = NA, align = "right", partial = TRUE
  )
}

#' add_previous
#' @param d with the variable of `Q_obs`
#' @param nlead the number of leads to add
#' @export
add_previous <- function(d, nlead = 12) {
  Qs <- previous_tn(d$Q_obs, nlead)[, -1] %>%
    as.data.table() %>%
    rename_with(\(x) paste0("Q_", x))
  cbind(d, Qs)
}
