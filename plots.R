
## ===============Test OneDrive connection ===========================
##
## CodeMonkey:  Mike Proctor
## ======================================================================

source("Setup.R")
library(purrr)

oldDB_path <- "C:/Users/mike.proctor/GIS/Ft_Irwin_CR_EDA/Old Databases"


fy24_layers <- st_layers(paste0(oldDB_path, "/FY24_GIS.gdb"))

spatial_layers <- fy24_layers$name[!is.na(fy24_layers$geomtype)]



spatial_layers <- spatial_layers[fy24_layers$features[fy24_layers$name %in% spatial_layers] > 0]


twentyFour <- st_read(paste0(oldDB_path, "/FY24_GIS.gdb"))





# 1. Get a list of all layer names in the GDB
layers <- st_layers(paste0(oldDB_path, "/FY24_GIS.gdb"))$name

# 2. Initialize the plot
p <- ggplot()

# 3. Iterate through all layers and add them to the plot
# Note: With 400 layers, this may be slow and visually cluttered.
for (lyr in spatial_layers) {
  data_sf <- st_read(paste0(oldDB_path, "/FY24_GIS.gdb"), layer = lyr, quiet = TRUE)
  p <- p + geom_sf(data = data_sf, inherit.aes = FALSE)


  if (nrow(data_sf) > 0) {
    ggsave(filename = paste0(plot_path, lyr, ".png"), plot = p, width = 5, height = 4)

  }


}
