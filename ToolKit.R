


# Project setup - creates standard folders for a new project
ifelse(!dir.exists("csv_output"), dir.create("csv_output"), "Folder exists already")
#ifelse(!dir.exists("dat_output"), dir.create("dat_output"), "Folder exists already")
ifelse(!dir.exists("plots"), dir.create("plots"), "Folder exists already")
ifelse(!dir.exists("source_data"), dir.create("source_data"), "Folder exists already")
# ----
# Convert a copied windows path to a 'nix' path - after copying
#path to clipboard just run this line

gsub("\\\\", "/", readClipboard())


# Get folder listing with sizes

# Install fs if you haven't: install.packages("fs")

target_dir <- "C:/Users/mike.proctor/GIS/Ft_Irwin_CR_EDA/NewDatabases/CR_Enterprise_02242026/Archive"
library(fs)
library(dplyr)
library(purrr)

# Get all top-level directories
dirs <- dir_ls(target_dir, type = "directory")

# Function to calculate recursive size
get_folder_size <- function(path) {
  # Get info for all files within this folder, recursively
  files <- dir_info(path, recurse = TRUE, type = "file")
  sum(files$size)
}

# Create the report
report <- tibble(
  folder_path = dirs,
  # Map the function over each directory
  total_size = map_dbl(dirs, get_folder_size) 
) %>%
  # Convert to readable units (MB)
  mutate(size_mb = round(total_size / (1024^2), 2)) %>%
  arrange(desc(size_mb))

print(report)