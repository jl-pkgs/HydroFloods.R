devtools::build(".")

install.packages(c("pacman", "pak"))
pak::pkg_install(paste0("local::", "../HydroFloods_0.1.1.tar.gz"))
# pak::pkg_install("jl-pkgs/HydroFloods.R")
