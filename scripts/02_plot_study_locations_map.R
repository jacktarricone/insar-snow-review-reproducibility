#!/usr/bin/env Rscript

# Study-location map for the InSAR seasonal snow review.
#
# Archive use:
#   Rscript scripts/02_plot_study_locations_map.R
#
# Optional root override:
#   INSAR_SWE_REVIEW_DIR=/path/to/repository Rscript scripts/02_plot_study_locations_map.R
#
# Inputs:
#   data/csv/figure3_study_locations.csv
#   data/rasters/sturm/SnowClass_EA_05km_2.50arcmin_2021_v01.0.tif
#   data/rasters/sturm/SnowClass_GL_05km_2.50arcmin_2021_v01.0.tif
#
# Vector inputs:
#   Preferred: local shapefiles in data/vectors/
#   Fallback: rnaturalearth/rnaturalearthdata if local shapefiles are absent.
#
# Outputs:
#   outputs/figures/figure3_study_locations_map.pdf
#   outputs/figures/figure3_study_locations_map.png
#   outputs/figures/fig03.pdf
#   outputs/figures/fig03.png
#   outputs/tables/figure3_plot_clusters.csv

required_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "sf", "terra", "patchwork", "grid", "units")
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
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(sf)
  library(terra)
  library(patchwork)
  library(grid)
})

get_repo_root <- function() {
  # Priority:
  #   1. Explicit environment variable for local manuscript repo.
  #   2. Alternate repository-root environment variable, if used.
  #   3. Parent directory of this script when run with Rscript.
  #   4. Default local manuscript repo path.
  #   5. Current working directory.
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
input_csv <- file.path(repo_root, "data", "csv", "figure3_study_locations.csv")
fig_dir <- file.path(repo_root, "outputs", "figures")
plot_dir <- fig_dir
table_dir <- file.path(repo_root, "outputs", "tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

snow_raster_ea <- first_existing(c(
  file.path(repo_root, "data", "rasters", "sturm", "SnowClass_EA_05km_2.50arcmin_2021_v01.0.tif"),
  file.path(repo_root, "data", "rasters", "SnowClass_EA_05km_2.50arcmin_2021_v01.0.tif")
))
snow_raster_gl <- first_existing(c(
  file.path(repo_root, "data", "rasters", "sturm", "SnowClass_GL_05km_2.50arcmin_2021_v01.0.tif"),
  file.path(repo_root, "data", "rasters", "SnowClass_GL_05km_2.50arcmin_2021_v01.0.tif")
))
world_shp <- first_existing(c(
  file.path(repo_root, "data", "vectors", "world-administrative-boundaries", "world-administrative-boundaries.shp")
))
states_shp <- first_existing(c(
  file.path(repo_root, "data", "vectors", "cb_2018_us_state_20m", "cb_2018_us_state_20m.shp")
))

needed <- c(input_csv, snow_raster_ea, snow_raster_gl)
missing_files <- needed[is.na(needed) | !file.exists(needed)]
if (length(missing_files) > 0) {
  stop(
    "Missing required Figure 3 input files. Expected this exact map CSV: data/csv/figure3_study_locations.csv, ",
    "and Sturm/Liston snow-class rasters in data/rasters/sturm/.",
    call. = FALSE
  )
}
message("Reading mapped-location data: ", input_csv)
message("Using snow rasters: ", snow_raster_ea, " and ", snow_raster_gl)

pick_font_family <- function(preferred = c("Arial", "Helvetica")) {
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    available <- unique(systemfonts::system_fonts()$family)
    for (ff in preferred) if (ff %in% available) return(ff)
  }
  "sans"
}
fig_font <- pick_font_family()

sf::sf_use_s2(TRUE)
map_crs <- "EPSG:4326"
cluster_threshold_m <- 200000
cluster_threshold_km <- cluster_threshold_m / 1000

# Reader-facing map extents. The map uses EPSG:4326/lon-lat coordinates.
bbox_na <- c(xmin = -172, xmax = -37, ymin = 24, ymax = 82)
bbox_eurasia <- c(xmin = -5, xmax = 130, ymin = 24, ymax = 82)

# Paul Tol-inspired qualitative colors. Snow class codes follow Sturm and Liston (2021).
snow_fill_values <- c(
  "1" = "#4477AA",  # Tundra
  "2" = "#EE6677",  # Boreal Forest
  "3" = "#228833",  # Maritime
  "5" = "#F0E442",  # Prairie
  "6" = "#AA3377",  # Montane Forest
  "7" = "#66CCEE",  # Ice
  "4" = "#C7B9A5"   # Ephemeral
)
snow_labels <- c(
  "1" = "Tundra",
  "2" = "Boreal Forest",
  "3" = "Maritime",
  "5" = "Prairie",
  "6" = "Montane Forest",
  "7" = "Ice",
  "4" = "Ephemeral"
)
snow_breaks <- c("2", "1", "3", "5", "6", "7", "4")
cluster_fill <- grDevices::adjustcolor("#F7F7F2", alpha.f = 0.85)

review_theme <- function(base_size = 11, base_family = "sans") {
  theme_bw(base_size = base_size, base_family = base_family) %+replace%
    theme(
      panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.9),
      panel.background = element_rect(fill = "white", colour = NA),
      panel.grid = element_blank(),
      axis.ticks = element_line(color = "black"),
      axis.text = element_text(color = "black"),
      legend.position = "none",
      complete = TRUE
    )
}

theme_set(review_theme(11, fig_font))

format_lon_label <- function(x) {
  x <- round(x)
  ifelse(x < 0, paste0(abs(x), "\u00B0W"), ifelse(x > 0, paste0(x, "\u00B0E"), "0\u00B0"))
}
format_lat_label <- function(y) {
  y <- round(y)
  ifelse(y < 0, paste0(abs(y), "\u00B0S"), ifelse(y > 0, paste0(y, "\u00B0N"), "0\u00B0"))
}
pad_bbox <- function(bbox, pad_deg = 1.0) {
  c(
    xmin = max(-180, bbox[["xmin"]] - pad_deg),
    xmax = min(180, bbox[["xmax"]] + pad_deg),
    ymin = max(-90, bbox[["ymin"]] - pad_deg),
    ymax = min(90, bbox[["ymax"]] + pad_deg)
  )
}

filter_bbox <- function(df, bbox) {
  df %>% filter(lon >= bbox[["xmin"]], lon <= bbox[["xmax"]], lat >= bbox[["ymin"]], lat <= bbox[["ymax"]])
}

make_reference_id <- function(doi, title, year) {
  doi_clean <- ifelse(!is.na(doi) & nzchar(doi), tolower(trimws(doi)), NA_character_)
  title_clean <- tolower(gsub("[^a-z0-9]+", "_", trimws(title)))
  ifelse(!is.na(doi_clean), doi_clean, paste(year, title_clean, sep = "_"))
}

cluster_locations <- function(raw_locs, threshold_m = 200000) {
  raw_locs <- raw_locs %>% distinct(raw_lon, raw_lat)
  if (nrow(raw_locs) == 0) return(raw_locs %>% mutate(plot_cluster_id = integer(0)))

  locs_sf <- st_as_sf(raw_locs, coords = c("raw_lon", "raw_lat"), crs = 4326, remove = FALSE)
  dist_m <- units::drop_units(st_distance(locs_sf))
  adjacency <- dist_m <= threshold_m

  cluster_id <- rep(NA_integer_, nrow(raw_locs))
  current_id <- 0L
  for (i in seq_len(nrow(raw_locs))) {
    if (is.na(cluster_id[i])) {
      current_id <- current_id + 1L
      cluster_id[i] <- current_id
      stack <- i
      while (length(stack) > 0) {
        current <- stack[1]
        stack <- stack[-1]
        neighbors <- which(adjacency[current, ] & is.na(cluster_id))
        if (length(neighbors) > 0) {
          cluster_id[neighbors] <- current_id
          stack <- c(stack, neighbors)
        }
      }
    }
  }
  raw_locs$plot_cluster_id <- cluster_id
  raw_locs
}

make_size_lookup <- function(max_count) {
  data.frame(count = c(1, 2, 7, 10, max_count), size = c(1.5, 2.6, 5.4, 7.8, 10.2)) %>%
    filter(count <= max_count) %>%
    group_by(count) %>%
    summarise(size = max(size), .groups = "drop") %>%
    arrange(count)
}
point_size_from_count <- function(count, lookup) {
  approx(x = lookup$count, y = lookup$size, xout = count, rule = 2, ties = "ordered")$y
}

snow_to_df <- function(raster_obj, bbox, panel_name) {
  bbox_pad <- pad_bbox(bbox, pad_deg = 1.0)
  r_crop <- crop(raster_obj, ext(bbox_pad[["xmin"]], bbox_pad[["xmax"]], bbox_pad[["ymin"]], bbox_pad[["ymax"]]))
  out <- as.data.frame(r_crop, xy = TRUE, na.rm = FALSE)
  names(out)[3] <- "class"
  out <- out %>% filter(!is.na(class), class != 8) %>% mutate(class = factor(as.integer(class)))
  message(panel_name, ": ", nrow(out), " raster cells")
  out
}

sf_to_path_df <- function(x) {
  x <- x %>% st_make_valid() %>% st_transform(4326)
  pieces <- vector("list", nrow(x))
  for (i in seq_len(nrow(x))) {
    xi <- x[i, ]
    if (any(st_is_empty(xi))) next
    boundary <- suppressWarnings(st_boundary(xi))
    if (any(st_is_empty(boundary))) next
    coords <- as.data.frame(st_coordinates(boundary))
    if (nrow(coords) == 0) next
    level_cols <- grep("^L", names(coords), value = TRUE)
    local_group <- if (length(level_cols) == 0) rep("1", nrow(coords)) else as.character(do.call(interaction, c(coords[level_cols], drop = TRUE, lex.order = TRUE)))
    pieces[[i]] <- data.frame(x = coords$X, y = coords$Y, group = paste(i, local_group, sep = "_"), vertex_id = seq_len(nrow(coords)))
  }
  bind_rows(pieces)
}

split_large_path_jumps <- function(path_df, max_jump_deg = 6) {
  path_df %>%
    arrange(group, vertex_id) %>%
    group_by(group) %>%
    mutate(
      jump = ifelse(row_number() == 1, FALSE, abs(x - lag(x)) > max_jump_deg | abs(y - lag(y)) > max_jump_deg),
      segment_id = cumsum(jump),
      group2 = paste(group, segment_id, sep = "_")
    ) %>%
    ungroup()
}

filter_path_bbox <- function(path_df, bbox, pad_deg = 1.0) {
  bbox_pad <- pad_bbox(bbox, pad_deg = pad_deg)
  out <- path_df %>% filter(x >= bbox_pad[["xmin"]], x <= bbox_pad[["xmax"]], y >= bbox_pad[["ymin"]], y <= bbox_pad[["ymax"]])
  if (nrow(out) == 0) return(out)
  split_large_path_jumps(out, max_jump_deg = 6)
}

# Read and cluster mapped study locations.
locations <- read_csv(input_csv, show_col_types = FALSE) %>%
  mutate(
    plot_lat = suppressWarnings(as.numeric(plot_lat)),
    plot_lon = suppressWarnings(as.numeric(plot_lon)),
    reference_id = make_reference_id(doi, title, year),
    plot_area = ifelse(is.na(plot_area) | plot_area == "", area, plot_area)
  ) %>%
  filter(is.finite(plot_lat), is.finite(plot_lon)) %>%
  mutate(raw_lat = round(plot_lat, 4), raw_lon = round(plot_lon, 4))

message("Mapped rows used for Figure 3: ", nrow(locations))

raw_locs <- locations %>% distinct(raw_lon, raw_lat) %>% cluster_locations(threshold_m = cluster_threshold_m)
clustered <- locations %>% left_join(raw_locs, by = c("raw_lon", "raw_lat"))

cluster_counts <- clustered %>%
  group_by(plot_cluster_id) %>%
  summarise(
    count = n_distinct(reference_id),
    area = paste(sort(unique(plot_area)), collapse = "; "),
    lat = mean(plot_lat, na.rm = TRUE),
    lon = mean(plot_lon, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(count))

max_count <- max(cluster_counts$count, na.rm = TRUE)
size_lookup <- make_size_lookup(max_count)
size_breaks <- sort(unique(c(1, 2, 7, 10, max_count)))
size_breaks <- size_breaks[size_breaks >= 1 & size_breaks <= max_count]
legend_size_values <- point_size_from_count(size_breaks, size_lookup)
cluster_counts <- cluster_counts %>% mutate(plot_size = point_size_from_count(count, size_lookup))

write_csv(cluster_counts, file.path(table_dir, "figure3_plot_clusters.csv"))

message("Mapped rows: ", nrow(locations))
message("Plot clusters: ", nrow(cluster_counts))
message("Maximum studies in one cluster: ", max_count)

# Read base-map data.
snow_class <- merge(rast(snow_raster_ea), rast(snow_raster_gl))
if (!grepl("4326|WGS 84|longlat", as.character(crs(snow_class)), ignore.case = TRUE)) {
  snow_class <- project(snow_class, map_crs, method = "near")
}
snow_na <- snow_to_df(snow_class, bbox_na, "North America")
snow_eurasia <- snow_to_df(snow_class, bbox_eurasia, "Eurasia")

if (!is.na(world_shp) && !is.na(states_shp)) {
  message("Using local vector shapefiles.")
  world_sf <- st_read(world_shp, quiet = TRUE)
  states_sf <- st_read(states_shp, quiet = TRUE)
} else {
  message("Local vector shapefiles not found; falling back to rnaturalearth.")
  if (!requireNamespace("rnaturalearth", quietly = TRUE) || !requireNamespace("rnaturalearthdata", quietly = TRUE)) {
    stop(
      "Install rnaturalearth and rnaturalearthdata, or place vector shapefiles in data/vectors/.",
      call. = FALSE
    )
  }
  world_sf <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf")
  states_sf <- rnaturalearth::ne_states(country = "United States of America", returnclass = "sf")
}

world_lines <- world_sf %>% sf_to_path_df() %>% split_large_path_jumps()
states_lines <- states_sf %>% sf_to_path_df() %>% split_large_path_jumps()

make_panel <- function(snow_df, clusters, bbox, panel_label = "(a)", include_states = FALSE) {
  points <- filter_bbox(clusters, bbox)
  world_panel <- filter_path_bbox(world_lines, bbox, pad_deg = 1.0)
  states_panel <- filter_path_bbox(states_lines, bbox, pad_deg = 1.0)

  ggplot() +
    geom_raster(data = snow_df, aes(x = x, y = y, fill = class), interpolate = FALSE, alpha = 0.99, show.legend = FALSE) +
    geom_path(data = world_panel, aes(x = x, y = y, group = group2), linewidth = 0.28, color = "grey35", alpha = 0.25) +
    {if (include_states) geom_path(data = states_panel, aes(x = x, y = y, group = group2), linewidth = 0.18, color = "grey45", alpha = 0.25)} +
    geom_point(data = points, aes(x = lon, y = lat, size = plot_size), shape = 21, color = "black", fill = cluster_fill, stroke = 0.65, show.legend = FALSE) +
    annotate("text", x = bbox[["xmin"]] + 2.0, y = bbox[["ymax"]] - 1.5, label = panel_label, hjust = 0, vjust = 1, size = 6.0, fontface = "bold", family = fig_font) +
    coord_fixed(ratio = 1, xlim = c(bbox[["xmin"]], bbox[["xmax"]]), ylim = c(bbox[["ymin"]], bbox[["ymax"]]), expand = FALSE) +
    scale_x_continuous(breaks = pretty(c(bbox[["xmin"]], bbox[["xmax"]]), n = 6), labels = format_lon_label) +
    scale_y_continuous(breaks = pretty(c(bbox[["ymin"]], bbox[["ymax"]]), n = 5), labels = format_lat_label) +
    scale_fill_manual(values = snow_fill_values, drop = FALSE) +
    scale_size_identity() +
    review_theme(base_size = 11, base_family = fig_font) +
    theme(
      axis.title = element_blank(),
      axis.text = element_text(size = 8.5, family = fig_font),
      plot.margin = margin(t = 4, r = 6, b = 4, l = 6, unit = "pt"),
      plot.background = element_rect(fill = "white", colour = NA),
      text = element_text(family = fig_font)
    )
}

make_custom_legend <- function() {
  cluster_legend <- data.frame(count = size_breaks, size = legend_size_values * 0.95) %>%
    mutate(label = as.character(count), radius_x = 0.0027 * size, label_width = nchar(label) * 0.013)

  circle_left <- numeric(nrow(cluster_legend))
  circle_x <- numeric(nrow(cluster_legend))
  label_x <- numeric(nrow(cluster_legend))
  current_left <- 0.030
  for (i in seq_len(nrow(cluster_legend))) {
    circle_left[i] <- current_left
    circle_x[i] <- circle_left[i] + cluster_legend$radius_x[i]
    label_x[i] <- circle_x[i] + cluster_legend$radius_x[i] + 0.010
    current_left <- label_x[i] + cluster_legend$label_width[i] + 0.010
  }
  cluster_legend <- cluster_legend %>% mutate(x = circle_x, label_x = label_x, y = 0.585)

  snow_label_x <- c(0.43, 0.65, 0.78, 0.96)
  snow_legend <- bind_rows(
    data.frame(class = factor(snow_breaks[1:4], levels = names(snow_fill_values)), label = unname(snow_labels[snow_breaks[1:4]]), label_x = snow_label_x, y = 0.705),
    data.frame(class = factor(snow_breaks[5:7], levels = names(snow_fill_values)), label = unname(snow_labels[snow_breaks[5:7]]), label_x = snow_label_x[1:3], y = 0.455)
  ) %>% mutate(swatch_x = label_x - 0.030)

  ggplot() +
    geom_point(data = cluster_legend, aes(x = x, y = y, size = size), shape = 21, color = "black", fill = cluster_fill, stroke = 1.0) +
    geom_text(data = cluster_legend, aes(x = label_x, y = y, label = label), hjust = 0, vjust = 0.5, size = 3.5, family = fig_font) +
    geom_tile(data = snow_legend, aes(x = swatch_x, y = y, fill = class), width = 0.025, height = 0.17, alpha = 0.99) +
    geom_text(data = snow_legend, aes(x = label_x, y = y, label = label), hjust = 0, vjust = 0.5, size = 3.5, family = fig_font) +
    scale_size_identity() +
    scale_fill_manual(values = snow_fill_values, guide = "none") +
    coord_cartesian(xlim = c(0, 1.14), ylim = c(0.30, 0.84), expand = FALSE, clip = "off") +
    theme_void(base_family = fig_font) +
    theme(plot.margin = margin(t = 0, r = 10, b = 0, l = 8, unit = "pt"), plot.background = element_rect(fill = "white", colour = NA))
}

map_na <- make_panel(snow_na, cluster_counts, bbox_na, panel_label = "(a)", include_states = TRUE)
map_eurasia <- make_panel(snow_eurasia, cluster_counts, bbox_eurasia, panel_label = "(b)", include_states = FALSE)
legend_panel <- make_custom_legend()

map_figure <- (map_na / map_eurasia / legend_panel) +
  plot_layout(heights = c(1, 1, 0.22)) +
  plot_annotation(theme = theme(plot.margin = margin(t = 5, r = 5, b = 5, l = 5, unit = "pt"), text = element_text(family = fig_font)))

pdf_device <- if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf

ggsave(file.path(fig_dir, "figure3_study_locations_map.pdf"), map_figure, width = 7.9, height = 7.45, device = pdf_device)
ggsave(file.path(fig_dir, "figure3_study_locations_map.png"), map_figure, width = 7.9, height = 7.45, dpi = 500)
ggsave(file.path(fig_dir, "fig03.pdf"), map_figure, width = 7.9, height = 7.45, device = pdf_device)
ggsave(file.path(fig_dir, "fig03.png"), map_figure, width = 7.9, height = 7.45, dpi = 500)

message("Wrote: ", file.path(fig_dir, "figure3_study_locations_map.pdf"))
message("Wrote: ", file.path(fig_dir, "fig03.pdf"))

