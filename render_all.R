# render_all.R
# Renders all .qmd files in /scripts to /docs using quarto.

if (!requireNamespace("quarto", quietly = TRUE)) install.packages("quarto")
if (!requireNamespace("here", quietly = TRUE))  install.packages("here")

library(quarto)
library(here)

# Resolve absolute paths
scripts_dir <- here::here("scripts")
docs_dir    <- here::here("docs")

# Create /docs if it does not exist
if (!dir.exists(docs_dir)) {
  dir.create(docs_dir, recursive = TRUE)
  message("Created output directory: ", docs_dir)
}

# Collect all .qmd files in /scripts (non-recursive)
qmd_files <- list.files(
  path       = scripts_dir,
  pattern    = "\\.qmd$",
  full.names = TRUE
)

if (length(qmd_files) == 0) {
  stop("No .qmd files found in: ", scripts_dir)
}

message("Found ", length(qmd_files), " .qmd file(s) to render.\n")

# Render each file, directing output to /docs
results <- purrr::map(qmd_files, function(qmd_path) {
  file_name <- basename(qmd_path)
  message("Rendering: ", file_name)

  tryCatch(
    {
      quarto::quarto_render(
        input           = qmd_path,
        output_format   = "all",
        output_file     = NULL,         # keep Quarto's default output name
        execute_dir     = here::here(), # project root so here() works in each doc
        quiet           = FALSE
      )

      # Move rendered output(s) from /scripts to /docs
      # Quarto writes output next to the .qmd by default
      rendered_files <- list.files(
        path       = scripts_dir,
        pattern    = paste0("^", tools::file_path_sans_ext(file_name), "\\."),
        full.names = TRUE
      )

      # Exclude the source .qmd itself
      rendered_files <- rendered_files[!grepl("\\.qmd$", rendered_files)]

      purrr::walk(rendered_files, function(f) {
        dest <- file.path(docs_dir, basename(f))
        file.rename(f, dest)
        message("  Moved -> docs/", basename(f))
      })

      list(file = file_name, status = "ok")
    },
    error = function(e) {
      message("  ERROR rendering ", file_name, ": ", conditionMessage(e))
      list(file = file_name, status = "error", message = conditionMessage(e))
    }
  )
})

# Summary report
message("\n--- Render Summary ---")
purrr::walk(results, function(r) {
  status_label <- if (r$status == "ok") "[OK]" else "[FAILED]"
  message(status_label, " ", r$file)
})
