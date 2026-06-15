#import "@preview/modern-cug-report:0.1.3": *
#show: doc => template(doc, footer: "CUG水文气象学2025", header: "")


#let Figure3(site, model) = {
  let file = "Figure3_ensemble/Figure3_ensemble_" + site + "_" + model + "_lead_03.svg"
  figure(
    image(file, width: 110%),
    caption: [
      集合平均预报效果：#site --- #model
    ],
  )
}

= 1 县河
#Figure3("县河", "m05_ihacres_7p_1s")
#Figure3("县河", "m07_gr4j_4p_2s")
#Figure3("县河", "m09_susannah1_6p_2s")
#Figure3("县河", "m28_xinanjiang_12p_4s")
#Figure3("县河", "XAJ")

#pagebreak()

= 2 孤山
#Figure3("孤山", "m05_ihacres_7p_1s")
#Figure3("孤山", "m07_gr4j_4p_2s")
#Figure3("孤山", "m09_susannah1_6p_2s")
#Figure3("孤山", "m28_xinanjiang_12p_4s")
#Figure3("孤山", "XAJ")

#pagebreak()

= 3 延坝
#Figure3("延坝", "m05_ihacres_7p_1s")
#Figure3("延坝", "m07_gr4j_4p_2s")
#Figure3("延坝", "m09_susannah1_6p_2s")
#Figure3("延坝", "m28_xinanjiang_12p_4s")
#Figure3("延坝", "XAJ")

#pagebreak()

= 4 房县
#Figure3("房县", "m05_ihacres_7p_1s")
#Figure3("房县", "m07_gr4j_4p_2s")
#Figure3("房县", "m09_susannah1_6p_2s")
#Figure3("房县", "m28_xinanjiang_12p_4s")
#Figure3("房县", "XAJ")

#pagebreak()

= 5 松柏（二）
#Figure3("松柏（二）", "m05_ihacres_7p_1s")
#Figure3("松柏（二）", "m07_gr4j_4p_2s")
#Figure3("松柏（二）", "m09_susannah1_6p_2s")
#Figure3("松柏（二）", "m28_xinanjiang_12p_4s")
#Figure3("松柏（二）", "XAJ")

#pagebreak()
