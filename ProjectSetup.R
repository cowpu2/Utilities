## ========== Utility to create folders for new projects=================
## File can be deleted after run
## CodeMonkey:  Mike Proctor
## ======================================================================



ifelse(!dir.exists("csv_output"), dir.create("csv_output"), "Folder exists already")
#ifelse(!dir.exists("dat_output"), dir.create("dat_output"), "Folder exists already")
ifelse(!dir.exists("plots"), dir.create("plots"), "Folder exists already")
ifelse(!dir.exists("source_data"), dir.create("source_data"), "Folder exists already")


