#!/usr/bin/env Rscript

# Lightweight input check for the InSAR seasonal snow review reproducibility archive.
# Usage:
#   Rscript scripts/check_inputs.R

required_packages <- c("readr", "dplyr")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required R packages for this check: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

suppressPackageStartupMessages({library(readr); library(dplyr)})

get_repo_root <- function() {
  for (env_name in c("INSAR_SWE_REVIEW_DIR", "INSAR_SWE_REPO_DIR", "INSAR_SWE_REPRO_DIR")) {
    env_root <- Sys.getenv(env_name, unset = NA_character_)
    if (!is.na(env_root) && nzchar(env_root)) return(normalizePath(path.expand(env_root), mustWork = TRUE))
  }

  cmd <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE)
    return(normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE))
  }

  normalizePath(getwd(), mustWork = TRUE)
}

repo_root <- get_repo_root()
graph_path <- file.path(repo_root, "data", "csv", "figure1_publication_counts.csv")
map_path <- file.path(repo_root, "data", "csv", "figure3_study_locations.csv")
required_files <- c(
  graph_path,
  map_path,
  file.path(repo_root, "data", "rasters", "sturm", "SnowClass_EA_05km_2.50arcmin_2021_v01.0.tif"),
  file.path(repo_root, "data", "rasters", "sturm", "SnowClass_GL_05km_2.50arcmin_2021_v01.0.tif"),
  file.path(repo_root, "data", "vectors", "world-administrative-boundaries", "world-administrative-boundaries.shp"),
  file.path(repo_root, "data", "vectors", "cb_2018_us_state_20m", "cb_2018_us_state_20m.shp")
)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files) > 0) {
  stop("Missing required input files:\n", paste(missing_files, collapse = "\n"), call. = FALSE)
}

graph <- read_csv(graph_path, show_col_types = FALSE)
map <- read_csv(map_path, show_col_types = FALSE)

stopifnot(nrow(graph) == 95)
stopifnot(nrow(map) == 97)
stopifnot(!any(c("key", "atm_cor", "atm_correction", "optical_data") %in% names(graph)))
stopifnot(!any(c("key", "atm_cor", "atm_correction", "optical_data") %in% names(map)))
stopifnot(all(!is.na(graph$year)))
stopifnot(all(is.finite(map$plot_lat), is.finite(map$plot_lon)))

message("Input checks passed for the fully reproducible archive components.")
message("Figure 1 CSV rows: ", nrow(graph))
message("Figure 3 CSV rows: ", nrow(map))
message("Figure 1 item types: ", paste(names(table(graph$item_type)), as.integer(table(graph$item_type)), sep = "=", collapse = "; "))
message("Figure 3 item types: ", paste(names(table(map$item_type)), as.integer(table(map$item_type)), sep = "=", collapse = "; "))

optional_fig8_files <- c(
  file.path(repo_root, "scripts", "03_plot_nisar_orbits_wus_map_optional.R"),
  file.path(repo_root, "data", "vectors", "nisar", "nisar_ascending_trackframes.gpkg"),
  file.path(repo_root, "data", "vectors", "nisar", "nisar_descending_trackframes.gpkg")
)
optional_fig8_missing <- optional_fig8_files[!file.exists(optional_fig8_files)]
if (length(optional_fig8_missing) == 0) {
  message("Optional Figure 8 vector/script inputs are present.")
} else {
  message("Optional Figure 8 vector/script inputs missing: ", paste(optional_fig8_missing, collapse = "; "))
}

modis_paths <- c(
  file.path(repo_root, "data", "rasters", "MODIS_mtnsnow_classes.tif"),
  file.path(repo_root, "data", "rasters", "wrzesien_modis_mountain_snow_mask", "MODIS_mtnsnow_classes.tif")
)
if (!any(file.exists(modis_paths))) {
  message("Optional Figure 8 external raster is absent. Download it from the cited Zenodo record before running Figure 8.")
  message("To run Figure 8, download MODIS_mtnsnow_classes.zip from Zenodo DOI 10.5281/zenodo.2626737 and place MODIS_mtnsnow_classes.tif under data/rasters/.")
}
