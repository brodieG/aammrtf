source("aammrtf/init.R")
library(add)
add(1, 2)
all.equal(add(pi, "1"), 4.141592654)   # WARNING
try(add("pi", 1))                      # ERROR
