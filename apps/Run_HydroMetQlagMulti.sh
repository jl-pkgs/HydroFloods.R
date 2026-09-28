#!/bin/bash
# Copyright (c) 2026 Dongdong Kong & JiaQi Shi

export PATH="/opt/miniforge3/envs/r4.5/bin:$PATH"
export OMP_NUM_THREADS=4
module load julia/1.12
Rscript apps/ModernHydroAPP_HydroMetQlagMulti.R \
  apps/config_GuShan_HydroMetQlagMulti.yaml
