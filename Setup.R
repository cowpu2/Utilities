
## ========= Load libraries and paths =================
##
## Utility file
##
##
## CodeMonkey:  Mike Proctor
## ======================================================================


Package_list <- c(
                  "tidyverse"
                  , "rprojroot"
                  , "tidylog"
                  , "sf"
                  )

for (package in Package_list) {
  if (!require(package, character.only = TRUE)) {
    install.packages(package, dependencies = TRUE)
  }

  library(package, character.only = TRUE)
}

rm(list = c("package", "Package_list"))

## Local stuff  =================
base_path       <- find_rstudio_root_file()
source_path     <- file.path(base_path, "source_data//")
#dat_path        <- file.path(base_path, "dat_output//")
plot_path       <- file.path(base_path, "plots//")
csv_path        <- file.path(base_path, "csv_output//")
#spatial_path    <- "X:/Transition/__R__/Spatial/spatial/"



# convert windows path
#gsub("\\\\", "/", readClipboard())
