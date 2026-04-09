# Unzipper
Mike Proctor
2025-11-06

This script, is designed to efficiently unzip geospatial archives (ZIP
files) from the defined source_path. It performs a selective extraction
based on the internal folder structure of each ZIP: all Shapefiles (SHP)
are flattened and aggregated into a single unzipped/shp folder, while
all File Geodatabases (FGDB) are extracted, and their unique .gdb folder
structure is preserved and moved into the unzipped/fgdb folder,
preventing data overwrites during the large-scale, concurrent
extraction.

Gemini was abused extensively in the composition of these scripts.

There is another version that uses parallel processing and is much
faster.

These were used primarily in working with files of land parcels
downloaded from \[TxGIO\]<https://data.geographic.texas.gov/> using
their bulk downloader. The zipfiles had shp files of parcels for each
county as well as gdb files for each county and one for the entire
state. The entire state is a little large to work with conviently so I
removed it before unzipping. The destination folder structure is the
complex part of the script. The gdb files for each county have to retain
their name and get put in a fgdb folder. The shape files were easier to
work with - they just ended up in a shp folder.

``` r
library(rprojroot)
library(tictoc)
library(beepr)

base_path       <- find_rstudio_root_file()
source_path     <- file.path(base_path, "source_data//")
unzip_path        <- file.path(base_path, "unzipped//")
zip_path        <- file.path(base_path, "zipped//")


# Define the final destination folders for the extracted contents
shp_destination_path <- file.path(unzip_path, "shp")
fgdb_destination_path <- file.path(unzip_path, "fgdb")

# Create the necessary destination folders
dir.create(source_path, recursive = TRUE, showWarnings = FALSE)
dir.create(shp_destination_path, recursive = TRUE, showWarnings = FALSE)
dir.create(fgdb_destination_path, recursive = TRUE, showWarnings = FALSE)

cat("--- Setup Complete ---\n")
```

    --- Setup Complete ---

``` r
cat("Zips are expected in: ", zip_path, "\n")
```

    Zips are expected in:  C:/Users/mike.proctor/__R__/Utilities/zipped/ 

``` r
cat("Shapefiles will be extracted to: ", shp_destination_path, "\n")
```

    Shapefiles will be extracted to:  C:/Users/mike.proctor/__R__/Utilities/unzipped//shp 

``` r
cat("Geodatabases will be extracted to: ", fgdb_destination_path, "\n\n")
```

    Geodatabases will be extracted to:  C:/Users/mike.proctor/__R__/Utilities/unzipped//fgdb 

``` r
# Get a list of all .zip files in the source directory
zip_files <- list.files(
  path = zip_path,
  pattern = "\\.zip$", # Ensure only zip files are selected
  full.names = TRUE # Get the full path for the unzip function
)

if (length(zip_files) == 0) {
  stop("No .zip files found in the source_path. Please check the path and file existence.")
}

cat("Found", length(zip_files), "zip files. Starting selective extraction...\n")
```

    Found 235 zip files. Starting selective extraction...

``` r
# --- 3. Loop and Perform Selective Unzip ---
tic()
sapply(zip_files, function(zip_file) {
  
  zip_name <- basename(zip_file)
  cat("\nProcessing:", zip_name, "\n")
  
  # A. Get the list of all files inside the current zip archive
  internal_files <- unzip(zip_file, list = TRUE)$Name
  
  # B. Extract FGDB files (Preserve folder structure!)
  fgdb_files_to_extract <- grep("^fgdb/", internal_files, value = TRUE)
  
  if (length(fgdb_files_to_extract) > 0) {
    # 1. Temporarily extract the GDB to a scratch folder
    temp_extract_path <- file.path(unzip_path, "temp_gdb_extract")
    dir.create(temp_extract_path, showWarnings = FALSE)
    
    unzip(
      zipfile = zip_file,
      files = fgdb_files_to_extract,
      exdir = temp_extract_path # Extract to a temporary folder
      # *** DO NOT USE junkpaths = TRUE HERE! ***
    )
    
    # 2. Identify the unique *.gdb folder that was just extracted (e.g., in temp_extract_path/fgdb)
    extracted_fgdb_root <- file.path(temp_extract_path, "fgdb")
    gdb_folder_name <- list.files(extracted_fgdb_root, pattern = "\\.gdb$", full.names = FALSE)
    
    if (length(gdb_folder_name) == 1) {
      # 3. Move the unique GDB folder to the final destination
      source_gdb_path <- file.path(extracted_fgdb_root, gdb_folder_name)
      destination_gdb_path <- file.path(fgdb_destination_path, gdb_folder_name)
      
      file.rename(from = source_gdb_path, to = destination_gdb_path)
      cat(sprintf("  -> Extracted and moved GDB: %s\n", gdb_folder_name))
      
    } else {
       cat("  -> Warning: Could not find unique *.gdb folder to move.\n")
    }
    
    # 4. Clean up the temporary directory
    unlink(temp_extract_path, recursive = TRUE)
    
  } else {
    cat("  -> No 'fgdb' folder/files found for extraction.\n")
  }

  # C. Extract SHP files (Flatten structure!)
  shp_files_to_extract <- grep("^shp/", internal_files, value = TRUE)
  
  if (length(shp_files_to_extract) > 0) {
    unzip(
      zipfile = zip_file,
      files = shp_files_to_extract, 
      exdir = shp_destination_path, 
      junkpaths = TRUE # Use junkpaths=TRUE to flatten 'shp/' contents
    )
    cat(sprintf("  -> Extracted %d SHP files to %s\n", length(shp_files_to_extract), basename(shp_destination_path)))
  } else {
    cat("  -> No 'shp' folder/files found for extraction.\n")
  }
  
  return(TRUE)
})
```


    Processing: stratmap19-landparcels_48001_lp.zip 
      -> Extracted and moved GDB: stratmap19-landparcels_48001_anderson.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap19-landparcels_48003_lp.zip 
      -> Extracted and moved GDB: stratmap19-landparcels_48003_andrews.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap19-landparcels_48005_lp.zip 
      -> Extracted and moved GDB: stratmap19-landparcels_48005_angelina.gdb
      -> Extracted 11 SHP files to shp

    Processing: stratmap19-landparcels_48007_lp.zip 
      -> Extracted and moved GDB: stratmap19-landparcels_48007_aransas.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap19-landparcels_48009_lp.zip 
      -> Extracted and moved GDB: stratmap19-landparcels_48009_archer.gdb
      -> Extracted 11 SHP files to shp

    Processing: stratmap22-landparcels_48001_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48001_anderson_202201.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48003_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48003_andrews_202202_.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48005_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48005_angelina_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48007_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48007_aransas_202201.gdb
      -> No 'shp' folder/files found for extraction.

    Processing: stratmap22-landparcels_48011_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48011_armstrong_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48015_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48015_austin_202201.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48017_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48017_bailey_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48019_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48019_bandera_202201.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48021_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48021_bastrop_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48025_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48025_bee_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48027_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48027_bell_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48029_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48029_bexar_202201.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48031_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48031_blanco_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48033_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48033_borden_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48035_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48035_bosque_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48037_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48037_bowie_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48039_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48039_brazoria_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48041_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48041_brazos_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48043_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48043_brewster_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48045_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48045_briscoe_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48047_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48047_brooks_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48049_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48049_brown_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48051_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48051_burleson_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48053_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48053_burnet_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48057_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48057_calhoun_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48059_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48059_callahan_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48061_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48061_cameron_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48063_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48063_camp_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48065_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48065_carson_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48067_lp.zip 
      -> Warning: Could not find unique *.gdb folder to move.
      -> Extracted 20 SHP files to shp

    Processing: stratmap22-landparcels_48069_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48069_castro_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48071_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48071_chambers_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48073_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48073_cherokee_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48075_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48075_childress_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48077_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48077_clay_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48081_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48081_coke_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48085_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48085_collin_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48087_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48087_collingsworth_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48089_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48089_colorado_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48091_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48091_comal_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48093_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48093_comanche_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48095_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48095_concho_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48097_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48097_cooke_202201.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48099_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48099_coryell_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48101_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48101_cottle_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48103_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48103_crane_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48105_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48105_crockett_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48109_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48109_culberson_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48111_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48111_dallam_202206.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48113_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48113_dallas_202202.gdb
      -> No 'shp' folder/files found for extraction.

    Processing: stratmap22-landparcels_48115_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48115_dawson_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48117_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48117_deafsmith_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48119_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48119_delta_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48121_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48121_denton_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48123_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48123_dewitt_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48125_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48125_dickens_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48127_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48127_dimmit_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48131_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48131_duval_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48133_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48133_eastland_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48135_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48135_ector_202201.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48137_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48137_edwards_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48139_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48139_ellis_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48141_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48141_elpaso_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48143_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48143_erath_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48145_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48145_falls_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48147_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48147_fannin_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48149_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48149_fayette_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48151_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48151_fisher_202206.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48153_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48153_floyd_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48155_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48155_foard_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48157_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48157_fortbend_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48159_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48159_franklin_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48161_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48161_freestone_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48163_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48163_frio_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48165_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48165_gaines_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48167_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48167_galveston_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48169_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48169_garza_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48171_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48171_gillespie_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48173_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48173_glasscock_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48175_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48175_goliad_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48177_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48177_gonzales_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48179_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48179_gray_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48181_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48181_grayson_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48183_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48183_gregg_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48185_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48185_grimes_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48187_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48187_guadalupe_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48189_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48189_hale_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48191_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48191_hall_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48195_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48195_hansford_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48197_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48197_hardeman_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48199_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48199_hardin_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48201_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48201_harris_202201.gdb
      -> Extracted 6 SHP files to shp

    Processing: stratmap22-landparcels_48203_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48203_harrison_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48205_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48205_hartley_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48207_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48207_haskell_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48209_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48209_hays_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48213_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48213_henderson_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48215_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48215_hidalgo_202201.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48217_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48217_hill_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48219_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48219_hockley_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48223_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48223_hopkins_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48225_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48225_houston_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48227_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48227_howard_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48229_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48229_hudspeth_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48231_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48231_hunt_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48233_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48233_hutchinson_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48235_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48235_irion_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48239_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48239_jackson_202206.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48241_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48241_jasper_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48243_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48243_jeffdavis_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48245_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48245_jefferson_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48247_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48247_jimhogg_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48249_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48249_jimwells_202206.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48251_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48251_johnson_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48253_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48253_jones_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48255_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48255_karnes_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48257_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48257_kaufman_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48259_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48259_kendall_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48261_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48261_kenedy_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48263_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48263_kent_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48267_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48267_kimble_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48269_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48269_king_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48271_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48271_kinney_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48273_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48273_kleberg_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48275_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48275_knox_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48277_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48277_lamar_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48279_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48279_lamb_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48281_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48281_lampasas_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48283_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48283_lasalle_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48285_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48285_lavaca_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48287_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48287_lee_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48289_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48289_leon_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48291_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48291_liberty_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48293_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48293_limestone_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48295_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48295_lipscomb_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48297_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48297_liveoak_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48299_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48299_llano_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48301_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48301_loving_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48303_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48303_lubbock_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48305_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48305_lynn_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48307_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48307_mcculloch_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48311_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48311_mcmullen_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48313_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48313_madison_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48315_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48315_marion_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48317_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48317_martin_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48319_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48319_mason_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48321_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48321_matagorda_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48325_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48325_medina_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48327_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48327_menard_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48329_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48329_midland_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48331_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48331_milam_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48333_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48333_mills_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48335_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48335_mitchell_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48339_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48339_montgomery_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48341_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48341_moore_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48343_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48343_morris_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48347_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48347_nacogdoches_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48349_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48349_navarro_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48353_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48353_nolan_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48355_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48355_nueces_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48357_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48357_ochiltree_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48361_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48361_orange_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48363_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48363_palopinto_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48365_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48365_panola_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48369_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48369_parmer_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48371_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48371_pecos_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48373_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48373_polk_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48375_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48375_potter_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48377_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48377_presidio_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48379_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48379_rains_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48381_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48381_randall_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48383_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48383_reagan_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48385_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48385_real_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48387_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48387_redriver_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48389_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48389_reeves_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48391_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48391_refugio_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48393_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48393_roberts_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48395_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48395_robertson_202206.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48397_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48397_rockwall_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48399_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48399_runnels_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48401_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48401_rusk_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48403_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48403_sabine_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48405_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48405_sanaugustine_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48407_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48407_sanjacinto_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48409_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48409_sanpatricio_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48411_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48411_sansaba_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48413_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48413_schleicher_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48415_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48415_scurry_202206.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48417_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48417_shackelford_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48419_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48419_shelby_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48421_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48421_sherman_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48425_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48425_somervell_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48427_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48427_starr_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48429_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48429_stephens_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48431_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48431_sterling_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48433_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48433_stonewall_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48435_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48435_sutton_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48437_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48437_swisher_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48439_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48439_tarrant_202204.gdb
      -> No 'shp' folder/files found for extraction.

    Processing: stratmap22-landparcels_48443_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48443_terrell_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48447_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48447_throckmorton_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48449_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48449_titus_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48451_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48451_tomgreen_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48455_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48455_trinity_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48457_lp.zip 
      -> No 'fgdb' folder/files found for extraction.
      -> No 'shp' folder/files found for extraction.

    Processing: stratmap22-landparcels_48459_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48459_upshur_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48461_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48461_upton_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48463_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48463_uvalde_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48465_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48465_valverde_202203.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48467_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48467_vanzandt_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48469_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48469_victoria_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48471_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48471_walker_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48473_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48473_waller_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48475_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48475_ward_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48477_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48477_washington_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48479_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48479_webb_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48481_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48481_wharton_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48483_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48483_wheeler_202204.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48485_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48485_wichita_202205.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48487_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48487_wilbarger_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48489_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48489_willacy_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48491_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48491_williamson_202201.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48493_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48493_wilson_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48495_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48495_winkler_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48497_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48497_wise_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48499_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48499_wood_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48501_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48501_yoakum_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48503_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48503_young_202202.gdb
      -> Extracted 9 SHP files to shp

    Processing: stratmap22-landparcels_48505_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48505_zapata_202202.gdb
      -> Extracted 10 SHP files to shp

    Processing: stratmap22-landparcels_48507_lp.zip 
      -> Extracted and moved GDB: stratmap22-landparcels_48507_zavala_202202.gdb
      -> Extracted 10 SHP files to shp

    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap19-landparcels_48001_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap19-landparcels_48003_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap19-landparcels_48005_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap19-landparcels_48007_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap19-landparcels_48009_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48001_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48003_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48005_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48007_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48011_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48015_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48017_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48019_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48021_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48025_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48027_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48029_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48031_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48033_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48035_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48037_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48039_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48041_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48043_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48045_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48047_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48049_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48051_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48053_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48057_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48059_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48061_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48063_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48065_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48067_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48069_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48071_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48073_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48075_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48077_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48081_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48085_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48087_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48089_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48091_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48093_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48095_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48097_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48099_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48101_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48103_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48105_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48109_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48111_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48113_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48115_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48117_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48119_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48121_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48123_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48125_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48127_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48131_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48133_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48135_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48137_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48139_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48141_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48143_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48145_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48147_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48149_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48151_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48153_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48155_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48157_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48159_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48161_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48163_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48165_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48167_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48169_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48171_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48173_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48175_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48177_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48179_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48181_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48183_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48185_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48187_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48189_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48191_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48195_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48197_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48199_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48201_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48203_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48205_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48207_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48209_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48213_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48215_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48217_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48219_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48223_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48225_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48227_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48229_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48231_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48233_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48235_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48239_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48241_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48243_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48245_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48247_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48249_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48251_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48253_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48255_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48257_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48259_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48261_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48263_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48267_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48269_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48271_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48273_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48275_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48277_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48279_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48281_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48283_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48285_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48287_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48289_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48291_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48293_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48295_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48297_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48299_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48301_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48303_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48305_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48307_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48311_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48313_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48315_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48317_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48319_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48321_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48325_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48327_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48329_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48331_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48333_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48335_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48339_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48341_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48343_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48347_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48349_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48353_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48355_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48357_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48361_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48363_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48365_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48369_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48371_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48373_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48375_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48377_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48379_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48381_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48383_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48385_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48387_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48389_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48391_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48393_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48395_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48397_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48399_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48401_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48403_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48405_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48407_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48409_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48411_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48413_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48415_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48417_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48419_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48421_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48425_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48427_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48429_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48431_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48433_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48435_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48437_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48439_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48443_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48447_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48449_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48451_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48455_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48457_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48459_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48461_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48463_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48465_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48467_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48469_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48471_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48473_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48475_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48477_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48479_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48481_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48483_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48485_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48487_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48489_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48491_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48493_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48495_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48497_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48499_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48501_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48503_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48505_lp.zip 
                                                                                TRUE 
    C:/Users/mike.proctor/__R__/Utilities/zipped/stratmap22-landparcels_48507_lp.zip 
                                                                                TRUE 

``` r
toc()
```

    150.5 sec elapsed

``` r
beep(sound = 4)

# 235 files - 145.28 sec
```
