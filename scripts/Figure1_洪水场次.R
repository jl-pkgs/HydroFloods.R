source("scripts/main_pkgs.R")

models <- c("m05_ihacres_7p_1s", "m07_gr4j_4p_2s", "m09_susannah1_6p_2s", "m28_xinanjiang_12p_4s", "XAJ")
model <- models[1]

load(glue("./OUTPUT/res_{model}.rda"))