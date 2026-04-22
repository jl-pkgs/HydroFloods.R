pacman::p_load(
  Ipaper, data.table, dplyr, lubridate, stringr,
  kfold, zeallot,
  ggplot2, gg.layers, ggrepel, ggh4x
)
# InitCluster(6)

devtools::load_all(".")
# devtools::load_all(path.mnt("/mnt/z/GitHub/cug-hydro/kfold.R"))
options(datatable.print.nrow = 20)
