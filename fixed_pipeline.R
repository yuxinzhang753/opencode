#!/usr/bin/env Rscript
# =============================================================================
# fixed_pipeline.R
#
# Corrected rebuild of the broken pipeline (opencode.R / broken_pipeline.R).
# Analyzes the Swiss fertility dataset and writes a correlation heatmap.
#
# Fixes applied:
#   1. USES THE CORRECT DATASET. The earlier version plotted the built-in
#      `mtcars` data; the required source is swiss.csv from the css_bootcamp
#      repository (URL below), downloaded at runtime.
#   2. ggplot2 layers are joined with `+`, not `|>`. Using `|>` fed the whole
#      ggplot object into geom_point()'s `mapping` argument, which fails with
#      "`mapping` must be created by `aes()`".
#   3. Packages are installed only when actually missing, and a CRAN mirror is
#      set first so `install.packages()` no longer aborts with "trying to use
#      CRAN without setting a mirror" under Rscript.
#   4. outputs/ is created with dir.create() *before* any file is written, so
#      the pipeline no longer dies on a missing directory.
#   5. The stray bare `mtcars` statement (which dumped 32 rows to the console
#      as a side effect) is replaced by an explicit, informative summary.
#   6. The blank first-column header is renamed to `District` instead of being
#      left as readr's auto-generated `...1`.
#   7. Output paths are anchored to this script's own folder, so the pipeline
#      writes to the same place regardless of where it is launched from.
# =============================================================================


# ---- 1. Dependencies -------------------------------------------------------

needed <- c("readr", "dplyr", "tidyr", "ggplot2")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing) > 0) {
  # Rscript starts with repos = "@CRAN@", which makes install.packages() fail.
  repos <- getOption("repos")
  if (is.null(repos) || any(is.na(repos)) || any(repos %in% c("@CRAN@", ""))) {
    options(repos = c(CRAN = "https://cloud.r-project.org"))
  }
  install.packages(missing)
}

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)


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


# ---- 3. Load the data ------------------------------------------------------

data_url <- "https://raw.githubusercontent.com/Marshall-Soc/css_bootcamp/main/data/swiss.csv"

message("Downloading: ", data_url)

swiss <- tryCatch(
  read_csv(data_url, show_col_types = FALSE),
  error = function(e) {
    stop("Could not download the Swiss data from\n  ", data_url,
         "\nReason: ", conditionMessage(e), call. = FALSE)
  }
)

# The district column arrives with an empty header, which readr renames to
# `...1`. Give it a real name so downstream code is readable and stable.
names(swiss)[1] <- "District"

# Column names must match the documented schema.
expected <- c("District", "Fertility", "Agriculture", "Examination",
              "Education", "Catholic", "Infant.Mortality")
if (!all(expected %in% names(swiss))) {
  stop("Unexpected columns in swiss.csv.\n  Expected: ",
       paste(expected, collapse = ", "),
       "\n  Found:    ", paste(names(swiss), collapse = ", "), call. = FALSE)
}

# Guard against empty or malformed input before any analysis runs.
stopifnot(
  is.data.frame(swiss),
  nrow(swiss) > 0,
  !anyNA(swiss),
  is.character(swiss$District),
  all(vapply(swiss[expected[-1]], is.numeric, logical(1)))
)

message(sprintf(
  "Loaded %d districts x %d variables from the Swiss fertility dataset.",
  nrow(swiss), ncol(swiss)
))


# ---- 4. Correlation matrix -------------------------------------------------

# Only quantitative variables enter the matrix; District is dropped.
swiss_num <- swiss |> select(where(is.numeric))

corr_mat <- cor(swiss_num, use = "complete.obs")

if (any(!is.finite(corr_mat))) {
  stop("Correlation matrix contains non-finite values (zero variance?).",
       call. = FALSE)
}

# Rank off-diagonal pairs by absolute correlation.
var_levels <- colnames(corr_mat)

# `Var1 < Var2` keeps each unordered pair exactly once; without it the matrix's
# symmetry would list every pair twice (A~B and B~A).
top_pairs <- as.data.frame(as.table(corr_mat)) %>%
  filter(as.character(Var1) < as.character(Var2)) %>%
  mutate(abs_r = abs(Freq)) %>%
  arrange(desc(abs_r)) %>%
  slice_head(n = 5)


# ---- 5. Heatmap (note the `+`, not `|>`) -----------------------------------

corr_df <- as.data.frame(corr_mat) %>%
  mutate(Variable1 = factor(rownames(corr_mat), levels = var_levels)) %>%
  pivot_longer(
    cols = -Variable1,
    names_to = "Variable2",
    values_to = "r"
  ) %>%
  mutate(Variable2 = factor(Variable2, levels = var_levels))

corr_plot <- ggplot(corr_df, aes(x = Variable2, y = Variable1, fill = r)) +
  geom_tile(color = "white", linewidth = 1) +
  geom_text(aes(label = sprintf("%.2f", r)), size = 4.2, family = "mono") +
  scale_fill_gradient2(
    low = "#2166AC", mid = "white", high = "#B2182B",
    midpoint = 0, limits = c(-1, 1), name = "Pearson r"
  ) +
  coord_fixed() +
  labs(
    title = "Correlation heatmap of Swiss district indicators",
    subtitle = "Blue = negative association, red = positive association",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"),
    axis.text.y = element_text(face = "bold"),
    panel.grid = element_blank(),
    plot.title = element_text(face = "bold")
  )


# ---- 6. Save outputs -------------------------------------------------------

plot_file <- file.path(output_dir, "swiss_correlation_heatmap.png")
corr_file <- file.path(output_dir, "swiss_correlation_matrix.csv")
pairs_file <- file.path(output_dir, "swiss_top_correlations.csv")
data_file  <- file.path(output_dir, "swiss_clean.csv")

ggsave(
  filename = plot_file,
  plot     = corr_plot,
  width    = 8,
  height   = 7,
  dpi      = 300
)

write.csv(round(corr_mat, 4), corr_file)
write.csv(top_pairs, pairs_file, row.names = FALSE)
write.csv(swiss, data_file, row.names = FALSE)

# Verify the artifacts really exist.
written <- c(plot_file, corr_file, pairs_file, data_file)
if (!all(file.exists(written))) {
  stop("Expected output file(s) missing: ",
       paste(written[!file.exists(written)], collapse = ", "), call. = FALSE)
}

message("Saved:\n  - ", paste(written, collapse = "\n  - "))
message(sprintf(
  "Strongest association: %s ~ %s (r = %.3f)",
  top_pairs$Var1[1], top_pairs$Var2[1], top_pairs$Freq[1]
))
