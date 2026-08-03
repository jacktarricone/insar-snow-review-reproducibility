#!/usr/bin/env Rscript

# Run all reproducible figure scripts from the repository root.
# Usage:
#   Rscript scripts/run_all.R

cmd <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd, value = TRUE)
if (length(file_arg) > 0) {
  repo_root <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE)), ".."), mustWork = TRUE)
} else {
  repo_root <- normalizePath(getwd(), mustWork = TRUE)
}
Sys.setenv(INSAR_SWE_REVIEW_DIR = repo_root, INSAR_SWE_REPRO_DIR = repo_root)

scripts <- c(
  file.path(repo_root, "scripts", "01_plot_publication_counts.R"),
  file.path(repo_root, "scripts", "02_plot_study_locations_map.R")
)

for (script in scripts) {
  message("Running ", basename(script))
  source(script, local = new.env(parent = globalenv()))
}

message("Done. See outputs/figures and outputs/tables.")
