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

#let model = "m05_ihacres_7p_1s"

= 1 #model
#Figure3("县河", model)
#Figure3("孤山", model)
#Figure3("延坝", model)
#Figure3("房县", model)
#Figure3("松柏（二）", model)

#pagebreak()

#let model = "m07_gr4j_4p_2s"
= 2 #model
#Figure3("县河", model)
#Figure3("孤山", model)
#Figure3("延坝", model)
#Figure3("房县", model)
#Figure3("松柏（二）", model)

#pagebreak()

#let model = "m09_susannah1_6p_2s"
= 3 #model
#Figure3("县河", model)
#Figure3("孤山", model)
#Figure3("延坝", model)
#Figure3("房县", model)
#Figure3("松柏（二）", model)

#pagebreak()

#let model = "m28_xinanjiang_12p_4s"
= 4 #model
#Figure3("县河", model)
#Figure3("孤山", model)
#Figure3("延坝", model)
#Figure3("房县", model)
#Figure3("松柏（二）", model)

#pagebreak()

#let model = "XAJ"
= 5 #model
#Figure3("县河", model)
#Figure3("孤山", model)
#Figure3("延坝", model)
#Figure3("房县", model)
#Figure3("松柏（二）", model)
