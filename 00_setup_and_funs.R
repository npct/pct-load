#################
# PACKAGES NEEDED
#################

# Project settings - libraries you'll need to load
if(!require(devtools)) install.packages("devtools") # devtools allows installation of the latest packages

pkgs <- c(
  "ggmap",
  "tmap",
  "foreign", # loads external data
  "rgdal",   # for loading and saving geo* data
  "dplyr",   # for manipulating data rapidly
  "data.table",   # for reading in large csv files
  "sp",
  "velox",   # For rasters
  "raster",  # For rasters
  "rgeos",   # GIS functionality
  "raster",  # GIS functions
  "maptools", # GIS functions
  "stplanr", # Sustainable transport planning with R
  "tidyr", # tidies up your data!
  "readr", # reads your data fast
  "knitr", # for knitting it all together
  "geojsonio",
  "rmapshaper", # To simplify rnet
  "foreach",    # for rnet
  "doParallel"  # for rnet
)
# Which packages do we require?
reqs <- as.numeric(lapply(pkgs, require, character.only = TRUE))
# Install packages we require
if(sum(!reqs) > 0) install.packages(pkgs[!reqs], dependencies = TRUE)
rm(pkgs, reqs)


#################
# PCT PARAMETERS
#################

# Set Projection
proj_4326 <- CRS("+proj=longlat +init=epsg:4326")   # global projection - lat/long.
proj_27700 <- CRS("+init=epsg:27700")               # UK easting/northing projection - 'projected' (need if working in metres)

# set directory paths
path_inputs <- "../pct-inputs"
path_temp_cs <- "../pct-inputs/02_intermediate/x_temporary_files/cyclestreets"
path_temp_raster <- "../pct-inputs/02_intermediate/x_temporary_files/raster"
path_temp_scenario <- "../pct-inputs/02_intermediate/x_temporary_files/scenario_building"
path_temp_unzip <- "../pct-inputs/02_intermediate/x_temporary_files/unzip"
path_outputs_national <- "../pct-outputs-national"
path_outputs_regional_R <- "../pct-outputs-regional-R"
path_outputs_regional_notR <- "../pct-outputs-regional-notR"
path_outputs_regional_Rsmall <- "../pct-outputs-regional-Rsmall"
path_scripts <- "../pct-scripts"
path_shiny <- "../pct-shiny"
path_codebooks <- "../pct-shiny/regions_www/www/static/02_codebooks"


#################
# PCT FUNCTIONS
#################

# Set number of decimal places/significant figures for data frames
round_df <- function(x, dpdigits = 2, sfdigits = 3) {
  x1 <- as.numeric(x)
  # If non-integer >1, round to dp
  if ((x1 %% 1 != 0 && (x1<=-1 | x1>=1) && !is.na(x1)) == T) {
    x  <- as.numeric(round(x1, digits = dpdigits))
    # If non-integer <1, round to sf
  } else if ((x1 %% 1 != 0 && (x1>-1 & x1<1) && !is.na(x1)) == T) {
    x  <- as.numeric(signif(x1, digits = sfdigits))
    # If 'integer', round (otherwise get some '3.000' for scenario values), but don't do if >=1000 else get scientific notation which is messed up & becomes NA
  } else if ((x1 %% 1 == 0 && x1<1000 && !is.na(x1)) == T) {
    x  <- as.numeric(round(x1))
    # If missing/character, leave unchanged
  } else {
    x
  }
}


# Region names [NB copy of this also in pct-shiny///pct-shiny-funs - if modify here, modify there too]
get_pretty_region_name <- function(region_name_in, the = T){
  regions_thes <- c(
    "isle-of-wight" = "the Isle of Wight",
    "north-east" = "the North East",
    "west-midlands" = "the West Midlands"
  )
  region_name <- gsub("(\\b[[:alpha:]])", "\\U\\1", region_name_in, perl=TRUE)
  region_name <- gsub("-", " ", region_name)
  region_name <- gsub("(Of|And|The) ", "\\L\\1 ", region_name, perl=TRUE)
  
  if(the) {
    ifelse(!is.na(regions_thes[region_name_in]), regions_thes[region_name_in], region_name)
  } else {
    region_name
  }
}


# function to remove style from html page
remove_style = function(x){
  style_starts = grep("<style", x)
  style_ends = grep("</style", x)
  # Remove lines ONLY when the 'style' tag exists
  if ((length(style_starts) != 0 && length(style_ends) != 0))
    x[-(style_starts:style_ends)]
  else
    x
}


# Initiate the regional and LA geography input files
init_region <- function(region_type, geography, purpose){
  # LOAD PCT REGIONS
  if (region_type == "pct_regions"){
    assign("pct_regions_lad_lookup", read_csv(file.path(path_inputs, "01_raw/01_geographies/pct_regions/pct_regions_lad_lookup.csv")),  envir = .GlobalEnv)
    assign("build_params", read_csv(file.path(purpose, geography, "build_params_pct_region.csv")), envir = .GlobalEnv)
    regions_highres <- readOGR(file.path(path_inputs, "02_intermediate/01_geographies", "pct_regions_highres.geojson"))
    assign("regions_highres", spTransform(regions_highres, proj_4326), envir = .GlobalEnv)
  }
  # LOAD LAs
  las <- readOGR(dsn = file.path(path_inputs, "02_intermediate/01_geographies", "lad.geojson"))
  assign("las", spTransform(las, proj_4326), envir = .GlobalEnv)
}


#Initiate national output datasets
init_outputs_national <- function(purpose, geography){
  if(purpose == "commute") {
    assign("z_all", readRDS(file.path(path_outputs_national, purpose, geography,  "z_all.Rds")), envir = .GlobalEnv)
    assign("c_all", readRDS(file.path(path_outputs_national, purpose, geography,  "c_all.Rds")), envir = .GlobalEnv)
    assign("od_all_attributes", read_csv(file.path(path_outputs_national, purpose, geography, "od_all_attributes.csv")), envir = .GlobalEnv)
    assign("l_all", readRDS(file.path(path_outputs_national, purpose, geography, "l_all.Rds")), envir = .GlobalEnv)
    assign("rf_all", readRDS(file.path(path_outputs_national, purpose, geography, "rf_all.Rds")), envir = .GlobalEnv)
    assign("rq_all", readRDS(file.path(path_outputs_national, purpose, geography, "rq_all.Rds")), envir = .GlobalEnv)
  }
  if(purpose == "school") {
    assign("z_all", readRDS(file.path(path_outputs_national, purpose, geography,  "z_all.Rds")), envir = .GlobalEnv)
    assign("z_all_private", readRDS(file.path(path_outputs_national, purpose_private, geography,  "z_all.Rds")), envir = .GlobalEnv)
    assign("d_all", readRDS(file.path(path_outputs_national, purpose, geography,  "d_all.Rds")), envir = .GlobalEnv)
    assign("d_all_private", readRDS(file.path(path_outputs_national, purpose_private, geography,  "d_all.Rds")), envir = .GlobalEnv)
    assign("rf_shape", readRDS(file.path(path_inputs, "02_intermediate/02_travel_data", purpose, geography, "rf_shape.Rds")), envir = .GlobalEnv)
    assign("rnet_all_attributes", read_csv(file.path(path_temp_scenario, purpose, geography, "rnet_all_attributes.csv")), envir = .GlobalEnv)
  }
}


# Initiate R small dataset
init_Rsmall <- function(purpose){
  if(purpose == "commute") {
    assign("c_codebook_small", read_csv(file.path(path_codebooks, purpose, "c_codebook_small.csv")), envir = .GlobalEnv)
    assign("od_l_rf_codebook_small", read_csv(file.path(path_codebooks, purpose, "od_l_rf_codebook_small.csv")), envir = .GlobalEnv)
    assign("rq_codebook_small", read_csv(file.path(path_codebooks, purpose, "rq_codebook_small.csv")), envir = .GlobalEnv)
    assign("z_codebook_small", read_csv(file.path(path_codebooks, purpose, "z_codebook_small.csv")), envir = .GlobalEnv)
  }
  if(purpose == "school") {
    assign("d_codebook_small", read_csv(file.path(path_codebooks, purpose, "d_codebook_small.csv")), envir = .GlobalEnv)
    assign("z_codebook_small", read_csv(file.path(path_codebooks, purpose, "z_codebook_small.csv")), envir = .GlobalEnv)
  }  
}