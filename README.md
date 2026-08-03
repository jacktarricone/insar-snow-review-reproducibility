# InSAR seasonal snow review reproducibility materials

R code and supporting data for the original analyses in Figures 1, 3, and 8 of **Interferometric Synthetic Aperture Radar (InSAR) for Monitoring Seasonal Snow**.

- GitHub repository: https://github.com/jacktarricone/insar-snow-review-reproducibility
- Archived release: https://doi.org/10.5281/zenodo.21776012

## Contents

- `scripts/01_plot_publication_counts.R`: Figure 1
- `scripts/02_plot_study_locations_map.R`: Figure 3
- `scripts/03_plot_nisar_orbits_wus_map_optional.R`: Figure 8
- `scripts/run_all.R`: runs Figures 1 and 3
- `scripts/check_inputs.R`: checks required inputs
- `data/csv/`: author-curated literature tables
- `data/rasters/` and `data/vectors/`: geospatial inputs

## Run

Install the required R packages:

```r
install.packages(c(
  "readr", "dplyr", "tidyr", "ggplot2", "scales",
  "sf", "terra", "patchwork", "grid", "units", "cowplot"
))
```

From the repository root:

```bash
Rscript scripts/check_inputs.R
Rscript scripts/run_all.R
```

Figure 8 also requires `MODIS_mtnsnow_classes.tif` from Wrzesien et al. (2019), DOI `10.5281/zenodo.2626737`. Place the file in `data/rasters/` and run:

```bash
Rscript scripts/03_plot_nisar_orbits_wus_map_optional.R
```

Generated figures and tables are written to `outputs/`.

## External data

Sources and licensing for third-party geospatial inputs are listed in `THIRD_PARTY_NOTICES.md`.

## Citation

Please cite the archived Version 1.0.0 Zenodo record:

> Tarricone, J. (2026). *Interferometric Synthetic Aperture Radar (InSAR) for Monitoring Seasonal Snow: Data and Code for Figure Generation* (Version 1.0.0) [Software]. Zenodo. https://doi.org/10.5281/zenodo.21776012

The repository also includes `CITATION.cff` for software citation metadata.

## License

- R code: MIT License, see `LICENSE`.
- Author-created CSV tables and documentation: CC BY 4.0, see `LICENSE_DATA.txt`.
- Third-party files retain their original terms.
