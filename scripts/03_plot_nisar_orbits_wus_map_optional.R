#!/usr/bin/env Rscript

# Optional Figure 8 / NISAR Western U.S. orbit map for the InSAR seasonal snow review.
#
# This script is included for transparency, but it is not part of scripts/run_all.R
# because it depends on an external raster that is intentionally omitted from this
# reproducibility archive:
#
#   data/rasters/MODIS_mtnsnow_classes.tif
#
# Source for omitted raster:
#   Wrzesien, M. L., Pavelsky, T. M., Durand, M. T., Lundquist, J. D., & Dozier, J.
#   Global Seasonal Mountain Snow Mask from MODIS MOD10A2. Zenodo.
#   DOI: 10.5281/zenodo.2626737
#   Download file: MODIS_mtnsnow_classes.zip
#
# Archive use after adding the external raster:
#   Rscript scripts/03_plot_nisar_orbits_wus_map_optional.R
#
# Optional root override:
#   INSAR_SWE_REVIEW_DIR=/path/to/repository Rscript scripts/03_plot_nisar_orbits_wus_map_optional.R
#
# Included inputs:
#   data/vectors/cb_2018_us_state_20m/cb_2018_us_state_20m.shp
#   data/vectors/nisar/nisar_ascending_trackframes.gpkg
#   data/vectors/nisar/nisar_descending_trackframes.gpkg
#
# External omitted input:
#   data/rasters/MODIS_mtnsnow_classes.tif
#
# Outputs, if the external raster is supplied:
#   outputs/figures/fig08_nisar_orbit_wus_wrr.png
#   outputs/figures/fig08_nisar_orbit_wus_wrr.pdf
#   outputs/figures/fig08.png
#   outputs/figures/fig08.pdf

required_packages <- c("dplyr", "ggplot2", "sf", "terra", "cowplot", "grid")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    "Missing required R packages: ", paste(missing_packages, collapse = ", "),
    "\nInstall them with: install.packages(c(",
    paste(sprintf('"%s"', missing_packages), collapse = ", "), "))",
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(sf)
  library(terra)
  library(cowplot)
  library(grid)
})

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

first_existing <- function(paths) {
  paths <- path.expand(paths)
  hits <- paths[file.exists(paths)]
  if (length(hits) == 0) return(NA_character_)
  normalizePath(hits[[1]], mustWork = TRUE)
}

repo_root <- get_repo_root()
fig_dir <- file.path(repo_root, "outputs", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

states_shp <- first_existing(c(
  file.path(repo_root, "data", "vectors", "cb_2018_us_state_20m", "cb_2018_us_state_20m.shp")
))
nisar_ascending_gpkg <- first_existing(c(
  file.path(repo_root, "data", "vectors", "nisar", "nisar_ascending_trackframes.gpkg")
))
nisar_descending_gpkg <- first_existing(c(
  file.path(repo_root, "data", "vectors", "nisar", "nisar_descending_trackframes.gpkg")
))
modis_mtnsnow_raster <- first_existing(c(
  file.path(repo_root, "data", "rasters", "MODIS_mtnsnow_classes.tif"),
  file.path(repo_root, "data", "rasters", "wrzesien_modis_mountain_snow_mask", "MODIS_mtnsnow_classes.tif")
))

included_needed <- c(states_shp, nisar_ascending_gpkg, nisar_descending_gpkg)
if (any(is.na(included_needed) | !file.exists(included_needed))) {
  stop(
    "Missing one or more included Figure 8 vector inputs. Expected:\n",
    "  data/vectors/cb_2018_us_state_20m/cb_2018_us_state_20m.shp\n",
    "  data/vectors/nisar/nisar_ascending_trackframes.gpkg\n",
    "  data/vectors/nisar/nisar_descending_trackframes.gpkg",
    call. = FALSE
  )
}

if (is.na(modis_mtnsnow_raster) || !file.exists(modis_mtnsnow_raster)) {
  stop(
    "Optional Figure 8 cannot run because the external MODIS mountain snow-class raster is not included.\n\n",
    "Download the dataset 'Global Seasonal Mountain Snow Mask from MODIS MOD10A2' from Zenodo, ",
    "DOI 10.5281/zenodo.2626737. Download and unzip MODIS_mtnsnow_classes.zip, then place:\n\n",
    "  MODIS_mtnsnow_classes.tif\n\n",
    "at either of these paths relative to this archive root:\n\n",
    "  data/rasters/MODIS_mtnsnow_classes.tif\n",
    "  data/rasters/wrzesien_modis_mountain_snow_mask/MODIS_mtnsnow_classes.tif\n\n",
    "The NISAR orbit GPKGs and state-boundary input are included; only this external raster is omitted.",
    call. = FALSE
  )
}

pick_font_family <- function(preferred = c("Arial", "Helvetica")) {
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    available <- unique(systemfonts::system_fonts()$family)
    for (ff in preferred) if (ff %in% available) return(ff)
  }
  "sans"
}
font_family <- pick_font_family()

theme_classic2 <- function(base_size = 8, base_family = "",
                           base_line_size = base_size / 22,
                           base_rect_size = base_size / 22) {
  theme_bw(
    base_size = base_size,
    base_family = base_family,
    base_line_size = base_line_size,
    base_rect_size = base_rect_size
  ) %+replace%
    theme(
      text = element_text(family = base_family, color = "black"),
      panel.border = element_blank(),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      legend.key = element_blank(),
      complete = TRUE
    )
}

theme_set(theme_classic2(8, base_family = font_family))

col_ephemeral <- "#E69F00"
col_seasonal  <- "#0072B2"
col_track     <- "grey20"
col_state     <- "grey70"

# WUS Albers equal-area projection used for the manuscript map.
map_crs <- "+proj=aea +lat_0=23 +lon_0=-96 +lat_1=29.5 +lat_2=45.5 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

message("Reading NISAR ascending track frames: ", nisar_ascending_gpkg)
ascend_v1 <- st_read(nisar_ascending_gpkg, quiet = TRUE)
ascend_sf <- st_geometry(st_transform(ascend_v1, crs = map_crs))

message("Reading NISAR descending track frames: ", nisar_descending_gpkg)
descend_v1 <- st_read(nisar_descending_gpkg, quiet = TRUE)
descend_sf <- st_geometry(st_transform(descend_v1, crs = map_crs))

message("Reading external MODIS mountain snow-class raster: ", modis_mtnsnow_raster)
mtns_rast_v1 <- rast(modis_mtnsnow_raster)
mtns_rast_v2 <- crop(mtns_rast_v1, ext(-125, -102, 33, 50))
mtns_rast_v3 <- ifel(mtns_rast_v2 == 0, NA, mtns_rast_v2)
mtns_rast_v4 <- ifel(mtns_rast_v3 == 1, NA, mtns_rast_v3)
mtns_rast_v5 <- project(mtns_rast_v4, map_crs, method = "near")

mtns_rast_df <- as.data.frame(mtns_rast_v5, xy = TRUE)
colnames(mtns_rast_df)[3] <- "snow_class"
mtns_rast_df <- mtns_rast_df |>
  filter(!is.na(snow_class)) |>
  mutate(snow_class = as.character(snow_class))

message("Reading state boundaries: ", states_shp)
states_v1 <- st_read(states_shp, quiet = TRUE)
states_sf <- states_v1 |>
  st_transform(crs = map_crs) |>
  st_geometry()

snow_fill_scale <- scale_fill_manual(
  name = "Snow class",
  breaks = c("2", "3"),
  labels = c("2" = "Ephemeral", "3" = "Seasonal"),
  values = c("2" = col_ephemeral, "3" = col_seasonal),
  drop = FALSE
)

map_coord <- coord_sf(
  xlim = c(-2305585, -740000),
  ylim = c(1214805, 3114805),
  expand = FALSE
)

map_theme <- theme(
  text = element_text(family = font_family, color = "black"),
  panel.background = element_rect(fill = "white", color = NA),
  panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.45),
  panel.grid.major = element_blank(),
  panel.grid.minor = element_blank(),
  axis.title.x = element_blank(),
  axis.title.y = element_blank(),
  axis.text.x = element_text(family = font_family, color = "black", size = 7.5),
  axis.text.y = element_text(family = font_family, color = "black", size = 7.5),
  axis.ticks = element_line(color = "black", linewidth = 0.2),
  plot.title = element_blank(),
  plot.margin = unit(c(0.02, 0.06, 0.02, 0.06), "cm"),
  legend.position = "bottom",
  legend.direction = "horizontal",
  legend.title = element_text(family = font_family, size = 8.0, color = "black"),
  legend.text = element_text(family = font_family, size = 7.8, color = "black"),
  legend.key = element_blank(),
  legend.key.width = unit(0.34, "cm"),
  legend.key.height = unit(0.28, "cm"),
  legend.spacing.x = unit(0.12, "cm"),
  legend.margin = margin(t = 0, r = 0, b = 0, l = 0),
  legend.box.margin = margin(t = -3, r = 0, b = 0, l = 0)
)

label_x <- -2275000
label_y <- 3065000

make_nisar_panel <- function(track_sf, panel_label) {
  ggplot() +
    geom_tile(
      data = mtns_rast_df,
      mapping = aes(x = x, y = y, fill = snow_class),
      alpha = 0.95
    ) +
    geom_sf(
      data = states_sf,
      fill = NA,
      color = col_state,
      linewidth = 0.12,
      inherit.aes = FALSE,
      alpha = 0.85
    ) +
    geom_sf(
      data = track_sf,
      fill = NA,
      color = col_track,
      linewidth = 0.15,
      inherit.aes = FALSE,
      alpha = 0.38
    ) +
    annotate(
      "label",
      x = label_x,
      y = label_y,
      label = panel_label,
      family = font_family,
      fontface = "bold",
      size = 3.1,
      hjust = 0,
      vjust = 1,
      label.size = 0,
      label.padding = unit(0.33, "lines"),
      fill = "white",
      color = "black"
    ) +
    snow_fill_scale +
    map_coord +
    guides(
      fill = guide_legend(
        nrow = 1,
        byrow = TRUE,
        override.aes = list(alpha = 1)
      )
    ) +
    map_theme
}

map_ascending <- make_nisar_panel(ascend_sf, "(a) Ascending")
map_descending <- make_nisar_panel(descend_sf, "(b) Descending")

shared_legend <- cowplot::get_legend(
  map_ascending +
    theme(
      legend.position = "bottom",
      legend.box.margin = margin(0, 0, 0, 0)
    )
)

panel_row <- plot_grid(
  map_ascending + theme(legend.position = "none"),
  map_descending + theme(legend.position = "none"),
  ncol = 2,
  nrow = 1,
  align = "hv",
  axis = "tb",
  rel_widths = c(1, 1)
)

fig8 <- plot_grid(
  panel_row,
  shared_legend,
  ncol = 1,
  rel_heights = c(1, 0.065)
)

png_device <- if (requireNamespace("ragg", quietly = TRUE)) ragg::agg_png else "png"

for (fname in c("fig08_nisar_orbit_wus_wrr.png", "fig08.png")) {
  ggsave(
    plot = fig8,
    filename = file.path(fig_dir, fname),
    width = 7.2,
    height = 4.15,
    dpi = 600,
    device = png_device
  )
}

for (fname in c("fig08_nisar_orbit_wus_wrr.pdf", "fig08.pdf")) {
  ggsave(
    plot = fig8,
    filename = file.path(fig_dir, fname),
    width = 7.2,
    height = 4.15,
    device = cairo_pdf
  )
}

message("Done. Wrote Figure 8 outputs to ", fig_dir)
