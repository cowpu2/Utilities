

# Check gdb files that weren't reading

source("Setup.R")
source_path  <- "C:/Users/mike.proctor/GIS/Ft_Irwin_CR_EDA/Old Databases/done/"


# List all layers in the GDB
layerList <- st_layers(paste0(source_path, "DigPermits2.gdb"))
layerList <- st_layers(paste0(source_path, "DigPermits2a.gdb"))

layerList <- st_layers(paste0(source_path, "OLM_FY24.gdb"))

# Just reads the layers - doesn't save them
for (i in layerList$name) {
    st_read(paste0(source_path, "OLM_FY24.gdb"), layer = i)
    }




gdb_path <- paste0(source_path, "DigPermits2.gdb")
gdb_path <- paste0(source_path, "DigPermits2a.gdb")
gdb_path <- paste0(source_path, "OLM_FY24.gdb")
gdb_path <- paste0(source_path, "OLM_FY241.gdb")


layers <- st_layers(gdb_path)$name

# Create clean variable names and read data
for (layer in layers) {
  # Clean the layer name for use as variable name
  clean_name <- make.names(layer)
  
  # Read and assign
  assign(clean_name, 
         st_read(gdb_path, layer = layer, quiet = TRUE),
         envir = .GlobalEnv)
  
  cat("Loaded:", layer, "as", clean_name, "\n")
}
