# julia -t12 --project
# include("apps/ex-Lumped_RunALL.jl")
using Revise
using ModelParams: GOF, of_KGE
using ModernHydroModels
using JLD2, UnPack, Ipaper, RTableTools, Dates
using RCall

function GOF2(d_sim::DataFrame, inds_calib, inds_valid; site="")
  (; Q_obs, Q_sim) = d_sim
  gof_calib = GOF(Q_obs[inds_calib], Q_sim[inds_calib]) # 检查模拟结果
  gof_valid = GOF(Q_obs[inds_valid], Q_sim[inds_valid]) # 检查模拟结果
  DataFrame([
    (; site, type="calib", gof_calib..., inds=inds_calib),
    (; site, type="valid", gof_valid..., inds=inds_valid)
  ])
end

dir_proj = "/mnt/z/GitHub/jl-pkgs/ModernHydroModels.jl"
st = fread("$dir_proj/apps/data/十堰_st_basins24.csv")
sites = st.site

f = "$dir_proj/apps/data/十堰_Forcing_hourly_ALL_v20260417_basins24.csv"
dir_root = "$dir_proj/Project_Shiyan2025/OUTPUT/version1_千里眼/"

f = "$dir_proj/apps/data/十堰_Forcing_hourly_ALL_v20260418_basins24_patch5sp.csv"
dir_root = "$dir_proj/Project_Shiyan2025/OUTPUT/version2_洪水摘录表/"

f = "$dir_proj/apps/data/十堰_Forcing_hourly_ALL_v20260418_basins5_OnlyEvents.csv"
dir_root = "$dir_proj/Project_Shiyan2025/OUTPUT/version3_洪水摘录表_OnlyEvents"

## load data
Forcing = fread(f)
Forcing.time = DateTime.(Forcing.time, dateformat"yyyy-mm-ddTHH:MM:SSZ")
replace_missing!(Forcing)

## Action
function RunHydro(; SITE="孤山", outdir="apps/OUTPUT", overwrite=false,
  model=XAJ{FT}(;))
  model = deepcopy(model) # 避免模型参数被其他SITE污染

  f_jld = "$outdir/Output_$(SITE)_v20260417.jld2"
  f_csv = "$outdir/Output_$(SITE).csv"
  f_gof = "$outdir/GOF_$(SITE).csv"
  isfile(f_jld) && !overwrite && return println("File exists: $f_jld")

  area = st[st.site.==SITE, :area_km2][1]
  d = Forcing[Forcing.site.==SITE, 2:end]
  d = d[year.(d.time).>=2015, :] # 太老的数据，观测精度不佳

  ## 率定参数
  ntime = nrow(d)
  n_calib = round(Int, ntime * 0.7)
  inds_calib = 1:n_calib
  inds_valid = (n_calib+1):ntime

  dates = d.time
  R_obs = d.R
  X = d[:, [:P, :PET_Romanenko]] |> Matrix

  FT = Float64
  hydro = LumpedModel{Float64}(; X, R_obs, inds_calib, inds_valid, ntime=length(R_obs), model)
  @time theta, gof = optim(hydro; maxn=3000, fun_gof=of_KGE)

  ## 评估精度
  theta_prev = update_params!(hydro, theta)
  fluxes = predict(hydro; save_states=true)

  d_sim = DataFrame(; site=SITE, time=d.time, P=hydro.X[:, 1],
    Q_obs=R2Q.(hydro.R_obs, area),
    Q_sim=R2Q.(fluxes.R_sim, area)
  )
  gof = GOF2(d_sim, inds_calib, inds_valid; site=SITE) # 检查模拟结果

  jldsave(f_jld; hydro, d_sim, gof, theta, fluxes, dates, inds_calib, inds_valid, area)
  fwrite(d_sim, f_csv)
  fwrite(gof, f_gof)
  ## 出图
  # Floods_Visualization(; fout=f_csv, area, show_floods=false, show=false,
  #   outdir, prefix="Figure1_$SITE", subfix="")
end

##
R"""
pacman::p_load(
  Ipaper, data.table, dplyr, lubridate,
  ggplot2, gg.layers, HydroFloods
)
devtools::load_all(".")
"""

function RunPlot(; SITE, outdir="apps/OUTPUT")
  f_csv = "$outdir/Output_$(SITE).csv"
  prefix = "Figure1_$SITE"
  # area = st[st.site.==SITE, :area_km2][1]

  R"""
  Floods_Visualization($f_csv, SITE=$SITE, show_floods=TRUE, show=FALSE,
    outdir=$outdir, prefix=$prefix, subfix="")
  """
  nothing
end

R"devtools::load_all('.')"

FT = Float64
models = (
  "XAJ" => XAJ{FT}(),
  "m05_ihacres_7p_1s" => m05_ihacres_7p_1s{FT}(),
  "m07_gr4j_4p_2s" => m07_gr4j_4p_2s{FT}(),
  "m09_susannah1_6p_2s" => m09_susannah1_6p_2s{FT}(),
  "m28_xinanjiang_12p_4s" => m28_xinanjiang_12p_4s{FT}()
)

for i in eachindex(models)
  model = models[i].second |> deepcopy
  modelName = models[i].first
  printstyled("Running model: $modelName \n", color=:blue, bold=true)

  outdir = "$dir_root/$(modelName)"
  mkpath(outdir)

  # @time RunHydro(; SITE="孤山")
  sites_good = ["松柏（二）", "县河", "房县", "延坝", "孤山"] # "贾家坊"
  @par for SITE in sites_good[1:end]
    @time RunHydro(; SITE, outdir, overwrite=true, model)
  end

  for SITE in sites_good#[5:5] # 绘图，不能采用并行
    @time RunPlot(; SITE, outdir)
  end
end
