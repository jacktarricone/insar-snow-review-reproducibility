#!/usr/bin/env Rscript

# Publication-count plot for the InSAR seasonal snow review.
#
# Archive use:
#   Rscript scripts/01_plot_publication_counts.R
#
# Optional root override:
#   INSAR_SWE_REVIEW_DIR=/path/to/repository Rscript scripts/01_plot_publication_counts.R
#
# Input:
#   data/csv/figure1_publication_counts.csv
#
# Outputs:
#   outputs/figures/figure1_publication_counts.pdf
#   outputs/figures/figure1_publication_counts.png
#   outputs/figures/fig01.pdf
#   outputs/figures/fig01.png
#   outputs/tables/figure1_publication_counts_by_year.csv

required_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "scales")
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
  library(scales)
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
input_csv <- file.path(repo_root, "data", "csv", "figure1_publication_counts.csv")
fig_dir <- file.path(repo_root, "outputs", "figures")
plot_dir <- fig_dir
table_dir <- file.path(repo_root, "outputs", "tables")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(input_csv)) {
  stop(
    "Missing Figure 1 input CSV: ", input_csv,
    "\nExpected this exact file: data/csv/figure1_publication_counts.csv",
    call. = FALSE
  )
}
message("Reading publication-count data: ", input_csv)

pick_font_family <- function(preferred = c("Arial", "Helvetica")) {
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    available <- unique(systemfonts::system_fonts()$family)
    for (ff in preferred) if (ff %in% available) return(ff)
  }
  "sans"
}
fig_font <- pick_font_family()

review_theme <- function(base_size = 12, base_family = "sans") {
  theme_bw(base_size = base_size, base_family = base_family) %+replace%
    theme(
      panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.9),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.ticks = element_line(color = "black"),
      axis.text = element_text(color = "black"),
      legend.key = element_blank(),
      legend.background = element_blank(),
      legend.box.background = element_blank(),
      complete = TRUE
    )
}

type_levels <- c("conferencePaper", "journalArticle", "preprint")
type_labels <- c(
  conferencePaper = "Conference Paper",
  journalArticle  = "Journal Article",
  preprint        = "Public Preprint"
)

# Color-blind-safe, high-contrast colors.
fill_values <- c(
  conferencePaper = "#56B4E9",
  journalArticle  = "#D55E00",
  preprint        = "grey75"
)
line_values <- c(cumulative = "black")

publications <- read_csv(input_csv, show_col_types = FALSE) %>%
  mutate(
    year = as.integer(year),
    item_type = case_when(
      is.na(item_type) ~ NA_character_,
      tolower(item_type) %in% c("journalarticle", "journal article") ~ "journalArticle",
      tolower(item_type) %in% c("conferencepaper", "conference paper", "proceedings paper") ~ "conferencePaper",
      tolower(item_type) %in% c("preprint", "public preprint") ~ "preprint",
      TRUE ~ item_type
    ),
    item_type = factor(item_type, levels = type_levels)
  ) %>%
  filter(!is.na(year), !is.na(item_type))

if (nrow(publications) == 0) stop("No valid publication rows found in ", input_csv, call. = FALSE)
message("Valid publication rows used for Figure 1: ", nrow(publications))

# Store year bounds outside dplyr verbs. This avoids tidy-evaluation name conflicts
# after the count column is named `publications`.
year_min <- min(publications[["year"]], na.rm = TRUE)
year_max <- max(publications[["year"]], na.rm = TRUE)
all_years <- seq(year_min, year_max, by = 1)

count_by_year_type <- publications %>%
  count(year, item_type, name = "publications") %>%
  complete(
    year = all_years,
    item_type = factor(type_levels, levels = type_levels),
    fill = list(publications = 0)
  ) %>%
  arrange(year, item_type)

cumulative_counts <- count_by_year_type %>%
  group_by(year) %>%
  summarise(yearly_publications = sum(publications), .groups = "drop") %>%
  complete(year = all_years, fill = list(yearly_publications = 0)) %>%
  arrange(year) %>%
  mutate(cumulative_publications = cumsum(yearly_publications))

write_csv(count_by_year_type, file.path(table_dir, "figure1_publication_counts_by_year.csv"))

snowex_years <- tibble::tibble(
  year = c(2017, 2020, 2021),
  label = c("SnowEx 2017", "SnowEx 2020", "SnowEx 2021")
)
y_max <- max(110, max(cumulative_counts$cumulative_publications, na.rm = TRUE) + 5)
label_y <- max(cumulative_counts$cumulative_publications, na.rm = TRUE) * 0.70

plot_obj <- ggplot() +
  geom_vline(data = snowex_years, aes(xintercept = year), linetype = 2, color = "grey70") +
  geom_col(
    data = count_by_year_type,
    aes(x = year, y = publications, fill = item_type),
    width = 0.8
  ) +
  geom_line(
    data = cumulative_counts,
    aes(x = year, y = cumulative_publications, color = "cumulative"),
    linewidth = 0.75
  ) +
  geom_point(
    data = cumulative_counts,
    aes(x = year, y = cumulative_publications, color = "cumulative"),
    size = 1.5
  ) +
  geom_text(
    data = snowex_years,
    aes(x = year, y = label_y, label = label),
    angle = 90,
    color = "grey45",
    vjust = -0.5,
    size = 3.4,
    family = fig_font
  ) +
  scale_fill_manual(name = NULL, values = fill_values, labels = type_labels, drop = FALSE) +
  scale_color_manual(name = NULL, values = line_values, labels = c(cumulative = "Cumulative publications")) +
  scale_x_continuous(breaks = all_years, expand = c(0.01, 0)) +
  scale_y_continuous(limits = c(0, y_max), expand = c(0, 0.03)) +
  labs(x = "Year", y = "Publications (#)") +
  review_theme(base_size = 13, base_family = fig_font) +
  theme(
    legend.position = c(0.20, 0.67),
    legend.margin = margin(-5, 1, 1, 1),
    axis.text.x = element_text(angle = 45, hjust = 1, vjust = 0.9, size = 10),
    axis.title.x = element_text(vjust = 0)
  )

pdf_device <- if (capabilities("cairo")) grDevices::cairo_pdf else grDevices::pdf

ggsave(file.path(fig_dir, "figure1_publication_counts.pdf"), plot_obj, width = 8, height = 3.5, device = pdf_device)
ggsave(file.path(fig_dir, "figure1_publication_counts.png"), plot_obj, width = 8, height = 3.5, dpi = 500)
ggsave(file.path(fig_dir, "fig01.pdf"), plot_obj, width = 8, height = 3.5, device = pdf_device)
ggsave(file.path(fig_dir, "fig01.png"), plot_obj, width = 8, height = 3.5, dpi = 500)

message("Wrote: ", file.path(fig_dir, "figure1_publication_counts.pdf"))
message("Wrote: ", file.path(fig_dir, "fig01.pdf"))

