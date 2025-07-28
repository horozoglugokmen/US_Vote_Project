# US Demographic and Political Preference Analysis

A comprehensive spatial analysis of US demographic characteristics and voting behavior using R and machine learning techniques.

## Project Overview

This project analyzes the relationship between demographic factors (race, income) and voting patterns across US counties using advanced spatial analysis methods and machine learning algorithms.

**Dataset Scale**: Analysis of **~100,000 records** across multiple datasets including 3109 county, salary income, race, election results, and spatial geometries covering the entire United States.

### Key Features

- **Spatial Data Processing**: Integration of multiple shapefiles and demographic datasets
- **Statistical Analysis**: OLS regression, spatial lag/error models, and correlation analysis
- **Machine Learning**: Random Forest and XGBoost models with spatial feature engineering
- **Visualization**: Interactive maps and statistical plots
- **Data Quality Control**: Comprehensive data validation and cleaning procedures

## Repository Structure

```
├── us_demographic_political_pref.Rmd     # Main analysis file
├── README.md                              # This file
├── LICENSE                                # MIT License
├── data/                                  # Data directory (see setup)
│   ├── race_2.xlsx                       # Race demographic data
│   ├── gov.csv                           # Election results
│   ├── fips.csv                          # FIPS codes
│   ├── latest_merged_data.xlsx           # Pre-merged dataset
│   ├── tiger/                            # US Tiger shapefiles
│   ├── smallshp/                         # Connecticut old boundaries
│   └── small_tiger/                      # Connecticut new boundaries (2024)
└── outputs/                              # Generated analysis outputs
    ├── plots/                            # Statistical visualizations
    ├── maps/                             # Geographic distribution maps
    └── tables/                           # Model performance results
```


### Required R Packages

```r
install.packages(c(
  "jsonlite", "dplyr", "readxl", "tidyr", "sf", 
  "spdep", "spatialreg", "ggplot2", "cowplot", 
  "leaflet", "randomForest", "xgboost", "caret"
))
```

   - `race_2.xlsx`: Demographic data by county
   - `gov.csv`: Election results with county FIPS codes
   - `fips.csv`: FIPS code mappings
   - Shapefile directories with complete .shp, .dbf, .shx, .prj files

**Note**: All file paths are configured as relative paths in the `DATA_PATHS` list for portability across different systems.


### Key Analysis Steps

1. **Data Loading and Cleaning** (Sections 1-2)
   - Loads demographic, voting, and spatial data
   - Performs data cleaning and standardization

2. **Spatial Data Processing** (Sections 3-5)
   - Handles shapefile integration
   - Performs spatial interpolation for Connecticut case study

3. **Statistical Analysis** (Sections 6-8)
   - Regression modeling
   - Correlation analysis
   - Data quality assessment

4. **Visualization** (Sections 9-10)
   - Scatter plots and geographic maps
   - Population density visualizations

5. **Spatial Analysis** (Section 11)
   - Spatial autocorrelation testing (Moran's I)
   - Spatial lag and error models

6. **Machine Learning** (Section 12)
   - Random Forest and XGBoost models
   - Feature importance analysis
   - Model comparison and evaluation

## Key Results

### Statistical Findings

- **Demographic Impact**: Strong correlations between racial composition and voting patterns
- **Income Effects**: Significant relationship between salary income and party preferences
- **Spatial Patterns**: Confirmed spatial autocorrelation in voting behavior

## Spatial Analysis Features

- **Spatial Weights Matrix**: Queen contiguity-based neighborhood relationships
- **Moran's I Test**: Spatial autocorrelation detection
- **Spatial Regression**: Lag and error model implementations
- **Feature Engineering**: Spatial lag variables for ML models

## Visualizations

The analysis generates several types of visualizations:

- **Choropleth Maps**: County-level demographic and voting patterns
- **Scatter Plots**: Relationships between variables
- **Population Density Maps**: Spatial distribution analysis
- **Feature Importance Plots**: ML model interpretability


### File Paths

All file paths are configured in the `DATA_PATHS` list and use relative paths for portability.

## Data Sources

- **Demographic Data**: US Census Bureau
- **Election Data**: County-level election results
- **Spatial Data**: TIGER/Line Shapefiles
- **Income Data**: American Community Survey (ACS) via Census API


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.



- **Author**: Gokmen Horozoglu
- **GitHub**: [@horozoglugokmen](https://github.com/horozoglugokmen)

---

**Disclaimer**: This analysis is for academic research purposes. All data used is from publicly available sources. 
