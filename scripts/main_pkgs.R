pacman::p_load(
  Ipaper, data.table, dplyr, lubridate, stringr,
  kfold, zeallot,
  ggplot2, gg.layers, ggrepel, ggh4x
)
# InitCluster(6)

devtools::load_all(".")
# devtools::load_all(path.mnt("/mnt/z/GitHub/cug-hydro/kfold.R"))
options(datatable.print.nrow = 20)

dir_root <- "/mnt/z/GitHub/jl-pkgs/ModernHydroModels.jl" %>% path.mnt()
