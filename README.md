# US Demographic and Political Preference Analysis

A comprehensive spatial analysis of US demographic characteristics and voting behavior using R and machine learning techniques.

## Project Overview

This project analyzes the relationship between demographic factors (race, income) and voting patterns across US counties using advanced spatial analysis methods and machine learning algorithms.

### Key Features

- **Spatial Data Processing**: Integration of multiple shapefiles and demographic datasets
- **Statistical Analysis**: OLS regression, spatial lag/error models, and correlation analysis
- **Machine Learning**: Random Forest and XGBoost models with spatial feature engineering
- **Visualization**: Interactive maps and statistical plots
- **Data Quality Control**: Comprehensive data validation and cleaning procedures

## Repository Structure

```
├── us_demographic_political_analysis.Rmd  # Main analysis file
├── README.md                              # This file
├── data/                                  # Data directory (see setup)
│   ├── race_2.xlsx                       # Race demographic data
│   ├── gov.csv                           # Election results
│   ├── fips.csv                          # FIPS codes
│   ├── latest_merged_data.xlsx           # Pre-merged dataset
│   ├── tiger/                            # Tiger shapefiles
│   ├── smallshp/                         # Small shapefiles
│   └── small_tiger/                      # Connecticut-specific shapefiles
└── output/                               # Generated outputs
    ├── plots/                            # Generated visualizations
    └── models/                           # Saved model objects
```

## Setup and Installation

### Prerequisites

- R (version 4.0 or higher)
- RStudio (recommended)
- Git

### Required R Packages

```r
install.packages(c(
  "jsonlite", "dplyr", "readxl", "tidyr", "sf", 
  "spdep", "spatialreg", "ggplot2", "cowplot", 
  "leaflet", "randomForest", "xgboost", "caret"
))
```

### Data Setup

1. Clone this repository:
```bash
git clone https://github.com/horozoglugokmen/US_Vote_Project.git
cd US_Vote_Project
```

2. Copy your data files to the project directory:
   - Place all `.xlsx`, `.csv` files in the root directory
   - Create subdirectories for shapefiles: `tiger/`, `smallshp/`, `small_tiger/`

3. Ensure your data structure matches the expected format:
   - `race_2.xlsx`: Demographic data by county
   - `gov.csv`: Election results with county FIPS codes
   - `fips.csv`: FIPS code mappings
   - Shapefile directories with complete .shp, .dbf, .shx, .prj files

## Usage

### Running the Analysis

1. Open `us_demographic_political_analysis.Rmd` in RStudio
2. Install required packages (if not already installed)
3. Run the entire notebook or execute chunks individually

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

## Configuration

### Customizable Parameters

Edit the `ANALYSIS_PARAMS` list in the configuration section:

```r
ANALYSIS_PARAMS <- list(
  target_state = "connecticut",  # State for detailed analysis
  critical_vars = c("per_gop", "per_dem", "salary_income_ln", 
                   "Hispanic_ratio", "White_ratio", "Black_ratio"),
  numeric_cols = c(...)  # Columns for processing
)
```

### File Paths

All file paths are configured in the `DATA_PATHS` list and use relative paths for portability.

## Data Sources

- **Demographic Data**: US Census Bureau
- **Election Data**: County-level election results
- **Spatial Data**: TIGER/Line Shapefiles
- **Income Data**: American Community Survey (ACS) via Census API

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- US Census Bureau for providing demographic and spatial data
- R community for excellent spatial analysis packages
- Contributors to the spatial econometrics and machine learning ecosystems

## Contact

- **Author**: Gokmen Horozoglu
- **GitHub**: [@horozoglugokmen](https://github.com/horozoglugokmen)
- **Project Link**: [US_Vote_Project](https://github.com/horozoglugokmen/US_Vote_Project/blob/main/us_demographic_political_analysis.Rmd)

---

**Disclaimer**: This analysis is for academic research purposes. All data used is from publicly available sources. 