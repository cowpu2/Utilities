## ============== Count Markdown Lines ==========================
##
## Counts .md files and lines in a selected folder.
## Captures file timestamps and plots lines vs modified time.
##
## Usage:
##   Rscript CountMarkdownLines.R "C:/path/to/folder"
##   Rscript CountMarkdownLines.R
##
## When no valid folder is supplied, a folder picker is shown.
## ======================================================================

choose_parent_dir <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) > 0 && dir.exists(args[1])) {
    return(normalizePath(args[1], winslash = "/", mustWork = TRUE))
  }

  selected_dir <- NULL

  if (.Platform$OS.type == "windows" && exists("choose.dir", mode = "function")) {
    selected_dir <- choose.dir(caption = "Select folder containing Markdown files")
  }

  if (is.null(selected_dir) || is.na(selected_dir) || !dir.exists(selected_dir)) {
    if (requireNamespace("tcltk", quietly = TRUE)) {
      selected_dir <- tcltk::tk_choose.dir(caption = "Select folder containing Markdown files")
    }
  }

  if (is.null(selected_dir) || is.na(selected_dir) || !dir.exists(selected_dir)) {
    stop("No valid folder selected.", call. = FALSE)
  }

  normalizePath(selected_dir, winslash = "/", mustWork = TRUE)
}

count_markdown_lines <- function(file_path) {
  lines <- readLines(file_path, warn = FALSE, skipNul = TRUE, encoding = "UTF-8")

  data.frame(
    total_lines = length(lines),
    non_empty_lines = sum(nchar(trimws(lines)) > 0),
    stringsAsFactors = FALSE
  )
}

collect_markdown_details <- function(parent_dir) {
  md_files <- list.files(
    path = parent_dir,
    pattern = "\\.md$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(md_files) == 0) {
    return(data.frame(
      folder = character(),
      file = character(),
      path = character(),
      total_lines = integer(),
      non_empty_lines = integer(),
      size_bytes = numeric(),
      created_time = as.POSIXct(character()),
      modified_time = as.POSIXct(character()),
      stringsAsFactors = FALSE
    ))
  }

  details <- lapply(md_files, function(file_path) {
    file_info <- file.info(file_path)
    line_counts <- count_markdown_lines(file_path)
    relative_path <- sub(paste0("^", normalizePath(parent_dir, winslash = "/"), "/?"), "", normalizePath(file_path, winslash = "/"))
    folder <- dirname(relative_path)

    if (folder == ".") {
      folder <- "(parent_dir)"
    }

    data.frame(
      folder = folder,
      file = basename(file_path),
      path = relative_path,
      total_lines = line_counts$total_lines,
      non_empty_lines = line_counts$non_empty_lines,
      size_bytes = file_info$size,
      created_time = file_info$ctime,
      modified_time = file_info$mtime,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, details)
}

write_lines_plot <- function(details, output_path) {
  if (nrow(details) == 0) {
    return(FALSE)
  }

  daily_lines <- aggregate(
    total_lines ~ modified_date,
    data = transform(details, modified_date = as.Date(modified_time)),
    FUN = sum
  )
  daily_lines <- daily_lines[order(daily_lines$modified_date), ]
  daily_lines$cumulative_lines <- cumsum(daily_lines$total_lines)

  png(filename = output_path, width = 1200, height = 800, res = 120)
  on.exit(dev.off(), add = TRUE)

  plot(
    daily_lines$modified_date,
    daily_lines$cumulative_lines,
    type = "l",
    xlab = "Modified date",
    ylab = "Cumulative total lines",
    main = "Accumulated Markdown lines by modified date",
    ylim = c(0, max(daily_lines$cumulative_lines)),
    lwd = 2,
    col = "steelblue"
  )

  points(
    daily_lines$modified_date,
    daily_lines$cumulative_lines,
    pch = 19,
    col = "steelblue"
  )

  TRUE
}

parent_dir <- choose_parent_dir()
timestamp <- format(Sys.time(), "%Y%m%d_%H%M")
project_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
output_dir <- file.path(project_dir, "markdown_line_counts")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

details <- collect_markdown_details(parent_dir)

if (nrow(details) > 0) {
  folder_summary <- data.frame(
    folder = unique(details$folder),
    file_count = as.integer(tabulate(match(details$folder, unique(details$folder)))),
    total_lines = as.integer(tapply(details$total_lines, details$folder, sum)[unique(details$folder)]),
    non_empty_lines = as.integer(tapply(details$non_empty_lines, details$folder, sum)[unique(details$folder)]),
    stringsAsFactors = FALSE
  )
  folder_summary <- folder_summary[order(-folder_summary$total_lines), ]
} else {
  folder_summary <- data.frame(
    folder = character(),
    file_count = integer(),
    total_lines = integer(),
    non_empty_lines = integer(),
    stringsAsFactors = FALSE
  )
}

grand_total <- data.frame(
  parent_dir = parent_dir,
  file_count = nrow(details),
  total_lines = sum(details$total_lines),
  non_empty_lines = sum(details$non_empty_lines),
  earliest_modified_time = if (nrow(details) > 0) min(details$modified_time) else as.POSIXct(NA),
  latest_modified_time = if (nrow(details) > 0) max(details$modified_time) else as.POSIXct(NA),
  stringsAsFactors = FALSE
)

details_path <- file.path(output_dir, paste0("markdown_details_by_file_", timestamp, ".csv"))
folder_summary_path <- file.path(output_dir, paste0("markdown_summary_by_folder_", timestamp, ".csv"))
grand_total_path <- file.path(output_dir, paste0("markdown_grand_total_", timestamp, ".csv"))
plot_path <- file.path(output_dir, paste0("markdown_lines_vs_time_", timestamp, ".png"))

write.csv(details, details_path, row.names = FALSE)
write.csv(folder_summary, folder_summary_path, row.names = FALSE)
write.csv(grand_total, grand_total_path, row.names = FALSE)
plot_written <- write_lines_plot(details, plot_path)

cat("\n", rep("=", 80), "\n", sep = "")
cat("MARKDOWN LINE COUNT SUMMARY\n")
cat(rep("=", 80), "\n\n", sep = "")
cat("Folder:         ", parent_dir, "\n", sep = "")
cat("Markdown files: ", grand_total$file_count, "\n", sep = "")
cat("Total lines:    ", grand_total$total_lines, "\n", sep = "")
cat("Non-empty lines: ", grand_total$non_empty_lines, "\n\n", sep = "")

if (nrow(folder_summary) > 0) {
  cat("SUMMARY BY FOLDER\n")
  print(folder_summary, row.names = FALSE)
} else {
  cat("No .md files found.\n")
}

cat("\nOutputs written to:\n")
cat("  File details:   ", details_path, "\n", sep = "")
cat("  Folder summary: ", folder_summary_path, "\n", sep = "")
cat("  Grand total:    ", grand_total_path, "\n", sep = "")

if (plot_written) {
  cat("  Plot:           ", plot_path, "\n", sep = "")
}
