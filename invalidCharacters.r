
source("Setup.R")

# 1. Read the file lines
file_lines <- readLines("path/to/your/file.txt", warn = FALSE)

file_lines <- readLines(here("Maplamina_Views.R"), warn = FALSE)




# 2. Test conversion to UTF-8. Invalid characters turn into NA.
invalid_lines <- which(is.na(iconv(file_lines, from = "UTF-8", to = "UTF-8")))

# 3. View results
if (length(invalid_lines) > 0) {
  cat("Non-UTF-8 characters found on lines:\n", invalid_lines)
  # Print the problematic lines to inspect them
  print(file_lines[invalid_lines])
} else {
  cat("All lines are valid UTF-8.")
}




