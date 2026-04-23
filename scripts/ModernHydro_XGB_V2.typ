#import "@preview/modern-cug-report:0.1.3": *
#show: doc => template(doc, footer: "2024", header: "version3 洪水摘录表")


#let Figure2(model) = {
  let file = "../Figures/Figure2_NSE_" + model + ".svg"
  figure(
    image(file, width: 110%),
    caption: [
      #model
    ],
  )
}

#let Figure3(model) = {
  let file = "../Figures/Figure3_洪水合格率_" + model + ".svg"
  figure(
    image(file, width: 110%),
    caption: [
      #model
    ],
  )
}

= 1 拟合优度

#Figure2("m05_ihacres_7p_1s")
#Figure2("m07_gr4j_4p_2s")
#Figure2("m09_susannah1_6p_2s")
#Figure2("m28_xinanjiang_12p_4s")
#Figure2("XAJ")

#pagebreak()


= 2 洪峰合格率

#Figure3("m05_ihacres_7p_1s")
#Figure3("m07_gr4j_4p_2s")
#Figure3("m09_susannah1_6p_2s")
#Figure3("m28_xinanjiang_12p_4s")
#Figure3("XAJ")
