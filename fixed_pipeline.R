#!/usr/bin/env Rscript
# =============================================================================
# fixed_pipeline.R
#
# Corrected rebuild of the broken pipeline (opencode.R / broken_pipeline.R).
#
# Fixes applied:
#   1. ggplot2 layers are joined with `+`, not `|>`.  Using `|>` fed the whole
#      ggplot object into geom_point()'s `mapping` argument, which fails with
#      "`mapping` must be created by `aes()`".
#   2. Packages are installed only when actually missing, and a CRAN mirror is
#      set first so `install.packages()` no longer aborts with "trying to use
#      CRAN without setting a mirror" under Rscript.
#   3. The plot is assigned to a variable so it can be saved, instead of being
#      built and silently discarded.
#   4. The stray bare `mtcars` statement (which dumped 32 rows to the console
#      as a side effect) is replaced by an explicit, informative summary.
#   5. outputs/ is created with dir.create() *before* any file is written, so
#      the pipeline no longer dies on a missing directory.
#   6. Output paths are anchored to this script's own folder, so the pipeline
#      writes to the same place regardless of where it is launched from.
# =============================================================================


# ---- 1. Dependencies -------------------------------------------------------

needed <- c("ggplot2", "dplyr")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) > 0) {
  # Rscript starts with repos = "@CRAN@", which makes install.packages() fail.
  repos <- getOption("repos")
  if (is.null(repos) || any(is.na(repos)) || any(repos %in% c("@CRAN@", ""))) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }
  install.packages(missing)
}

library(ggplot2)
library(dplyr)


# ---- 2. Locate the output directory (before anything is written) ----------

# Anchor to the script's folder when run via `Rscript fixed_pipeline.R`,
# otherwise fall back to the current working directory.
script_path <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
base_dir <- if (length(script_path) > 0) {
  dirname(normalizePath(sub("^--file=", "", script_path[1])))
} else {
  getwd()
}

output_dir <- file.path(base_dir, "outputs")

# `recursive = TRUE` also creates any missing parent directories.
# `showWarnings = FALSE` keeps a re-run quiet when outputs/ already exists.
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

# Fail loudly here rather than letting ggsave() fail obscurely later.
if (!dir.exists(output_dir)) {
  stop("Could not create the output directory: ", output_dir)
}
message("Writing outputs to: ", output_dir)


# ---- 3. Data preparation ---------------------------------------------------

# mtcars ships with the datasets package; nothing to download.
data("mtcars", package = "datasets")

# Guard against a silent empty result.
stopifnot(is.data.frame(mtcars), nrow(mtcars) > 0, all(c("cyl", "wt", "mpg") %in% names(mtcars)))

cyl4 <- mtcars |>
  as_tibble(rownames = "model") |>
  filter(cyl == 4)

if (nrow(cyl4) == 0) {
  stop("Filtering on cyl == 4 produced no rows - check the input data.")
}

# Replaces the old bare `mtcars` line with an explicit summary.
message(sprintf(
  "Loaded %d cars; %d are 4-cylinder (mean %.1f mpg, mean weight %.2f).",
  nrow(mtcars), nrow(cyl4), mean(cyl4$mpg), mean(cyl4$wt)
))


# ---- 4. Plot (note the `+`, not `|>`) --------------------------------------

cyl4_plot <- ggplot(cyl4, aes(x = wt, y = mpg)) +
  geom_point(size = 3, colour = "steelblue", alpha = 0.85) +
  geom_smooth(method = "lm", se = TRUE, colour = "darkorange") +
  labs(
    title = "Fuel efficiency vs. weight (4-cylinder cars)",
    subtitle = "mtcars dataset",
    x = "Weight (1000 lbs)",
    y = "Miles per gallon"
  ) +
  theme_minimal(base_size = 13)


# ---- 5. Save outputs -------------------------------------------------------

plot_file <- file.path(output_dir, "mtcars_4cyl_scatter.png")
csv_file  <- file.path(output_dir, "mtcars_4cyl.csv")

ggsave(
  filename = plot_file,
  plot     = cyl4_plot,
  width    = 8,
  height   = 6,
  dpi      = 300
)

write.csv(cyl4, csv_file, row.names = FALSE)

# Verify the artifacts really exist.
written <- c(plot_file, csv_file)
if (!all(file.exists(written))) {
  stop("Expected output file(s) missing: ",
       paste(written[!file.exists(written)], collapse = ", "))
}

message("Saved:\n  - ", plot_file, "\n  - ", csv_file)
