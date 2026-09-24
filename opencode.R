install.packages("tidyverse")
library(tidyverse)
mtcars

# We want to filter for 4 - cylinder cars and plot a scatter
mtcars|>
filter(cyl==4)|>
ggplot(aes(x=wt,y=mpg))|> # should be +
geom_point()
