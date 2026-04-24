pacman::p_load(
  Ipaper, data.table, dplyr, lubridate, stringr,
  kfold, zeallot,
  ggplot2, gg.layers, ggrepel, ggh4x
)
# InitCluster(6)

devtools::load_all(".")
# devtools::load_all(path.mnt("/mnt/z/GitHub/cug-hydro/kfold.R"))
options(datatable.print.nrow = 20)

models <- c("m05_ihacres_7p_1s", "m07_gr4j_4p_2s", "m09_susannah1_6p_2s", "m28_xinanjiang_12p_4s", "XAJ")
