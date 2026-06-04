# Script to read geoparquet files and save each as its own data frame
# Author: Mike Proctor
# Date: 2026-04-27
# 
# Note: Uses arrow::read_parquet() + sf::st_as_sf() approach to avoid 
# GDAL DuckDB driver dependency issues (missing duckdb.dll)

library(sf)
library(arrow)
library(dplyr)

#' Read Geoparquet Files from Folder
#'
#' This function reads all geoparquet files from a specified folder and 
#' saves each as an individual sf data frame in the global environment
#'
#' @param folder_path Character. Path to folder containing geoparquet files
#' @param save_as Character. Either "environment" to save to global environment,
#'                or "rds" to save as individual RDS files
#' @param output_folder Character. If save_as = "rds", path to output folder
#' @param geometry_col Character. If specified, forces use of this column as geometry.
#'                     Common names: "geometry", "geom", "Shape", "wkb_geometry"
#' @param verbose Logical. Print detailed diagnostic information
#' @return Invisible list of data frame names
#' @examples
#' read_geoparquet_files("./source_data")
#' read_geoparquet_files("./source_data", save_as = "rds", output_folder = "./output")
#' read_geoparquet_files("./source_data", geometry_col = "Shape")


folder_path <- "C:/Users/mike.proctor/__R__/Ft_Irwin_CR/spatial/NewDB/identical_parquet"


read_geoparquet_files <- function(folder_path, 
                                   save_as = "environment",
                                   output_folder = NULL,
                                   geometry_col = NULL,
                                   verbose = FALSE) {
  
  # Check if folder exists
  if (!dir.exists(folder_path)) {
    stop("Folder does not exist: ", folder_path)
  }
  
  # Get list of geoparquet files
  geoparquet_files <- list.files(
    path = folder_path,
    pattern = "\\.parquet$|\\.geoparquet$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  
  # Check if any files found
  if (length(geoparquet_files) == 0) {
    warning("No geoparquet files found in: ", folder_path)
    return(invisible(NULL))
  }
  
  message("Found ", length(geoparquet_files), " geoparquet file(s)")
  
  # Create output folder if saving as RDS
  if (save_as == "rds" && !is.null(output_folder)) {
    if (!dir.exists(output_folder)) {
      dir.create(output_folder, recursive = TRUE)
      message("Created output folder: ", output_folder)
    }
  }
  
  # Read each file and save
  df_names <- character(length(geoparquet_files))
  
  for (i in seq_along(geoparquet_files)) {
    file_path <- geoparquet_files[i]
    file_name <- tools::file_path_sans_ext(basename(file_path))
    
    # Clean name for R variable (remove special characters)
    clean_name <- gsub("[^[:alnum:]_]", "_", file_name)
    
    message("Reading: ", basename(file_path))
    
    # Read geoparquet file using arrow + sf approach
    tryCatch({
      # Read the parquet file first
      arrow_df <- arrow::read_parquet(file_path)
      
      if (verbose) {
        message("  Columns found: ", paste(names(arrow_df), collapse = ", "))
      }
      
      # Determine geometry column
      geom_col_name <- geometry_col  # Use user-specified if provided
      
      # If not user-specified, try to detect from metadata
      if (is.null(geom_col_name)) {
        meta <- try(arrow::read_parquet(file_path, as_data_frame = FALSE), silent = TRUE)
        
        if (!inherits(meta, "try-error")) {
          # Try to get schema metadata
          schema_meta <- meta$schema$metadata
          
          if (!is.null(schema_meta$geo)) {
            # Parse geo metadata (it's JSON)
            geo_json <- schema_meta$geo
            if (verbose) message("  Found geo metadata: ", substr(geo_json, 1, 100), "...")
            
            # Extract primary_column from JSON
            # Simple regex approach to avoid jsonlite dependency
            primary_match <- regmatches(geo_json, regexpr('"primary_column"\\s*:\\s*"([^"]+)"', geo_json, perl = TRUE))
            if (length(primary_match) > 0) {
              geom_col_name <- gsub('"primary_column"\\s*:\\s*"([^"]+)"', "\\1", primary_match, perl = TRUE)
              if (verbose) message("  Detected geometry column from metadata: ", geom_col_name)
            }
          }
        }
      }
      
      # If still not found, try common geometry column names
      if (is.null(geom_col_name)) {
        common_geom_names <- c("geometry", "geom", "Shape", "SHAPE", "wkb_geometry", 
                               "wkt_geometry", "the_geom", "geom_wkb")
        
        for (name in common_geom_names) {
          if (name %in% names(arrow_df)) {
            geom_col_name <- name
            if (verbose) message("  Found common geometry column: ", geom_col_name)
            break
          }
        }
      }
      
      # Now attempt to convert to sf object
      if (!is.null(geom_col_name) && geom_col_name %in% names(arrow_df)) {
        
        # Check the type of geometry data
        geom_sample <- arrow_df[[geom_col_name]][1]
        
        if (verbose) {
          message("  Geometry column type: ", class(geom_sample)[1])
        }
        
        # Try to convert to sf
        df <- tryCatch({
          # First try as WKB (most common for geoparquet)
          sf::st_as_sf(arrow_df, wkb = geom_col_name)
        }, error = function(e1) {
          # If WKB fails, try WKT
          tryCatch({
            if (verbose) message("  WKB conversion failed, trying WKT...")
            sf::st_as_sf(arrow_df, wkt = geom_col_name)
          }, error = function(e2) {
            # If both fail, check if it's already in binary format that needs decoding
            if (verbose) {
              message("  Direct conversion failed. Error: ", e1$message)
              message("  Trying manual WKB decoding...")
            }
            
            # Try manual WKB decoding
            tryCatch({
              # Convert the column to raw if needed
              geom_data <- arrow_df[[geom_col_name]]
              
              # If it's a list of raw vectors, convert directly
              if (is.list(geom_data) && all(sapply(geom_data[1:min(10, length(geom_data))], is.raw))) {
                geoms <- sf::st_as_sfc(geom_data, EWKB = FALSE)
                arrow_df[[geom_col_name]] <- geoms
                sf::st_as_sf(arrow_df)
              } else {
                stop("Could not determine geometry format")
              }
            }, error = function(e3) {
              warning("Could not convert geometry column. Returning as regular data.frame")
              as.data.frame(arrow_df)
            })
          })
        })
        
        if (inherits(df, "sf")) {
          message("  -> Successfully converted to sf object")
        } else {
          message("  -> Converted to regular data.frame (geometry conversion failed)")
        }
        
      } else {
        # No geometry column found or specified
        if (is.null(geom_col_name)) {
          warning(paste0("No geometry column detected in ", basename(file_path), 
                        ". Reading as regular data.frame."))
        } else {
          warning(paste0("Specified geometry column '", geom_col_name, 
                        "' not found in ", basename(file_path), 
                        ". Reading as regular data.frame."))
        }
        df <- as.data.frame(arrow_df)
      }
      
      if (save_as == "environment") {
        # Save to global environment
        assign(clean_name, df, envir = .GlobalEnv)
        message("  -> Saved as: ", clean_name, " (", nrow(df), " rows, ", 
                ncol(df), " columns)")
      } else if (save_as == "rds") {
        # Save as RDS file
        output_path <- file.path(output_folder, paste0(clean_name, ".rds"))
        saveRDS(df, output_path)
        message("  -> Saved to: ", output_path, " (", nrow(df), " rows)")
      }
      
      df_names[i] <- clean_name
      
    }, error = function(e) {
      warning("Error reading ", basename(file_path), ": ", e$message)
      df_names[i] <- NA
    })
  }
  
  # Remove any NA values from failed reads
  df_names <- df_names[!is.na(df_names)]
  
  message("\nComplete! Processed ", length(df_names), " file(s) successfully")
  
  if (save_as == "environment") {
    message("Data frames available in global environment: ", 
            paste(df_names, collapse = ", "))
  }
  
  invisible(df_names)
}


#' Diagnose Geoparquet File
#' 
#' Provides detailed diagnostic information about a geoparquet file
#' to help troubleshoot geometry reading issues
#' 
#' @param file_path Character. Path to the geoparquet file
#' @return Invisible list with diagnostic information
#' @examples
#' diagnose_geoparquet("./source_data/myfile.parquet")

diagnose_geoparquet <- function(file_path) {
  
  if (!file.exists(file_path)) {
    stop("File does not exist: ", file_path)
  }
  
  cat("\n=== GEOPARQUET DIAGNOSTIC REPORT ===\n")
  cat("File:", basename(file_path), "\n\n")
  
  # Read with arrow
  cat("1. Reading file with arrow::read_parquet()...\n")
  arrow_df <- arrow::read_parquet(file_path)
  
  cat("   Rows:", nrow(arrow_df), "\n")
  cat("   Columns:", ncol(arrow_df), "\n")
  cat("   Column names:", paste(names(arrow_df), collapse = ", "), "\n\n")
  
  # Check metadata
  cat("2. Checking geoparquet metadata...\n")
  meta_table <- try(arrow::read_parquet(file_path, as_data_frame = FALSE), silent = TRUE)
  
  if (!inherits(meta_table, "try-error")) {
    schema_meta <- meta_table$schema$metadata
    
    if (!is.null(schema_meta$geo)) {
      cat("   ✓ Found 'geo' metadata\n")
      geo_json <- schema_meta$geo
      cat("   Metadata preview:", substr(geo_json, 1, 200), "...\n\n")
      
      # Try to extract primary column
      primary_match <- regmatches(geo_json, regexpr('"primary_column"\\s*:\\s*"([^"]+)"', geo_json, perl = TRUE))
      if (length(primary_match) > 0) {
        primary_col <- gsub('"primary_column"\\s*:\\s*"([^"]+)"', "\\1", primary_match, perl = TRUE)
        cat("   Primary geometry column:", primary_col, "\n\n")
      }
    } else {
      cat("   ✗ No 'geo' metadata found\n\n")
    }
  } else {
    cat("   ✗ Could not read metadata\n\n")
  }
  
  # Look for potential geometry columns
  cat("3. Searching for potential geometry columns...\n")
  common_geom_names <- c("geometry", "geom", "Shape", "SHAPE", "wkb_geometry", 
                         "wkt_geometry", "the_geom", "geom_wkb")
  
  found_geom_cols <- intersect(names(arrow_df), common_geom_names)
  
  if (length(found_geom_cols) > 0) {
    cat("   ✓ Found potential geometry columns:", paste(found_geom_cols, collapse = ", "), "\n\n")
    
    for (col_name in found_geom_cols) {
      cat("   Analyzing column:", col_name, "\n")
      sample_val <- arrow_df[[col_name]][1]
      cat("     Type:", class(sample_val)[1], "\n")
      
      if (is.raw(sample_val)) {
        cat("     Format: Raw/Binary (likely WKB)\n")
        cat("     Size:", length(sample_val), "bytes\n")
      } else if (is.character(sample_val)) {
        cat("     Format: Character string\n")
        cat("     Length:", nchar(sample_val), "characters\n")
        cat("     Preview:", substr(sample_val, 1, 60), "...\n")
      } else if (is.list(sample_val) && is.raw(sample_val[[1]])) {
        cat("     Format: List of raw vectors (WKB)\n")
      }
      
      # Try conversion
      cat("     Testing conversions:\n")
      
      # Try WKB
      wkb_result <- try(sf::st_as_sf(arrow_df, wkb = col_name), silent = TRUE)
      if (!inherits(wkb_result, "try-error")) {
        cat("       ✓ WKB conversion: SUCCESS\n")
        cat("       Geometry type:", unique(sf::st_geometry_type(wkb_result))[1], "\n")
        cat("       CRS:", sf::st_crs(wkb_result)$input, "\n")
      } else {
        cat("       ✗ WKB conversion: FAILED -", wkb_result[1], "\n")
      }
      
      # Try WKT
      wkt_result <- try(sf::st_as_sf(arrow_df, wkt = col_name), silent = TRUE)
      if (!inherits(wkt_result, "try-error")) {
        cat("       ✓ WKT conversion: SUCCESS\n")
      } else {
        cat("       ✗ WKT conversion: FAILED\n")
      }
      
      cat("\n")
    }
  } else {
    cat("   ✗ No common geometry column names found\n")
    cat("   Available columns:", paste(names(arrow_df), collapse = ", "), "\n\n")
  }
  
  cat("=== END DIAGNOSTIC REPORT ===\n\n")
  
  invisible(list(
    arrow_df = arrow_df,
    columns = names(arrow_df),
    potential_geom_cols = found_geom_cols
  ))
}


# ===== USAGE EXAMPLES =====

# Example 1: Read all geoparquet files and save to global environment
# read_geoparquet_files("./source_data")

# Example 2: Read and save as individual RDS files
# read_geoparquet_files("./source_data", save_as = "rds", output_folder = "./output")

# Example 3: Specify custom folder path with verbose output
# read_geoparquet_files("C:/path/to/geoparquet/files", verbose = TRUE)

# Example 4: Force a specific geometry column (useful for ESRI Shape fields)
# read_geoparquet_files("./source_data", geometry_col = "Shape")

# Example 5: Diagnose a problematic file
# diagnose_geoparquet(paste0(folder_path, "/01_FY24_GIS__FY24_091_APE.parquet"))

# Run with current folder
read_geoparquet_files(folder_path)
