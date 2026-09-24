# opencode

A small R analysis pipeline that downloads the Swiss fertility dataset,
computes the Pearson correlation matrix among its socio‑economic indicators,
and writes the result as an annotated heatmap.

## What the script does

`fixed_pipeline.R` performs a short, self‑contained analysis in six stages:

1. **Loads dependencies** — installs `readr`, `dplyr`, `tidyr`, and `ggplot2`
   *only* if they are missing, setting a valid CRAN mirror first so installation
   works under non‑interactive `Rscript`.
2. **Creates the output directory** — resolves `outputs/` relative to the
   script's own location and calls `dir.create(..., recursive = TRUE)` before
   any file is written, aborting with a clear message if creation fails.
3. **Downloads the data** — reads `swiss.csv` directly from GitHub at runtime,
   with a `tryCatch` that reports the failing URL clearly if the download breaks.
4. **Validates and cleans** — renames the blank first‑column header to
   `District`, checks the column schema, and asserts the data is non‑empty,
   missing‑value free, and correctly typed before any analysis runs.
5. **Computes correlations** — drops the district names, builds the 6×6 Pearson
   matrix, rejects non‑finite values, and ranks the strongest variable pairs.
6. **Plots and saves** — renders an annotated heatmap joined with ggplot2's `+`
   operator, writes four artifacts, then confirms each exists on disk.

### Data source

<https://github.com/Marshall-Soc/css_bootcamp/blob/main/data/swiss.csv>

47 French‑speaking Swiss districts observed around 1888, with six quantitative
measures: `Fertility`, `Agriculture`, `Examination`, `Education`, `Catholic`,
and `Infant.Mortality`.

## Outputs

Running the pipeline creates the following (the directory is created
automatically if it does not exist):

| File | Description |
| --- | --- |
| `outputs/swiss_correlation_heatmap.png` | Annotated 6×6 heatmap, 8×7 in at 300 DPI |
| `outputs/swiss_correlation_matrix.csv` | Pearson correlation matrix, rounded to 4 decimals |
| `outputs/swiss_top_correlations.csv` | Five strongest variable pairs, ranked by \|r\| |
| `outputs/swiss_clean.csv` | The 47 districts with the `District` column renamed |

## Changelog

Bugs fixed from the original script (`opencode.R` / `broken_pipeline.R`):

- **Fixed the wrong dataset** — the original analyzed the built‑in `mtcars`
  data instead of the required Swiss dataset. The pipeline now downloads
  `swiss.csv` from the `Marshall-Soc/css_bootcamp` repository.
- **Fixed `|>` used instead of `+` to attach ggplot2 layers** — the original
  `ggplot(...) |> geom_point()` piped the whole plot object into
  `geom_point()`'s `mapping` argument, failing at runtime with
  `` `mapping` must be created by `aes()` ``. Layers are now joined with `+`.
- **Fixed unconditional `install.packages("tidyverse")`** — it reinstalled a
  very large package on every run, and crashed under `Rscript` with
  *"trying to use CRAN without setting a mirror"* because the default repo is
  `"@CRAN@"`. Packages are now installed only when missing, and a mirror is set
  first.
- **Fixed missing `outputs/` directory** — the original never created it, so any
  save attempt failed with *"cannot open the connection"*. `dir.create()` is now
  called (with `recursive = TRUE` and `showWarnings = FALSE`) **before** any file
  is written, followed by an explicit existence check.
- **Fixed the plot being built and then discarded** — the plot was never
  assigned to a variable, so the pipeline produced no artifact. It is now stored
  in `corr_plot` and saved with `ggsave()`.
- **Fixed duplicated correlation pairs** — ranking the off‑diagonal cells alone
  listed every pair twice (`Education~Examination` *and*
  `Examination~Education`), so a "top 5" showed only three real relationships.
  A `Var1 < Var2` filter now keeps each unordered pair exactly once.
- **Fixed the blank column header** — the district column in `swiss.csv` has an
  empty header, which `readr` renames to `...1`. It is now explicitly renamed to
  `District`.
- **Removed the stray bare `mtcars` statement** — it dumped all 32 rows to the
  console as a side effect and assigned nothing. Replaced with an explicit
  `message()` summary.
- **Narrowed `library(tidyverse)` to four specific packages** — the original
  loaded ~30 packages to use two of them.
- **Added schema and input validation** — column names, row count, missing
  values, and column types are all checked before analysis; a non‑finite
  correlation (zero variance) aborts with a clear message.
- **Added download error handling** — a failed fetch reports the URL and the
  underlying reason instead of a cryptic parser error.
- **Made output paths script‑relative instead of cwd‑relative** — running from
  another directory previously wrote to an unexpected location (or nowhere).
  Paths are now anchored to the script's own folder.
- **Added post‑write verification** — all four output files are checked with
  `file.exists()` so a silent save failure cannot pass as success.
- **Documented the pipeline** — sections, comments, and an inline list of fixes
  added for maintainability.

> **Note:** `broken_pipeline.R` in this repository is 0 bytes (empty) and was
> never populated with code — the broken logic it was meant to hold lives in
> `opencode.R`, which is listed in `.gitignore` and removed from git history in
> commit `e73022f`.

## How to run the fixed pipeline

**Requirements:** R ≥ 4.1 (for the native `|>` pipe) and internet access to
fetch the CSV. Verified on R 4.5.2.

From the repository root:

```bash
Rscript fixed_pipeline.R
```

Or from an arbitrary directory (outputs are still written to the repo root):

```bash
Rscript /path/to/opencode/fixed_pipeline.R
```

You can also run it from an R/RStudio session:

```r
source("fixed_pipeline.R")
```

**Expected output:**

```
Writing outputs to: /path/to/opencode/outputs
Downloading: https://raw.githubusercontent.com/Marshall-Soc/css_bootcamp/main/data/swiss.csv
Loaded 47 districts x 7 variables from the Swiss fertility dataset.
Saved:
  - /path/to/opencode/outputs/swiss_correlation_heatmap.png
  - /path/to/opencode/outputs/swiss_correlation_matrix.csv
  - /path/to/opencode/outputs/swiss_top_correlations.csv
  - /path/to/opencode/outputs/swiss_clean.csv
Strongest association: Education ~ Examination (r = 0.698)
```

The script exits with status `0` on success. Re‑running is safe: an existing
`outputs/` directory is reused without warnings, and the files are overwritten.

To regenerate everything from scratch:

```bash
rm -rf outputs
Rscript fixed_pipeline.R
```

## Key findings

* **Education and Examination** are the strongest pair (r = 0.70) — districts
  with more schooling also scored better in the military examination.
* **Fertility and Education** are strongly negatively correlated (r = −0.66).
* **Infant mortality** is largely disconnected from the other indicators, with
  all of its correlations within ±0.18 of zero except a moderate positive link
  with fertility (r = 0.42).

Correlation does not imply causation, and these are district‑level (ecological)
quantities, so the coefficients are descriptive rather than causal.

## Repository contents

| File | Purpose |
| --- | --- |
| `fixed_pipeline.R` | The corrected, runnable pipeline (**start here**) |
| `broken_pipeline.R` | Placeholder for the broken version — currently empty |
| `opencode.R` | The original broken script (gitignored, kept locally) |
| `fixedscript.R` | Earlier partial fix of `opencode.R` (plot never saved) |
| `swiss_correlation.qmd` | Quarto report of the same analysis, rendered to HTML |
| `outputs/` | Generated artifacts — auto‑created on first run |
