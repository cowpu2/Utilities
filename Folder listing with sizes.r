# Get folder listing with sizes

 

 Run this after copying path
  gsub("\\\\", "/", readClipboard())

#target_dir <- "C:/Users/mike.proctor/GIS/Ft_Irwin_CR_EDA/NewDatabases/CR_Enterprise_02242026/Archive"
target_dir <- "C:/Users/mike.proctor/__R__/"

library(fs)
library(tidyverse)

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

write_csv(report, "FolderSize.csv")
