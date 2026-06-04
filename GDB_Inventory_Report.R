# GDB Inventory Report Generator
# Scans folder (recursively) for geodatabases and generates detailed feature counts



source("Setup.R")



# ---- CONFIGURATION ----
# Set your target folder path here
folder_path <- "C:/Users/mike.proctor/GIS/Ft_Irwin_CR_EDA/"  # Change this to your target folder

# ---- FUNCTIONS ----

#' Get GDB inventory for a single geodatabase
#'
#' @param gdb_path Path to .gdb folder
#' @return tibble with layer details or NULL if error
get_gdb_inventory <- function(gdb_path) {
  gdb_name <- basename(gdb_path)
  
  tryCatch({
    # Normalize path to handle Windows path issues
    gdb_path_norm <- normalizePath(gdb_path, winslash = "/", mustWork = FALSE)
    
    # GDAL will automatically select the appropriate driver (OpenFileGDB or FileGDB)
    layer_info <- st_layers(gdb_path_norm)
    
    # If empty GDB
    if (length(layer_info$name) == 0) {
      return(tibble(
        gdb_name = gdb_name,
        gdb_path = gdb_path,
        layer_name = NA_character_,
        geom_type = NA_character_,
        feature_count = 0L,
        status = "Empty GDB"
      ))
    }
    
    # Build detail tibble
    tibble(
      gdb_name = gdb_name,
      gdb_path = gdb_path,
      layer_name = layer_info$name,
      geom_type = as.character(layer_info$geomtype),
      feature_count = layer_info$features,
      status = "OK"
    )
    
  }, error = function(e) {
    # Handle corrupted or inaccessible GDBs
    tibble(
      gdb_name = gdb_name,
      gdb_path = gdb_path,
      layer_name = NA_character_,
      geom_type = NA_character_,
      feature_count = 0L,
      status = paste("ERROR:", e$message)
    )
  })
}


#' Find all .gdb folders recursively
#'
#' @param root_path Root directory to search
#' @return character vector of .gdb paths
find_gdbs <- function(root_path) {
  # List all directories recursively
  all_dirs <- list.dirs(root_path, recursive = TRUE, full.names = TRUE)
  
  # Filter for .gdb extensions
  gdb_dirs <- all_dirs[str_detect(all_dirs, "\\.gdb$")]
  
  return(gdb_dirs)
}


#' Generate and display inventory report
#'
#' @param folder_path Root folder to scan
generate_gdb_report <- function(folder_path) {
  
  cat("\n===========================================\n")
  cat("   GDB INVENTORY REPORT\n")
  cat("===========================================\n")
  cat("Scanning folder:", folder_path, "\n")
  cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
  
  # Find all GDBs
  cat("Searching for geodatabases (recursive)...\n")
  gdb_paths <- find_gdbs(folder_path)
  
  if (length(gdb_paths) == 0) {
    cat("No geodatabases found in:", folder_path, "\n")
    return(invisible(NULL))
  }
  
  cat("Found", length(gdb_paths), "geodatabase(s)\n\n")
  
  # Process each GDB
  cat("Processing geodatabases...\n")
  inventory_list <- map(gdb_paths, get_gdb_inventory)
  
  # Combine into single tibble
  inventory_full <- bind_rows(inventory_list)
  
  # ---- SUMMARY CALCULATIONS ----
  
  # Per-GDB summary
  gdb_summary <- inventory_full |>
    group_by(gdb_name, gdb_path, status) |>
    summarise(
      layer_count = sum(!is.na(layer_name)),
      total_features = sum(feature_count, na.rm = TRUE),
      .groups = "drop"
    ) |>
    arrange(gdb_name)
  
  # Overall totals
  total_gdbs <- n_distinct(inventory_full$gdb_name)
  total_layers <- sum(!is.na(inventory_full$layer_name))
  total_features <- sum(inventory_full$feature_count, na.rm = TRUE)
  
  # ---- CONSOLE OUTPUT ----
  
  cat("\n===========================================\n")
  cat("   PER-GEODATABASE SUMMARY\n")
  cat("===========================================\n\n")
  
  for (i in seq_len(nrow(gdb_summary))) {
    row <- gdb_summary[i, ]
    cat(sprintf("[%d] %s\n", i, row$gdb_name))
    cat(sprintf("    Path: %s\n", row$gdb_path))
    cat(sprintf("    Layers: %d\n", row$layer_count))
    cat(sprintf("    Features: %s\n", format(row$total_features, big.mark = ",")))
    cat(sprintf("    Status: %s\n", row$status))
    cat("\n")
  }
  
  cat("===========================================\n")
  cat("   LAYER DETAILS\n")
  cat("===========================================\n\n")
  
  # Print layer details grouped by GDB
  for (gdb in unique(inventory_full$gdb_name)) {
    cat(sprintf(">>> %s\n", gdb))
    
    layers <- inventory_full |>
      filter(gdb_name == !!gdb, !is.na(layer_name)) |>
      select(layer_name, geom_type, feature_count)
    
    if (nrow(layers) > 0) {
      for (j in seq_len(nrow(layers))) {
        cat(sprintf("    • %s [%s] - %s features\n", 
                    layers$layer_name[j],
                    layers$geom_type[j],
                    format(layers$feature_count[j], big.mark = ",")))
      }
    } else {
      cat("    (No layers)\n")
    }
    cat("\n")
  }
  
  cat("===========================================\n")
  cat("   FOLDER TOTALS\n")
  cat("===========================================\n")
  cat(sprintf("Total Geodatabases: %d\n", total_gdbs))
  cat(sprintf("Total Layers: %d\n", total_layers))
  cat(sprintf("Total Features: %s\n", format(total_features, big.mark = ",")))
  cat("===========================================\n\n")
  
  # ---- CSV EXPORT ----
  
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Export detailed inventory
  detail_file <- paste0(csv_path,"/gdb_inventory_detail_", timestamp, ".csv")
  write.csv(inventory_full, detail_file, row.names = FALSE)
  cat("Detailed inventory saved to:", detail_file, "\n")
  
  # Export GDB summary
  summary_file <- paste0(csv_path, "/gdb_inventory_summary_", timestamp, ".csv")
  write.csv(gdb_summary, summary_file, row.names = FALSE)
  cat("GDB summary saved to:", summary_file, "\n")
  
  # Export folder totals
  totals_df <- tibble(
    folder_path = folder_path,
    scan_timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    total_geodatabases = total_gdbs,
    total_layers = total_layers,
    total_features = total_features
  )
  totals_file <- paste0(csv_path,"/gdb_inventory_totals_", timestamp, ".csv")
  write.csv(totals_df, totals_file, row.names = FALSE)
  cat("Folder totals saved to:", totals_file, "\n\n")
  
  cat("Report generation complete!\n")
  
  # Return invisibly for further analysis if needed
  invisible(list(
    inventory = inventory_full,
    gdb_summary = gdb_summary,
    totals = totals_df
  ))
}

# ---- EXECUTE ----
# Run the report generator
result <- generate_gdb_report(folder_path)
