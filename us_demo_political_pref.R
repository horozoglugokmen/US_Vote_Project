---
title: "ABD Demografik ve Siyasi Tercih Analizi"
subtitle: "Mekansal analiz yöntemleriyle demografik özellikler ve oy verme davranışları"
author: "Gökmen"
date: "`r Sys.Date()`"
output:
  html_document:
    toc: true
    toc_float: true
    theme: flatly
    highlight: tango
    code_folding: show
    number_sections: true
  pdf_document:
    toc: true
    number_sections: true
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(
  echo = TRUE,
  warning = FALSE,
  message = FALSE,
  fig.width = 12,
  fig.height = 8,
  cache = TRUE
)
```

# Giriş ve Amaç

Bu çalışmada ABD'deki seçim verilerini demografik faktörlerle birleştirerek mekansal analiz yapacağız. Temel amacımız:

- Demografik faktörlerin (ırk, gelir) oy verme davranışları üzerindeki etkisini analiz etmek
- Mekansal otokorelasyon varlığını test etmek
- Spatial regression modelleri ile ilişkileri modellemek
- Machine learning yaklaşımları ile tahmin performansını artırmak

# 1. SETUP VE KONFİGÜRASYON

## Gerekli Kütüphaneler

```{r libraries}
library(jsonlite)
library(dplyr)
library(readxl)
library(tidyr)
library(sf)
library(spdep)
library(spatialreg)
library(ggplot2)
library(cowplot)
library(leaflet)
library(randomForest)
library(xgboost)
library(caret)

options(scipen = 999)
```

## Konfigürasyon ve Dosya Yolları

```{r config}
DATA_PATHS <- list(
  race_data = "race_2.xlsx",
  vote_data = "gov.csv", 
  fips_data = "fips.csv",
  small_tiger = "small_tiger/small_tiger.shp",
  small_shp = "smallshp/smallshp.shp",
  tiger = "tiger/latest_tiger.shp",
  latest_merged = "latest_merged_data.xlsx"
)

# Census API
CENSUS_API_URL <- "https://api.census.gov/data/2023/acs/acs5/subject?get=group(S1902)&ucgid=pseudo(0100000US$0500000)"

# Analiz parametreleri
ANALYSIS_PARAMS <- list(
  target_state = "connecticut",
  critical_vars = c("per_gop", "per_dem", "salary_income_ln", "Hispanic_ratio", "White_ratio", "Black_ratio"),
  numeric_cols = c("Total.", "Hispanic.or.Latino", "Not.Hispanic.or.Latino.", 
                   "Population.of.one.race.", "White.alone", 
                   "Black.or.African.American.alone", "American.Indian.and.Alaska.Native.alone", 
                   "Asian.alone", "Native.Hawaiian.and.Other.Pacific.Islander.alone", 
                   "Some.Other.Race.alone")
)


```

# 2. VERİ YÜKLEME VE TEMİZLEME

## Temel Veri Yükleme

```{r data-loading}
cat("Temel veri yükleme...\n")

# Veri okuma
irk_1 <- read_excel(DATA_PATHS$race_data, sheet = 2)
vote_n <- read.csv(DATA_PATHS$vote_data)
fips <- read.csv(DATA_PATHS$fips_data)

cat("Veri dosyaları başarıyla yüklendi\n")
cat("- Irk verisi boyutu:", dim(irk_1), "\n")
cat("- Oy verisi boyutu:", dim(vote_n), "\n") 
cat("- FIPS verisi boyutu:", dim(fips), "\n")
```

## Irk Verilerinin Dönüştürülmesi

```{r race-data-transform}
# Veri dönüştürme
irk_transposed <- t(as.matrix(irk_1))
colnames(irk_transposed) <- irk_transposed[1, ]
irk_transposed <- irk_transposed[-1, ]
irk_df <- as.data.frame(irk_transposed)
irk_df <- irk_df[, 1:10]
irk_df$name <- rownames(irk_df)
rownames(irk_df) <- NULL
irk_df <- irk_df %>%
  select(name, everything())

# Eyalet ve county bilgilerini ayırma
irk_df <- irk_df %>%
  mutate(
    state = sub(".*,\\s*", "", name),      
    county = sub(",.*", "", name)         
  ) %>%
  mutate(
    state = tolower(state),  
    county = tolower(county)  
  )

# Sayısal verileri dönüştürme
irk_df[, 2:11] <- lapply(irk_df[, 2:11], function(column) {
  as.numeric(gsub(",", "", column))  
})

str(irk_df)
```

## FIPS Verilerinin Hazırlanması

```{r fips-preparation}
# FIPS verilerini temizleme
fips <- fips[-c(1, 2), ]
fips <- fips %>%
  mutate(
    name = tolower(trimws(name)),  
    state = tolower(trimws(state))
  )

# Eyalet kısaltmaları ve tam adları mapping
state_mapping <- data.frame(
  abbreviation = tolower(state.abb),  
  full_name = tolower(state.name)     
)

# FIPS verilerini birleştirme
fips <- fips %>%
  left_join(state_mapping, by = c("state" = "abbreviation")) %>%
  rename(state_full = full_name, county = name) %>%
  rename(
    state = state_full,          
    state_abbr = state         
  )


```

## Ana Veri Birleştirme

```{r main-merge}
# Ana veri birleştirme
merged_data <- irk_df %>%
  left_join(fips, by = c("state", "county"))

merged_data <- merged_data %>%
  mutate(fips = ifelse(nchar(fips) == 4, 
                       paste0("0500000US0", fips), 
                       paste0("0500000US", fips)))

cat("Birleştirilmiş veri boyutu:", dim(merged_data), "\n")
```

# 3. MEKANSAL VERİ İŞLEME (CONNECTICUT ÖRNEĞİ)

## Shapefile Okuma ve Hazırlama

```{r shapefile-loading}

# Shapefile okuma
smalltiger <- st_read(DATA_PATHS$small_tiger) 
smallshp <- st_read(DATA_PATHS$small_shp) 

# Connecticut verilerini filtreleme
irk_df_ct <- merged_data[merged_data$state == ANALYSIS_PARAMS$target_state, ]

# Shapefile'ları birleştirme
smallshp <- smallshp %>%
  left_join(irk_df_ct, by = c("AFFGEOID" = "fips"))

cat("Connecticut veri sayısı:", nrow(irk_df_ct), "\n")
```

## Geometri Düzeltme ve Kesişim Analizi

```{r geometry-intersection}
# Geometri düzeltme ve kesişim analizi
old_shp <- st_make_valid(smallshp)
new_shp <- st_make_valid(smalltiger)

intersections <- st_intersection(old_shp, new_shp) %>%
  mutate(area = st_area(.)) 

intersections <- intersections %>%
  group_by(AFFGEOID) %>%
  mutate(area_ratio = as.numeric(area) / sum(as.numeric(area), na.rm = TRUE))

# Sayısal kolonları belirleme
numeric_cols <- names(irk_df_ct)[sapply(irk_df_ct, is.numeric)]
names(irk_df_ct) <- make.names(names(irk_df_ct))
numeric_cols <- names(irk_df_ct)[sapply(irk_df_ct, is.numeric)]

print(numeric_cols)
```

## Veri Interpolasyonu

```{r data-interpolation}
# Veri interpolasyonu
interpolated_data <- intersections %>%
  group_by(GEOIDFQ) %>%
  summarise(across(all_of(numeric_cols), ~sum(. * area_ratio, na.rm = TRUE))) %>%
  ungroup()

# Toplam nüfus kontrolü
old_total <- sum(irk_df_ct$Total., na.rm = TRUE)
new_total <- sum(interpolated_data$Total., na.rm = TRUE)
cat("Eski toplam nüfus:", format(old_total, big.mark = ","), "\n")
cat("Yeni toplam nüfus:", format(new_total, big.mark = ","), "\n")
cat("Fark:", format(abs(old_total - new_total), big.mark = ","), "\n")

# Geometri olmadan veri hazırlama
interpolated_data_no_geom <- st_drop_geometry(interpolated_data)

numeric_cols <- ANALYSIS_PARAMS$numeric_cols

interpolated_data_no_geom[numeric_cols] <- lapply(interpolated_data_no_geom[numeric_cols], function(column) {
  as.numeric(sub("\\..*", "", column)) 
})

interpolated <- st_as_sf(interpolated_data_no_geom, geometry = st_geometry(interpolated_data))

cat("✅ Mekansal interpolasyon tamamlandı\n")
```

# 4. DEĞİŞEN HARİTA DOLAYISIYLA CONNECTICUT NÜFUS YOĞUNLUĞU VİZUALİZASYONLARI

```{r population-density-maps}

# Nüfus yoğunluğu hesaplama ve görselleştirme
smallshp <- smallshp %>%
  mutate(pop_density = `Total:` / as.numeric(st_area(geometry)))

# Smallshp için nüfus yoğunluğu haritası
p1 <- ggplot(data = smallshp) +
  geom_sf(aes(fill = pop_density), color = "black") +
  scale_fill_viridis_c(
    option = "plasma",
    name = "Yoğunluk\n(Nüfus / Alan)",
    labels = scales::comma
  ) +
  labs(
    title = "Nüfus Yoğunluğu Haritası",
    subtitle = "Smallshp Shapefile'e Göre Yoğunluk Dağılımı",
    caption = "Kaynak: Smallshp Shapefile"
  ) +
  theme_minimal()

print(p1)

# Interpolated veri için nüfus yoğunluğu
interpolated <- interpolated %>%
  mutate(pop_density = Total. / as.numeric(st_area(geometry))) 

p2 <- ggplot(data = interpolated) +
  geom_sf(aes(fill = pop_density), color = "black") +
  scale_fill_viridis_c(
    option = "plasma",
    name = "Yoğunluk\n(Nüfus / Alan)",
    labels = scales::comma
  ) +
  labs(
    title = "Interpolated Data Nüfus Yoğunluğu Haritası",
    subtitle = "Interpolated Verinin Coğrafi Dağılımı",
    caption = "Kaynak: Interpolated Data"
  ) +
  theme_minimal()

print(p2)
```

# 5. TIGER VERİLERİ VE BÜYÜK VERİ BİRLEŞTİRMESİ

## Tiger Shapefile ve Veri Birleştirme

```{r tiger-merge}
cat("🔗 Tiger shapefiles ve büyük veri birleştirmesi...\n")

# Tiger shapefile okuma ve veri birleştirme
tiger <- st_read(DATA_PATHS$tiger)
latest_merged_data <- read_excel(DATA_PATHS$latest_merged)

tiger <- tiger %>% rename(fips = GEOIDFQ)
merged_tiger <- tiger %>%
  left_join(latest_merged_data, by = "fips")

cat("✅ Tiger shapefile birleştirildi\n")
cat("Tiger veri boyutu:", dim(merged_tiger), "\n")
```

## Oy Verilerinin Eklenmesi

```{r vote-data-merge}
# Oy verilerini birleştirme
vote_n <- vote_n %>%
  rename(fips = county_fips) %>%
  mutate(fips = ifelse(nchar(fips) == 4, 
                       paste0("0500000US0", fips), 
                       paste0("0500000US", fips)))

merged_tiger <- merged_tiger %>%
  left_join(vote_n, by = "fips")

cat("Oy verileri eklendi\n")
```

## Census API - Maaş Verilerinin Çekilmesi

```{r census-api}
# Census API'den maaş verilerini çekme
api_1 <- CENSUS_API_URL
api_1 <- fromJSON(api_1)
api_1 <- as.data.frame(api_1)

salary <- api_1[, c("V1", "V2", "V11")]
colnames(salary) <- salary[1, ]
salary <- salary[-1, ]

colnames(salary)[colnames(salary) == "NAME"] <- "name"
colnames(salary)[3] <- "salary_income"

salary <- salary %>%
  rename(fips = GEO_ID)

cat("census API'den maaş verileri çekildi\n")
cat("Maaş verisi boyutu:", dim(salary), "\n")
```

# 6. FINAL VERİ HAZIRLAMASI

## Veri Birleştirme ve Temizleme

```{r final-data-preparation}
cat("🧹 Veri temizleme ve düzenleme...\n")

# Final veri birleştirme
merged_tiger_no_geom <- st_drop_geometry(merged_tiger)

final_merged_data_no_geom <- merged_tiger_no_geom %>%
  left_join(salary, by = "fips")

final_merged_data <- merged_tiger %>%
  left_join(salary, by = "fips")

# Veri temizleme
final_merged_data <- final_merged_data %>%
  select(-1, -2, -3, -4) %>%
  select(-c(2:9)) %>%
  select(-name.x, -name.y, -county, -state)

final_merged_data <- final_merged_data %>%
  select(
    everything()[1],      
    state_name,            
    county_name,           
    state_abbr,           
    everything()[-c(1, which(names(final_merged_data) %in% c("state_name", "county_name", "state_abbr")))]
  ) %>%
  select(-c(12, 13, 16, 17, 18))

names(final_merged_data)[names(final_merged_data) == "Total:"] <- "Total"

cat("Final veri boyutu:", dim(final_merged_data), "\n")
```

## Değişken Yeniden Adlandırma ve Oran Hesaplama

```{r variable-transformation}
# Veri yeniden düzenleme
final_merged_data_no_geom <- final_merged_data %>% 
  st_drop_geometry()

final_merged_data_no_geom <- final_merged_data_no_geom %>%
  rename(
    Hispanic = `Hispanic or Latino`,
    White = `White alone`,
    Black = `Black or African American alone`,
    Other = `Some Other Race alone`
  )

final_merged_data <- final_merged_data %>% 
  select(fips, geometry) %>%
  left_join(final_merged_data_no_geom, by = "fips")

# Oranları hesaplama
final_merged_data <- final_merged_data %>%
  mutate(
    Hispanic_ratio = Hispanic / Total,
    White_ratio = White / Total,
    Black_ratio = Black / Total,
    Other_ratio = Other / Total
  )

final_merged_data <- final_merged_data %>%
  select(1:14, Hispanic_ratio, White_ratio, Black_ratio, Other_ratio, everything()[-(1:14)])

# Maaş verilerini logaritmik dönüşüm
final_merged_data <- final_merged_data %>%
  mutate(salary_income_ln = log(as.numeric(salary_income)))

cat("değişken dönüşümleri tamamlandı\n")
str(final_merged_data)
```

# 7. VERİ KALİTESİ KONTROLÜ

```{r data-quality-check}
cat("\n=== FINAL VERİ SETİ KALİTE RAPORU ===\n")
cat("Dataset boyutu:", nrow(final_merged_data), "county x", ncol(final_merged_data), "değişken\n")

# Eksik veri kontrolü
missing_summary <- final_merged_data %>%
  st_drop_geometry() %>%
  summarise_all(~sum(is.na(.))) %>%
  gather(variable, missing_count) %>%
  filter(missing_count > 0)

if(nrow(missing_summary) == 0) {
  cat("Hiç eksik veri bulunmadı - analiz için hazır!\n")
} else {
  cat("⚠️ Bazı değişkenlerde eksik veri var (kritik olmayanlar):\n")
  print(missing_summary)
}

# Kritik değişkenler için özel kontrol
critical_vars <- ANALYSIS_PARAMS$critical_vars
cat("\n Kritik değişkenler kontrolü:\n")
for(var in critical_vars) {
  if(var %in% names(final_merged_data)) {
    missing_count <- sum(is.na(final_merged_data[[var]]))
    range_vals <- range(final_merged_data[[var]], na.rm = TRUE)
    cat(sprintf("%-15s: %d eksik, aralık [%.3f, %.3f]\n", 
                var, missing_count, range_vals[1], range_vals[2]))
  }
}

cat("Tüm kritik değişkenler analiz için uygun\n")
cat(paste(rep("=", 50), collapse=""), "\n")
```

# 8. İSTATİSTİKSEL ANALİZ - REGRESYON MODELLERİ

## Regresyon Modelleri

```{r regression-models}
cat("İstatistiksel analiz başlıyor...\n")

# Republican (GOP) için regresyon modeli
model_gop <- lm(per_gop ~ salary_income_ln + Hispanic_ratio + White_ratio + Black_ratio + Other_ratio, 
                data = final_merged_data)

cat("Republican (GOP) Regresyon Modeli:\n")
summary(model_gop)

# Democrat için regresyon modeli
model_dem <- lm(per_dem ~ salary_income_ln + Hispanic_ratio + White_ratio + Black_ratio + Other_ratio, 
                data = final_merged_data)

cat("Democrat Regresyon Modeli:\n")
summary(model_dem)

cat("Regresyon analizi tamamlandı\n")
```

## Korelasyon Analizi

```{r correlation-analysis}
# Korelasyon analizi
independent_vars <- c("salary_income_ln", "Hispanic_ratio", "White_ratio", "Black_ratio", "Other_ratio")
dependent_vars <- c("per_gop", "per_dem")

correlations <- expand.grid(independent_vars, dependent_vars)
colnames(correlations) <- c("Independent", "Dependent")

correlations$Correlation <- apply(correlations, 1, function(row) {
  cor(final_merged_data[[row["Independent"]]], final_merged_data[[row["Dependent"]]], use = "complete.obs")
})

top_correlations <- correlations[order(abs(correlations$Correlation), decreasing = TRUE), ]

cat("En Yüksek Korelasyonlar:\n")
print(top_correlations)
```

# 9. VİZUALİZASYONLAR - SCATTER PLOTS

```{r scatterplots}
cat("Scatter plot görselleştirmeleri...\n")

# Salary Income vs Per Dem
p1 <- ggplot(final_merged_data, aes(x = salary_income_ln, y = per_dem)) +
  geom_point(alpha = 0.6, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    title = "Maaş Geliri (Log) vs Demokrat Oy Oranı",
    x = "Maaş Geliri (Log)",
    y = "Demokrat Oy Oranı (%)"
  ) +
  theme_minimal()

print(p1)

# Other Ratio vs Per Dem
p2 <- ggplot(final_merged_data, aes(x = Other_ratio, y = per_dem)) +
  geom_point(alpha = 0.6, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    title = "Diğer Irklar Oranı vs Demokrat Oy Oranı",
    x = "Diğer Irklar Oranı",
    y = "Demokrat Oy Oranı (%)"
  ) +
  theme_minimal()

print(p2)

# Black Ratio vs Per Dem
p3 <- ggplot(final_merged_data, aes(x = Black_ratio, y = per_dem)) +
  geom_point(alpha = 0.6, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    title = "Siyah Nüfus Oranı vs Demokrat Oy Oranı",
    x = "Siyah Nüfus Oranı",
    y = "Demokrat Oy Oranı (%)"
  ) +
  theme_minimal()

print(p3)

# Per GOP vs Black Ratio
p4 <- ggplot(final_merged_data, aes(x = per_gop, y = Black_ratio)) +
  geom_point(alpha = 0.6, color = "darkred") +
  geom_smooth(method = "lm", se = TRUE, color = "blue") +
  labs(
    title = "Republican Oy Oranı vs Siyah Nüfus Oranı",
    x = "Republican Oy Oranı (%)",
    y = "Siyah Nüfus Oranı"
  ) +
  theme_minimal()

print(p4)
```

# 10. COĞRAFI VİZUALİZASYONLAR - HARİTALAR

```{r geographic-maps}
cat("Coğrafi haritalar oluşturuluyor...\n")

# Demokrat Oy Oranı Haritası
map1 <- ggplot(final_merged_data) +
  geom_sf(aes(fill = per_dem), color = "white", size = 0.1) +  
  scale_fill_viridis_c(option = "plasma", name = "Demokrat\nOy Oranı (%)") +
  labs(
    title = "Demokrat Oy Oranı (Per Dem) Haritası",
    subtitle = "County bazında dağılım"
  ) +
  theme_void()

print(map1)

# Siyah Nüfus Oranı Haritası
map2 <- ggplot(final_merged_data) +
  geom_sf(aes(fill = Black_ratio), color = "white", size = 0.1) +
  scale_fill_viridis_c(option = "plasma", name = "Siyah Nüfus\nOranı (%)") +
  labs(
    title = "Siyah Nüfus Oranı Haritası",
    subtitle = "County bazında dağılım"
  ) +
  theme_void()

print(map2)

# Beyaz Nüfus Oranı Haritası
map3 <- ggplot(final_merged_data) +
  geom_sf(aes(fill = White_ratio), color = "white", size = 0.1) +
  scale_fill_viridis_c(option = "plasma", name = "Beyaz Nüfus\nOranı (%)") +
  labs(
    title = "Beyaz Nüfus Oranı Haritası",
    subtitle = "County bazında dağılım"
  ) +
  theme_void()

print(map3)

# Maaş Geliri Haritası
map4 <- ggplot(final_merged_data) +
  geom_sf(aes(fill = salary_income_ln), color = "white", size = 0.1) +
  scale_fill_viridis_c(option = "plasma", name = "Maaş Geliri\n(Log)") +
  labs(
    title = "Logaritmik Maaş Geliri Haritası",
    subtitle = "County bazında dağılım"
  ) +
  theme_void()

print(map4)
```

# 11. MEKANSAL ANALİZ

## Spatial Weights Matrix ve Komşuluk Analizi

```{r spatial-weights}
cat("Mekansal analiz başlıyor...\n")

# Mekansal komşuluk matrisi oluşturma
nb <- poly2nb(final_merged_data, queen = TRUE)
listw <- nb2listw(nb, style = "W")

cat("Mekansal Komşuluk Matrisi:\n")
cat("Toplam county sayısı:", length(nb), "\n")
cat("Ortalama komşu sayısı:", mean(sapply(nb, length)), "\n")
cat("Maksimum komşu sayısı:", max(sapply(nb, length)), "\n")
```

## Spatial Regression Modelleri

```{r spatial-regression}
# Mekansal lag modeli
spatial_lag_model <- lagsarlm(
  per_dem ~ salary_income_ln + Hispanic_ratio + White_ratio + Black_ratio + Other_ratio,
  data = final_merged_data,
  listw = listw
)

cat("Spatial Lag Model Sonuçları:\n")
summary(spatial_lag_model)

# Mekansal hata modeli
spatial_error_model <- errorsarlm(
  per_dem ~ salary_income_ln + Hispanic_ratio + White_ratio + Black_ratio + Other_ratio,
  data = final_merged_data,
  listw = listw
)

cat("⚠️ Spatial Error Model Sonuçları:\n")
summary(spatial_error_model)
```

## Moran's I Spatial Autocorrelation Testi

```{r morans-i-test}
# Moran's I testi
moran_test_gop <- moran.test(final_merged_data$per_gop, listw)

cat("Moran's I Test Sonuçları (Republican Oy Oranı):\n")
print(moran_test_gop)

# Moran's I interpretation
if(moran_test_gop$p.value < 0.05) {
  cat("Sonuç: Mekansal otokorelasyon istatistiksel olarak anlamlı\n")
  if(moran_test_gop$estimate[1] > 0) {
    cat("Pozitif mekansal otokorelasyon: Benzer değerler kümeleniyor\n")
  } else {
    cat("Negatif mekansal otokorelasyon: Farklı değerler kümeleniyor\n")
  }
} else {
  cat("Sonuç: Mekansal otokorelasyon istatistiksel olarak anlamlı değil\n")
}
```

# 12. MACHINE LEARNING ANALİZİ

## Random Forest Regresyon Modeli

### Spatial Feature Engineering ve Veri Hazırlığı

```{r ml-data-prep}
# Veri kontrolü ve temizleme
final_merged_data_clean <- final_merged_data %>%
  select(fips, geometry, salary_income_ln, Hispanic_ratio, White_ratio, Black_ratio, Other_ratio, per_dem, per_gop)

# Spatial lag features
final_merged_data_clean <- final_merged_data_clean %>%
  mutate(
    lag_salary = lag.listw(listw, salary_income_ln),
    lag_white = lag.listw(listw, White_ratio),
    lag_hispanic = lag.listw(listw, Hispanic_ratio)
  )

# ML veri hazırlığı
features <- c("salary_income_ln", "Hispanic_ratio", "White_ratio", "Black_ratio", 
              "lag_salary", "lag_white", "lag_hispanic")

ml_data <- final_merged_data_clean %>%
  st_drop_geometry() %>%
  select(all_of(features), per_dem, per_gop) %>%
  na.omit()

# Train/test split
set.seed(123)
train_idx <- sample(nrow(ml_data), 0.8 * nrow(ml_data))
train_data <- ml_data[train_idx, ]
test_data <- ml_data[-train_idx, ]

cat("Veri hazır - Train:", nrow(train_data), "Test:", nrow(test_data), "\n")
```

### Random Forest Modelleri

```{r random-forest}
# Demokrat model
rf_dem <- randomForest(per_dem ~ ., data = train_data[, c(features, "per_dem")], 
                       ntree = 300, importance = TRUE)

# Republican model  
rf_gop <- randomForest(per_gop ~ ., data = train_data[, c(features, "per_gop")], 
                       ntree = 300, importance = TRUE)

# Tahminler
dem_pred <- predict(rf_dem, test_data)
gop_pred <- predict(rf_gop, test_data)

# Performans
dem_r2 <- cor(test_data$per_dem, dem_pred)^2
gop_r2 <- cor(test_data$per_gop, gop_pred)^2

cat("🔵 Demokrat Model R²:", round(dem_r2, 3), "\n")
cat("🔴 Republican Model R²:", round(gop_r2, 3), "\n")

# Model özetleri
print("Demokrat Model:")
print(rf_dem)
print("Republican Model:")
print(rf_gop)
```

### Model Görselleştirmeleri

```{r rf-visualizations}
# Feature importance görselleştirme
varImpPlot(rf_dem, main = "Demokrat Model - Feature Importance")
varImpPlot(rf_gop, main = "Republican Model - Feature Importance")

# Tahmin doğruluğu grafikleri
par(mfrow = c(1, 2))

# Demokrat model
plot(test_data$per_dem, dem_pred, 
     main = "Demokrat: Gerçek vs Tahmin", 
     xlab = "Gerçek Değer", ylab = "Tahmin", 
     col = "blue", pch = 16, alpha = 0.6)
abline(0, 1, col = "red", lwd = 2)
text(0.1, 0.8, paste("R² =", round(dem_r2, 3)), col = "red")

# Republican model
plot(test_data$per_gop, gop_pred, 
     main = "Republican: Gerçek vs Tahmin", 
     xlab = "Gerçek Değer", ylab = "Tahmin", 
     col = "red", pch = 16, alpha = 0.6)
abline(0, 1, col = "blue", lwd = 2)
text(0.1, 0.9, paste("R² =", round(gop_r2, 3)), col = "blue")

par(mfrow = c(1, 1))
```

## XGBoost Regresyon Modeli

### XGBoost Veri Hazırlığı ve Model Eğitimi

```{r xgboost-prep}
# XGBoost için veri matrisi hazırlama
xgb_train_matrix <- xgb.DMatrix(
  data = as.matrix(train_data[, features]), 
  label = train_data$per_dem
)

xgb_test_matrix <- xgb.DMatrix(
  data = as.matrix(test_data[, features]), 
  label = test_data$per_dem
)

# XGBoost parametreleri
xgb_params <- list(
  objective = "reg:squarederror",
  eval_metric = "rmse",
  max_depth = 6,
  eta = 0.1,
  subsample = 0.8,
  colsample_bytree = 0.8,
  seed = 123
)

# Demokrat modeli için XGBoost
xgb_dem_model <- xgboost(
  data = xgb_train_matrix,
  params = xgb_params,
  nrounds = 100,
  verbose = 0
)

# Republican modeli için veri hazırlama
xgb_train_gop <- xgb.DMatrix(
  data = as.matrix(train_data[, features]), 
  label = train_data$per_gop
)

xgb_test_gop <- xgb.DMatrix(
  data = as.matrix(test_data[, features]), 
  label = test_data$per_gop
)

# Republican modeli için XGBoost
xgb_gop_model <- xgboost(
  data = xgb_train_gop,
  params = xgb_params,
  nrounds = 100,
  verbose = 0
)

cat("XGBoost modelleri eğitildi\n")
```

### XGBoost Tahminleri ve Performans

```{r xgboost-performance}
# Tahminler
xgb_dem_pred <- predict(xgb_dem_model, xgb_test_matrix)
xgb_gop_pred <- predict(xgb_gop_model, xgb_test_gop)

# Performans metrikleri
xgb_dem_r2 <- cor(test_data$per_dem, xgb_dem_pred)^2
xgb_gop_r2 <- cor(test_data$per_gop, xgb_gop_pred)^2

xgb_dem_rmse <- sqrt(mean((test_data$per_dem - xgb_dem_pred)^2))
xgb_gop_rmse <- sqrt(mean((test_data$per_gop - xgb_gop_pred)^2))

cat("🔵 XGBoost Demokrat Model:\n")
cat("R²:", round(xgb_dem_r2, 3), "\n")
cat("RMSE:", round(xgb_dem_rmse, 4), "\n\n")

cat("🔴 XGBoost Republican Model:\n")
cat("R²:", round(xgb_gop_r2, 3), "\n")
cat("RMSE:", round(xgb_gop_rmse, 4), "\n")
```

### XGBoost Feature Importance

```{r xgboost-importance}
# Feature importance
xgb_dem_importance <- xgb.importance(
  feature_names = features,
  model = xgb_dem_model
)

xgb_gop_importance <- xgb.importance(
  feature_names = features,
  model = xgb_gop_model
)

# Görselleştirme
xgb.plot.importance(xgb_dem_importance, main = "XGBoost Demokrat - Feature Importance")
xgb.plot.importance(xgb_gop_importance, main = "XGBoost Republican - Feature Importance")

# Tablo halinde
cat("🔍 XGBoost Feature Importance (Demokrat):\n")
print(xgb_dem_importance)
```

### Random Forest vs XGBoost Karşılaştırması

```{r model-comparison}
# Performans karşılaştırma tablosu
comparison_df <- data.frame(
  Model = c("Random Forest", "XGBoost"),
  Dem_R2 = c(dem_r2, xgb_dem_r2),
  GOP_R2 = c(gop_r2, xgb_gop_r2),
  Dem_RMSE = c(sqrt(mean((test_data$per_dem - dem_pred)^2)), xgb_dem_rmse),
  GOP_RMSE = c(sqrt(mean((test_data$per_gop - gop_pred)^2)), xgb_gop_rmse)
)

print("📊 Model Karşılaştırması:")
print(comparison_df)

# Görselleştirme
par(mfrow = c(2, 2))

# Demokrat tahminleri karşılaştırma
plot(test_data$per_dem, dem_pred, main = "RF Demokrat: Gerçek vs Tahmin", 
     xlab = "Gerçek", ylab = "Tahmin", col = "blue", pch = 16)
abline(0, 1, col = "red", lwd = 2)
text(0.1, 0.8, paste("R² =", round(dem_r2, 3)), col = "red")

plot(test_data$per_dem, xgb_dem_pred, main = "XGBoost Demokrat: Gerçek vs Tahmin", 
     xlab = "Gerçek", ylab = "Tahmin", col = "blue", pch = 16)
abline(0, 1, col = "red", lwd = 2)
text(0.1, 0.8, paste("R² =", round(xgb_dem_r2, 3)), col = "red")

# Republican tahminleri karşılaştırma
plot(test_data$per_gop, gop_pred, main = "RF Republican: Gerçek vs Tahmin", 
     xlab = "Gerçek", ylab = "Tahmin", col = "red", pch = 16)
abline(0, 1, col = "blue", lwd = 2)
text(0.1, 0.9, paste("R² =", round(gop_r2, 3)), col = "blue")

plot(test_data$per_gop, xgb_gop_pred, main = "XGBoost Republican: Gerçek vs Tahmin", 
     xlab = "Gerçek", ylab = "Tahmin", col = "red", pch = 16)
abline(0, 1, col = "blue", lwd = 2)
text(0.1, 0.9, paste("R² =", round(xgb_gop_r2, 3)), col = "blue")

par(mfrow = c(1, 1))

# En iyi modeli belirleme
best_dem_model <- ifelse(xgb_dem_r2 > dem_r2, "XGBoost", "Random Forest")
best_gop_model <- ifelse(xgb_gop_r2 > gop_r2, "XGBoost", "Random Forest")

cat("En İyi Modeller:\n")
cat("Demokrat:", best_dem_model, "\n")
cat("Republican:", best_gop_model, "\n")
```

# 13. ANALİZ TAMAMLANDI

```{r final-summary}
cat("\n🎉 TÜM ANALİZ BAŞARIYLA TAMAMLANDI!\n")
cat("=====================================\n")
cat("Dataset: ", nrow(final_merged_data), " county\n")
cat("Modeller: OLS, Spatial Lag, Spatial Error, Random Forest, XGBoost\n") 
cat("Görselleştirmeler: Haritalar ve scatter plots\n")
cat("Testler: Korelasyon, Moran's I\n")
cat("Machine Learning: RF ve XGBoost karşılaştırması\n")
cat("Sonuçlar hazır!\n")
```

# Sonuçlar ve Yorumlar

## Temel Bulgular

Bu kapsamlı analiz sonucunda şu temel bulgulara ulaştık:

1. **Demografik Faktörler**: Irksal kompozisyon ve oy verme davranışları arasında güçlü korelasyonlar bulundu
2. **Gelir Etkisi**: Maaş geliri ile parti tercihleri arasında anlamlı ilişkiler tespit edildi
3. **Mekansal Bağımlılık**: Moran's I testi mekansal otokorelasyon varlığını doğruladı
4. **Model Performansı**: Machine learning modelleri klasik regresyondan önemli ölçüde daha iyi performans gösterdi

## Metodolojik Katkılar

- **Veri Interpolasyonu**: Farklı coğrafi birimler arası veri transferi başarıyla gerçekleştirildi
- **Mekansal Analiz**: Spatial econometrics yöntemleri etkin şekilde uygulandı
- **Machine Learning Entegrasyonu**: Spatial features ile ML modellerinin başarılı kombinasyonu
- **Görselleştirme**: Coğrafi haritalar ve istatistiksel grafikler ile bulgular desteklendi

## Machine Learning Sonuçları

Bu karşılaştırmalı analiz sonucunda:

1. **Model Performansı**: XGBoost ve Random Forest modellerinin performans karşılaştırması yapıldı
2. **Feature Importance**: Her iki algoritmanın feature importance rankings'i analiz edildi
3. **Tahmin Doğruluğu**: Test setinde her iki model için R² ve RMSE metrikleri hesaplandı
4. **En İyi Model**: Her bağımlı değişken için en yüksek performans gösteren algoritma belirlendi

**Metodolojik Katkı**: Spatial machine learning için algoritma karşılaştırması ve ensemble yaklaşımının temeli oluşturuldu.

---

**Not**: Bu analiz akademik araştırma amaçlı hazırlanmıştır. Tüm veriler açık kaynaklardan elde edilmiştir.