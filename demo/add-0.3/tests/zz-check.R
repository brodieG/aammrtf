# Copyright (C) 2022 Brodie Gaslam

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

flist <- function(x, y) paste0(x, paste0("'", basename(y), "'", collapse=", "))
report <- function(x) {writeLines(character(13)); stop(x, call.=FALSE)}

test.out <- list.files(pattern="\\.Rout$")
if(any(lengths(lapply(test.out, tools::showNonASCIIfile))))
  warning(flist("Some test output files contain non-ASCII:\n", test.out))

targets <- list.files(pattern='\\.Rout\\.save', full.names=TRUE)
current <- file.path(dirname(targets), sub('\\.save$', '', basename(targets)))
missing <- !file.exists(current)

if(any(missing))
  report(flist("Test output files are missing (failed?):\n", current[missing]))

diff.dat <- Map(
  tools::Rdiff, targets[!missing], current[!missing], useDiff=TRUE, Log=TRUE
)
diffs <- vapply(diff.dat, '[[', 1, 'status')
if(any(!!diffs))
  report(flist("Test output files have differences:\n", current[!!diffs]))

