# opencode

A small R analysis pipeline that builds a labelled scatter plot of fuel
efficiency versus weight for the 4‑cylinder cars in the built‑in `mtcars`
dataset.

## What the script does

`fixed_pipeline.R` performs a short, self‑contained analysis in five stages:

1. **Loads dependencies** — installs `ggplot2` and `dplyr` *only* if they are
   missing, setting a valid CRAN mirror first so installation works under
   non‑interactive `Rscript`.
2. **Creates the output directory** — resolves `outputs/` relative to the
   script's own location and calls `dir.create(..., recursive = TRUE)` before
   any file is written, aborting with a clear message if creation fails.
3. **Prepares the data** — loads `mtcars`, validates that the required columns
   exist, then filters to the 11 four‑cylinder cars. It errors out rather than
   silently continuing if the filter returns zero rows.
4. **Builds the plot** — a scatter of `wt` (x) against `mpg` (y), overlaid with
   a linear regression line and its confidence band, joined with ggplot2's `+`
   operator.
5. **Saves and verifies outputs** — writes a PNG and a CSV, then confirms both
   files actually exist on disk before reporting success.

## Outputs

Running the pipeline creates the following (the directory is created
automatically if it does not exist):

| File | Description |
| --- | --- |
| `outputs/mtcars_4cyl_scatter.png` | Scatter plot, 8×6 in at 300 DPI |
| `outputs/mtcars_4cyl.csv` | The 11 filtered 4‑cylinder records, with car names |

## Changelog

Bugs fixed from the original script (`opencode.R` / `broken_pipeline.R`):

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
- **Fixed plot being built and then discarded** — the plot was never assigned to
  a variable, so the pipeline produced no artifact. It is now stored in
  `cyl4_plot` and saved with `ggsave()`.
- **Removed the stray bare `mtcars` statement** — it dumped all 32 rows to the
  console as a side effect and assigned nothing. Replaced with an explicit
  `message()` summary (row counts and means).
- **Narrowed `library(tidyverse)` to `ggplot2` + `dplyr`** — the original loaded
  ~30 packages to use two of them.
- **Added an empty‑result guard** — `filter(cyl == 4)` returning zero rows would
  previously have produced an empty plot silently; it now raises an error.
- **Added input validation** — `stopifnot()` confirms `mtcars` is a non‑empty
  data frame containing `cyl`, `wt`, and `mpg` before any analysis runs.
- **Made output paths script‑relative instead of cwd‑relative** — running from
  another directory previously wrote to an unexpected location (or nowhere).
  Paths are now anchored to the script's own folder.
- **Added post‑write verification** — both output files are checked with
  `file.exists()` so a silent save failure cannot pass as success.
- **Documented the pipeline** — sections, comments, and an inline list of fixes
  added for maintainability.

> **Note:** `broken_pipeline.R` in this repository is 0 bytes (empty) and was
> never populated with code — the broken logic it was meant to hold lives in
> `opencode.R`, which is listed in `.gitignore` and removed from git history in
> commit `e73022f`.

## How to run the fixed pipeline

**Requirements:** R ≥ 4.1 (for the native `|>` pipe). Verified on R 4.5.2.

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
Loaded 32 cars; 11 are 4-cylinder (mean 26.7 mpg, mean weight 2.29).
Saved:
  - /path/to/opencode/outputs/mtcars_4cyl_scatter.png
  - /path/to/opencode/outputs/mtcars_4cyl.csv
```

The script exits with status `0` on success. Re‑running is safe: an existing
`outputs/` directory is reused without warnings, and the files are overwritten.

To regenerate everything from scratch:

```bash
rm -rf outputs
Rscript fixed_pipeline.R
```

## Repository contents

| File | Purpose |
| --- | --- |
| `fixed_pipeline.R` | The corrected, runnable pipeline (**start here**) |
| `broken_pipeline.R` | Placeholder for the broken version — currently empty |
| `opencode.R` | The original broken script (gitignored, kept locally) |
| `fixedscript.R` | Earlier partial fix of `opencode.R` (plot never saved) |
| `swiss_correlation.qmd` | Separate Quarto analysis of the Swiss fertility data |
| `outputs/` | Generated artifacts — auto‑created on first run |
