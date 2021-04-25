# Copyright (C) 2021 Brodie Gaslam

# This file is part of "aammrtf - An Almost Most Minimal R Test Framework"
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# Go to <https://www.r-project.org/Licenses/GPL-2> for a copy of the license.

## Generate Reference Object Accessor Functions
##
## Helper functions to simplify reading and writing reference files.
##
## @param name character(1) a name to use as a subfolder under `obj.dir`.
## @param obj.dir character(1L) directory to reference objects in.
## @return a list of reading ("rds", "txt"), and writing functions, ("rds_save",
##   "txt_save").
## @examples
## o <- make_file_funs("myfile")
## ## Test against stored RDS
## # o$rds_save(my_fun(), "my_fun_out")            # previously stored value
## all.equal(my_fun(), o$rds("my_fun_out"))

make_file_funs <- function(name, obj.dir=file.path("_helper", "objs")) {
  list(
    rds=
      function(x)
        readRDS(file.path(obj.dir, name, sprintf("%s.rds", x))),
    rds_save=
      function(x, i)
        saveRDS(
          x,
          file.path(obj.dir, name, sprintf("%s.rds", i)), version=2
        ),
    txt=
      function(x)
        readLines(file.path(obj.dir, name, sprintf("%s.txt", x))),
    txt_save=
      function(x, i)
        writeLines(
          x,
          file.path(obj.dir, NAME, sprintf("%s.txt", i))
        )
  )
}

