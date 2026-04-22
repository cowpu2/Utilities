# Unzipper_Parallel

Mike Proctor
2025-11-06

This script, utilizing the future and furrr packages for parallel
processing, is designed to efficiently unzip geospatial archives (ZIP
files) from the defined source_path. It performs a selective extraction
based on the internal folder structure of each ZIP: all Shapefiles (SHP)
are flattened and aggregated into a single unzipped/shp folder, while
all File Geodatabases (FGDB) are extracted, and their unique .gdb folder
structure is preserved and moved into the unzipped/fgdb folder,
preventing data overwrites during the large-scale, concurrent
extraction.

Gemini was abused extensively in the composition of these scripts.

There is another version that doesn’t use parallel processing but is not
as fast. 45 secs vs 145 secs for the same files

These were used primarily in working with files of land parcels
downloaded from [TxGIO]<https://data.geographic.texas.gov/> using
their bulk downloader. The zipfiles had shp files of parcels for each
county as well as gdb files for each county and one for the entire
state. The entire state is a little large to work with conviently so I
removed it before unzipping. The destination folder structure is the
complex part of the script. The gdb files for each county have to retain
their name and get put in a fgdb folder. The shape files were easier to
work with - they just ended up in a shp folder.

Script throws an error for each file about “Access is denied” - this is
a coming from windows - it doesn’t seem to cause any problems and
gemini’s fix didn’t work so it isn’t really worth chasing down at the
moment. It complains but still gets it done.

``` r
library(rprojroot)
library(tictoc) # not necessary
library(beepr) # not necessary
library(future)
library(furrr)
library(purrr) # Used implicitly by furrr structure

base_path       <- find_rstudio_root_file()
source_path     <- file.path(base_path, "source_data//")
unzip_path        <- file.path(base_path, "unzipped//")
zip_path        <- file.path(base_path, "zipped//")

# Define the final destination folders for the extracted contents
shp_destination_path <- file.path(unzip_path, "shp")
fgdb_destination_path <- file.path(unzip_path, "fgdb")


# Set the plan for parallel execution
# 'multisession' starts new R sessions for parallel work (works on all OS)
# We use all available cores minus one
plan(multisession, workers = availableCores() - 1) 

cat("Parallel plan set using:", future::nbrOfWorkers(), "cores.\n")
```

## Parallel plan set using: 21 cores

``` r
# Re-run your directory creation to ensure destinations exist
dir.create(shp_destination_path, recursive = TRUE, showWarnings = FALSE)
dir.create(fgdb_destination_path, recursive = TRUE, showWarnings = FALSE)


# --- 3. Define the Function (Cleanly separated) ---

# Wrap your extraction logic into a single function that takes ONE zip file
# This function is identical to the logic in the previous sequential script
unzip_selective_single_file <- function(zip_file) {
  
  # Variables (like fgdb_destination_path) are automatically exported by 'future'
  
  internal_files <- unzip(zip_file, list = TRUE)$Name
  
  # ----------------- A. FGDB Extraction (Preserve folder structure) -----------------
  fgdb_files_to_extract <- grep("^fgdb/", internal_files, value = TRUE)
  
  if (length(fgdb_files_to_extract) > 0) {
    temp_extract_path <- file.path(unzip_path, paste0("temp_gdb_", Sys.getpid()))
    dir.create(temp_extract_path, showWarnings = FALSE)
    
    unzip(
      zipfile = zip_file,
      files = fgdb_files_to_extract,
      exdir = temp_extract_path
    )
    
    extracted_fgdb_root <- file.path(temp_extract_path, "fgdb")
    gdb_folder_name <- list.files(extracted_fgdb_root, pattern = "\\.gdb$", full.names = FALSE)
    
    if (length(gdb_folder_name) == 1) {
      source_gdb_path <- file.path(extracted_fgdb_root, gdb_folder_name)
      destination_gdb_path <- file.path(fgdb_destination_path, gdb_folder_name)
      file.rename(from = source_gdb_path, to = destination_gdb_path)
    }
    
    unlink(temp_extract_path, recursive = TRUE)
  }
  
  # ----------------- B. SHP Extraction (Flatten structure) -----------------
  shp_files_to_extract <- grep("^shp/", internal_files, value = TRUE)
  
  if (length(shp_files_to_extract) > 0) {
    unzip(
      zipfile = zip_file,
      files = shp_files_to_extract, 
      exdir = shp_destination_path, 
      junkpaths = TRUE
    )
  }
  
  return(paste("Successfully processed:", basename(zip_file)))
}
```

``` r
# --- 4. Run the Parallel Map ---
tic()
zip_files <- list.files(
  path = zip_path,
  pattern = "\\.zip$", 
  full.names = TRUE 
)

cat("Starting parallel extraction of", length(zip_files), "files...\n")
```

    Starting parallel extraction of 235 files...

``` r
# Use future_map() to apply the function across all cores simultaneously
results <- future_map_chr(zip_files, unzip_selective_single_file)

# Stop the parallel workers (though plan(multisession) usually handles cleanup)
plan(sequential) 
toc()
```

    88.14 sec elapsed

``` r
beep(sound = 4)

# 235 files - 47.11 sec
```
