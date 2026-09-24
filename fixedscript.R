# Install tidyverse only if it is not already available
if (!requireNamespace("tidyverse", quietly = TRUE)) {
  install.packages("tidyverse")
}
library(tidyverse)

mtcars

# We want to filter for 4-cylinder cars and plot a scatter
mtcars |>
  filter(cyl == 4) |>
  ggplot(aes(x = wt, y = mpg)) +
  geom_point()
