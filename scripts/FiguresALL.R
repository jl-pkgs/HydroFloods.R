source("scripts/Figure1_洪水场次效果.R", encoding = "UTF-8")
source("scripts/Figure2_拟合优度.R", encoding = "UTF-8")
source("scripts/Figure3_洪水合格率.R", encoding = "UTF-8")

models <- c("m05_ihacres_7p_1s", "m07_gr4j_4p_2s", "m09_susannah1_6p_2s", "m28_xinanjiang_12p_4s", "XAJ")
# Figure2(models[1], overwrite = TRUE)

map(models, \(model) Figure1_Qsim_1model(model))
map(models, \(model) Figure2(model, overwrite = TRUE))
map(models, \(model) Figure3(model, overwrite = TRUE))
