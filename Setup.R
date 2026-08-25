
## ========= Load libraries and paths =================
##
## Utility file
##
##
## CodeMonkey:  Mike Proctor
## ======================================================================


Package_list <- c(
                  "tidyverse"
                  , "here"
                  , "tidylog"
                  #, "sf"
                  )

for (package in Package_list) {
  if (!require(package, character.only = TRUE)) {
    install.packages(package, dependencies = TRUE)
  }

  library(package, character.only = TRUE)
}

rm(list = c("package", "Package_list"))

## Local stuff  =================
source_path  <- here("source_data")
spatial_path <- here("spatial")
plot_path    <- here("plots")
csv_path     <- here("csv_output")
scipts_path     <- here("scripts")


