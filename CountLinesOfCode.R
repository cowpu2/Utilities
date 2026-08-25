## ==============Count lines of Code ==========================
##
## Counts lines of Code in a folder - includes .R, .RMD, .QMD, and .py
##
##
## CodeMonkey:  Mike Proctor
## ======================================================================



source("Setup.R")

# Set the parent directory you want to search
#parent_dir <- "C:/Users/mike.proctor/__R__"  # Change this to your target directory
#parent_dir <- "C:/Users/mike.proctor/__R__/Ft_Irwin_CR"  # Change this to your target directory
parent_dir <- "C:/Users/mike.proctor/mcps/local_file_catalog" 

## -----------------------------------------------------------------
exclude_list <- c("archive","RAP", "Resume", "Setup", # these aren't projects - don't count these folders
                  "Shiny","Spatial","Utilities", "ZZ_Docs", "__pycache__")
## ----------------------------------------------------------------------


# R Script to Count Lines of Code with Summary by Folder and Total

# ============================================================================
# STEP 1: List all folders and filter
# ============================================================================



# Get all subdirectories
all_folders <- list.dirs(path = parent_dir, full.names = FALSE, recursive = FALSE)

cat("Found", length(all_folders), "folders:\n")
print(all_folders)


folders_to_analyze <- c(
  ".",
  all_folders[!all_folders %in% exclude_list]
)


cat("\nFolders selected for analysis:\n")
print(folders_to_analyze)

# ============================================================================
# STEP 2: Functions to count lines (excluding comments)
# ============================================================================

# Function to clean and count R code lines
count_r_lines <- function(lines) {
  code_lines <- 0

  for (line in lines) {
    trimmed <- trimws(line)
    if (nchar(trimmed) == 0) next
    if (grepl("^#", trimmed)) next

    if (grepl("#", trimmed)) {
      code_part <- sub("#.*$", "", trimmed)
      code_part <- trimws(code_part)
      if (nchar(code_part) > 0) {
        code_lines <- code_lines + 1
      }
    } else {
      code_lines <- code_lines + 1
    }
  }

  return(code_lines)
}

# Function to clean and count Python code lines
count_python_lines <- function(lines) {
  code_lines <- 0
  in_multiline_string <- FALSE
  multiline_delimiter <- ""

  for (line in lines) {
    trimmed <- trimws(line)
    if (nchar(trimmed) == 0) next

    if (grepl('"""', trimmed) || grepl("'''", trimmed)) {
      if (grepl('"""', trimmed)) {
        delimiter <- '"""'
      } else {
        delimiter <- "'''"
      }

      occurrences <- str_count(trimmed, fixed(delimiter))

      if (!in_multiline_string) {
        in_multiline_string <- TRUE
        multiline_delimiter <- delimiter

        if (occurrences >= 2) {
          in_multiline_string <- FALSE
          parts <- strsplit(trimmed, fixed(delimiter))[[1]]
          if (length(parts) > 2 && nchar(trimws(parts[length(parts)])) > 0) {
            code_lines <- code_lines + 1
          }
        }
        next
      } else if (in_multiline_string && grepl(fixed(multiline_delimiter), trimmed)) {
        in_multiline_string <- FALSE
        multiline_delimiter <- ""
        next
      }
    }

    if (in_multiline_string) next
    if (grepl("^#", trimmed)) next

    if (grepl("#", trimmed)) {
      code_part <- sub("#.*$", "", trimmed)
      code_part <- trimws(code_part)
      if (nchar(code_part) > 0) {
        code_lines <- code_lines + 1
      }
    } else {
      code_lines <- code_lines + 1
    }
  }

  return(code_lines)
}

# Main function to count lines in files
count_lines_in_files <- function(folders, extensions, parent_path = ".", language = "R") {
  total_lines <- 0
  total_lines_with_comments <- 0
  file_count <- 0
  details <- data.frame(
    folder = character(),
    file = character(),
    lines_no_comments = integer(),
    lines_with_comments = integer(),
    stringsAsFactors = FALSE
  )

  for (folder in folders) {
    folder_path <- if (folder == ".") parent_path else file.path(parent_path, folder)
    folder_label <- if (folder == ".") "(parent_dir)" else folder

    if (!dir.exists(folder_path)) {
      warning(paste("Folder does not exist:", folder_path))
      next
    }

    pattern <- paste0("\\.(", paste(extensions, collapse = "|"), ")$")
    files <- list.files(
      path = folder_path,
      pattern = pattern,
      recursive = FALSE,
      full.names = TRUE,
      ignore.case = TRUE
    )

    for (file in files) {
      tryCatch({
        #lines <- readLines(file, warn = FALSE, skipNul = TRUE)
        lines <- read_lines(file) # deals with weird characters better


        lines_with_comments <- sum(nchar(trimws(lines)) > 0)

        if (language == "R") {
          lines_no_comments <- count_r_lines(lines)
        } else if (language == "Python") {
          lines_no_comments <- count_python_lines(lines)
        } else {
          lines_no_comments <- lines_with_comments
        }

        total_lines <- total_lines + lines_no_comments
        total_lines_with_comments <- total_lines_with_comments + lines_with_comments
        file_count <- file_count + 1

        details <- rbind(details, data.frame(
          folder = folder_label,
          file = basename(file),
          lines_no_comments = lines_no_comments,
          lines_with_comments = lines_with_comments,
          stringsAsFactors = FALSE
        ))
      }, error = function(e) {
        warning(paste("Error reading file:", file, "-", e$message))
      })
    }
  }

  return(list(
    total_lines = total_lines,
    total_lines_with_comments = total_lines_with_comments,
    file_count = file_count,
    details = details
  ))
}

# ============================================================================
# Count R-related files (.R, .RMD, .QMD)
# ============================================================================

r_results <- count_lines_in_files(
  folders = folders_to_analyze,
  extensions = c("R", "RMD", "QMD"),
  parent_path = parent_dir,
  language = "R"
)

# ============================================================================
# Count Python files (.py)
# ============================================================================

py_results <- count_lines_in_files(
  folders = folders_to_analyze,
  extensions = c("py"),
  parent_path = parent_dir,
  language = "Python"
)


# ============================================================================
# SUMMARY BY FOLDER
# ============================================================================

cat("\n", rep("=", 80), "\n", sep = "")
cat("SUMMARY BY FOLDER\n")
cat(rep("=", 80), "\n\n", sep = "")

# Initialize folder_summary (always create it, even if empty)
folder_summary <- data.frame(
  folder = character(),
  r_files = integer(),
  r_lines = integer(),
  py_files = integer(),
  py_lines = integer(),
  total_files = integer(),
  total_lines = integer(),
  stringsAsFactors = FALSE
)

# Combine R and Python results
if (nrow(r_results$details) > 0 || nrow(py_results$details) > 0) {

  # Get unique folders from both results
  all_analyzed_folders <- unique(c(r_results$details$folder, py_results$details$folder))

  for (folder in all_analyzed_folders) {
    # R stats for this folder
    r_folder_data <- r_results$details[r_results$details$folder == folder, ]
    r_files <- nrow(r_folder_data)
    r_lines <- sum(r_folder_data$lines_no_comments)

    # Python stats for this folder
    py_folder_data <- py_results$details[py_results$details$folder == folder, ]
    py_files <- nrow(py_folder_data)
    py_lines <- sum(py_folder_data$lines_no_comments)

    folder_summary <- rbind(folder_summary, data.frame(
      folder = folder,
      r_files = r_files,
      r_lines = r_lines,
      py_files = py_files,
      py_lines = py_lines,
      total_files = r_files + py_files,
      total_lines = r_lines + py_lines,
      stringsAsFactors = FALSE
    ))
  }

  # Sort by total lines (descending)
  folder_summary <- folder_summary[order(-folder_summary$total_lines), ]

  # Print folder summary table
  print(folder_summary, row.names = FALSE)

  # Print detailed view
  cat("\n", rep("-", 80), "\n", sep = "")
  cat("DETAILED VIEW BY FOLDER\n")
  cat(rep("-", 80), "\n", sep = "")

  # for (i in 1:nrow(folder_summary)) {
  #   row <- folder_summary[i, ]
  #   cat("\n", row$folder, ":\n", sep = "")
  #   cat("  R files:      ", sprintf("%3d files, %6d lines", row$r_files, row$r_lines), "\n", sep = "")
  #   cat("  Python files: ", sprintf("%3d files, %6d lines", row$py_files, row$py_lines), "\n", sep = "")
  #   cat("  TOTAL:        ", sprintf("%3d files, %6d lines", row$total_files, row$total_lines), "\n", sep = "")
  # }


  for (i in seq_len(nrow(folder_summary))) {
    row <- folder_summary[i, ]
    cat("\n", row$folder, ":\n", sep = "")
    cat("  R files:      ", sprintf("%3d files, %6d lines", row$r_files, row$r_lines), "\n", sep = "")
    cat("  Python files: ", sprintf("%3d files, %6d lines", row$py_files, row$py_lines), "\n", sep = "")
    cat("  TOTAL:        ", sprintf("%3d files, %6d lines", row$total_files, row$total_lines), "\n", sep = "")
  }

} else {
  cat("No files found in the analyzed folders.\n")
}

# ============================================================================
# GRAND TOTAL SUMMARY
# ============================================================================

cat("\n", rep("=", 80), "\n", sep = "")
cat("GRAND TOTAL SUMMARY\n")
cat(rep("=", 80), "\n\n", sep = "")

cat("R Files (.R, .RMD, .QMD):\n")
cat("  Files:        ", sprintf("%6d", r_results$file_count), "\n", sep = "")
cat("  Code lines:   ", sprintf("%6d (excluding comments)", r_results$total_lines), "\n", sep = "")
cat("  Total lines:  ", sprintf("%6d (including comments)", r_results$total_lines_with_comments), "\n", sep = "")
cat("  Comment lines:", sprintf("%6d", r_results$total_lines_with_comments - r_results$total_lines), "\n\n", sep = "")

cat("Python Files (.py):\n")
cat("  Files:        ", sprintf("%6d", py_results$file_count), "\n", sep = "")
cat("  Code lines:   ", sprintf("%6d (excluding comments)", py_results$total_lines), "\n", sep = "")
cat("  Total lines:  ", sprintf("%6d (including comments)", py_results$total_lines_with_comments), "\n", sep = "")
cat("  Comment lines:", sprintf("%6d", py_results$total_lines_with_comments - py_results$total_lines), "\n\n", sep = "")

cat(rep("-", 80), "\n", sep = "")
cat("COMBINED TOTAL:\n")
cat("  Files:        ", sprintf("%6d", r_results$file_count + py_results$file_count), "\n", sep = "")
cat("  Code lines:   ", sprintf("%6d (excluding comments)", r_results$total_lines + py_results$total_lines), "\n", sep = "")
cat("  Total lines:  ", sprintf("%6d (including comments)",
                                r_results$total_lines_with_comments + py_results$total_lines_with_comments), "\n", sep = "")
cat("  Comment lines:", sprintf("%6d",
                                (r_results$total_lines_with_comments - r_results$total_lines) +
                                  (py_results$total_lines_with_comments - py_results$total_lines)), "\n", sep = "")

cat("\n", rep("=", 80), "\n", sep = "")

# ============================================================================
# Optional: Export summaries to CSV
# ============================================================================

timestamp <- format(Sys.time(), "%Y%m%d_%H%M")




# Export folder summary (now always exists)
if (nrow(folder_summary) > 0) {
  write.csv(folder_summary, paste0(csv_path, "code_summary_by_folder_", timestamp, ".csv"), row.names = FALSE)
  cat("\nFolder summary exported to: code_summary_by_folder.csv\n")
} else {
  cat("\nNo folders with code files to export.\n")
}

# Export detailed file listing
if (nrow(r_results$details) > 0 || nrow(py_results$details) > 0) {

  # Create combined details safely
  combined_details <- data.frame()

  if (nrow(r_results$details) > 0) {
    r_details_with_lang <- cbind(r_results$details, language = "R", stringsAsFactors = FALSE)
    combined_details <- rbind(combined_details, r_details_with_lang)
  }

  if (nrow(py_results$details) > 0) {
    py_details_with_lang <- cbind(py_results$details, language = "Python", stringsAsFactors = FALSE)
    combined_details <- rbind(combined_details, py_details_with_lang)
  }

  write.csv(combined_details, paste0(csv_path,"code_details_by_file.csv"), row.names = FALSE)
  cat("File details exported to: code_details_by_file.csv\n")

} else {
  cat("No code files found to export.\n")
}






