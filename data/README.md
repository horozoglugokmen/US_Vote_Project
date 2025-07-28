# Data Directory

This directory contains all the datasets and shapefiles used in the US Demographic and Political Preference Analysis.

**Total Dataset Size**: Approximately **100,000 records** across multiple data sources, including county-level demographics, election results, and spatial geometries for comprehensive US coverage.

## Files Description

### CSV Files
- `race_2.xlsx` - Demographic data by race from US Census
- `gov.csv` - Election results data by county
- `fips.csv` - FIPS codes mapping for counties
- `latest_merged_data.xlsx` - Pre-merged demographic dataset

### Shapefiles
- `small_tiger/` - Connecticut specific Tiger shapefiles (new 2024 boundaries)
- `smallshp/` - Connecticut shapefiles (old boundaries)  
- `tiger/` - Complete US Tiger shapefiles

## Data Sources

- **Demographic Data**: US Census Bureau
- **Election Data**: County-level election results
- **Spatial Data**: TIGER/Line Shapefiles from US Census
- **Income Data**: American Community Survey (ACS) via Census API

## Note

Due to file size limitations, actual data files may not be included in the GitHub repository. 
Please refer to the main README.md for instructions on obtaining the required datasets.

## Usage

The R script `us_demo_political_pref.R` automatically loads all files from this directory using relative paths. 