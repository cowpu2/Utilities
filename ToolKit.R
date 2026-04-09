


# Project setup - creates standard folders for a new project
ifelse(!dir.exists("csv_output"), dir.create("csv_output"), "Folder exists already")
#ifelse(!dir.exists("dat_output"), dir.create("dat_output"), "Folder exists already")
ifelse(!dir.exists("plots"), dir.create("plots"), "Folder exists already")
ifelse(!dir.exists("source_data"), dir.create("source_data"), "Folder exists already")
# ----
# Convert a copied windows path to a 'nix' path - after copying
#path to clipboard just run this line

gsub("\\\\", "/", readClipboard())

# ----