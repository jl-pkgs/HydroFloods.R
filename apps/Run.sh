# !/bin/bash
# Copyright (c) 2026 Dongdong Kong & JiaQi Shi

# julia -t8 --project apps/RunHydro.jl apps/config_GuShan.toml 

export PATH="/opt/miniforge3/envs/r4.5/bin:$PATH" # R语言路径添加到环境变量
Rscript apps/ModernHydroAPP.R apps/config_GuShan.toml 
