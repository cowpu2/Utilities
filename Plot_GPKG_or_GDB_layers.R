
source("Setup.R")

#oldDB_path <- "C:/Users/mike.proctor/GIS/Ft_Irwin_CR_EDA/Old Databases/"




# convert windows path
gsub("\\\\", "/", readClipboard())

#source_path <- "C:/Users/mike.proctor/GIS/source_data/PADUS4_1_State_TX_GDB_KMZ/"
source_path <- "C:/Users/mike.proctor/GIS/Ft_Irwin_CR_EDA/Old Databases/"

st_layers(paste0(source_path, "FY24_GIS1.gdb"))

# Define the path to your GeoPackage or Geodatabase file
#file_path <- "path/to/your/file.gpkg"  # or "path/to/your/file.gdb"
#file_path <- paste0(source_path, "FY_24_Old_qgis_batch_issues.gpkg")
file_path <- paste0(source_path, "FY24_GIS1.gdb")
file_path <- paste0(source_path, "FY24_GIS.gdb")
file_path <- paste0(oldDB_path, "FY24_GIS1.gdb")

# Define target CRS (change as needed)
# Using WGS84 (EPSG:4326) as default, or use EPSG:3857 for Web Mercator
target_crs <- 32611
#target_crs <- 4326


# Extract filename without extension
file_name <- tools::file_path_sans_ext(basename(file_path))

# Determine file type
file_ext <- tools::file_ext(file_path)
if (file_ext == "") {
# Check if it's a .gdb directory
if (grepl("\\.gdb$", file_path)) {
file_ext <- "gdb"
file_name <- sub("\\.gdb$", "", basename(file_path))
}
}



print(paste("Reading from:", file_ext, "format"))

# List all layers in the file
layers <- st_layers(file_path)
layer_names <- layers$name

print(paste("Found", length(layer_names), "layers:"))
print(layer_names)


# Read all layers and transform to same CRS
layer_list <- list()

for (layer_name in layer_names) {
tryCatch({
# Read layer
layer_data <- st_read(file_path, layer = layer_name, quiet = TRUE)

# Check if this is actually an sf object (has geometry)
if (!inherits(layer_data, "sf")) {
print(paste("Warning: Layer", layer_name, "is not a spatial layer (no geometry). Skipping..."))
next
}

# Check if layer has any features
if (nrow(layer_data) == 0) {
print(paste("Warning: Layer", layer_name, "is empty. Skipping..."))
next
}

    # Check if layer has valid geometries
    if (all(st_is_empty(layer_data))) {
      print(paste("Warning: Layer", layer_name, "has no valid geometries. Skipping..."))
      next
    }

    # Print layer info for debugging
    print(paste("Layer:", layer_name, "- Rows:", nrow(layer_data),
                "- Geometry type:", paste(unique(st_geometry_type(layer_data)), collapse = ", ")))

    # Transform to target CRS
    layer_data_transformed <- st_transform(layer_data, crs = target_crs)

    # Add layer name as attribute for plotting
    layer_data_transformed$layer_name <- layer_name

    # Store in list
    layer_list[[layer_name]] <- layer_data_transformed

    print(paste("Processed layer:", layer_name))

  }, error = function(e) {
    print(paste("Error reading layer", layer_name, ":", e$message, ". Skipping..."))
  })
}

# Check if we have any valid layers
if (length(layer_list) == 0) {
  stop("No valid spatial layers found in the file!")
}

print(paste("\nSuccessfully loaded", length(layer_list), "spatial layers"))

# Create directory for individual layer plots
dir.create("layer_plots", showWarnings = FALSE)

# Plot and save each layer individually
for (layer_name in names(layer_list)) {
  layer_data <- layer_list[[layer_name]]

  tryCatch({
    # Create individual plot
    individual_plot <- ggplot() +
      geom_sf(data = layer_data,
              aes(fill = layer_name),
              alpha = 0.5,
              show.legend = FALSE) +
      theme_minimal() +
      labs(title = file_name,
           subtitle = layer_name) +
      theme(plot.title = element_text(size = 16, face = "bold"),
            plot.subtitle = element_text(size = 12))

    # Create filename (sanitize layer name for file system)
    safe_layer_name <- gsub("[^A-Za-z0-9_-]", "_", layer_name)
    filename <- paste0("layer_plots/", file_name, "_", safe_layer_name, ".png")

    # Save individual plot
    ggsave(filename, individual_plot, width = 10, height = 8, dpi = 300)

    print(paste("Saved plot:", filename))
  }, error = function(e) {
    print(paste("Error plotting layer", layer_name, ":", e$message))
  })
}

# Create combined plot of all layers
tryCatch({
  plot_obj <- ggplot()

  # Add each layer to the plot with different colors
  for (i in seq_along(layer_list)) {
    layer_data <- layer_list[[i]]

    plot_obj <- plot_obj +
      geom_sf(data = layer_data,
              aes(color = layer_name, fill = layer_name),
              alpha = 0.5)
  }

  # Customize combined plot
  plot_obj <- plot_obj +
    theme_minimal() +
    labs(title = paste("All Layers from", file_name),
         subtitle = paste("CRS: EPSG:", target_crs),
         color = "Layer",
         fill = "Layer") +
    theme(legend.position = "bottom",
          plot.title = element_text(size = 16, face = "bold"),
          plot.subtitle = element_text(size = 12))

  # Display combined plot
  print(plot_obj)

  # Save combined plot
  ggsave(paste0(file_name, "_all_layers.png"), plot_obj, width = 12, height = 8, dpi = 300)

  print(paste("\nAll done! Individual plots saved to 'layer_plots/' directory"))
  print(paste("Combined plot saved as '", file_name, "_all_layers.png'", sep = ""))

}, error = function(e) {
  print(paste("Error creating combined plot:", e$message))
})



# Layers that didn't print -  geometry type is likely to be multisurface
print(paste("Layer:", layer_name, "- Rows:", nrow(layer_data),
            "- Geometry type:", unique(st_geometry_type(layer_data))))




