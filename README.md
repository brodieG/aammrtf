# An Almost Most Minimal R Test Framework

Ultra-lightweight snapshot testing for R packages.

## Background

R provides built-in facilities for testing R packages.  R scripts in the "tests"
package subfolder are run as part of `R CMD check`, and any errors therein
cause the checks to fail.  Third party testing frameworks use this mechanism to
launch themselves and run tests.

A more obscure feature is that R captures test outputs, **and** computes
diffs against user-saved outputs from prior runs.  Differences alone do not fail
tests.  `aammrtf` changes this, which effectively adds snapshot test capability
to the built-in tools.  There are [caveats](#caveats) you should familiarize
yourself with prior to using `aammrtf`.

In its most basic form, `aammrtf` is a thirteen line script.

## Snapshot Testing

### What Is It?

Meaningful tests of user-level functionality produce non-trivial outputs.
Snapshots make it easy to test for regressions in them.  For example, to test a
function that transposes matrices with traditional assertions we might use:

```{r}
input <- matrix(1:6, nrow=2)
stopifnot(
  identical(
    transpose(input),
    matrix(c(1L, 3L, 5L, 2L, 4L, 6L), ncol=2)
) )
```

That's a lot of typing / copy pasting to write a test.  Instead, in `aammrtf`
snapshot testing the test is:

```{r}
input <- matrix(1:6, nrow=2)
transpose(input)
```

Multiply this difference by the need to test square matrices, empty matrices,
numeric matrices, other matrix functions, etc., and quickly the simplicity of
the snapshot test becomes very appealing.

The output of the test is automatically recorded, and the test along with its
output together become the snapshot test.  The user is responsible for output
review to ensure correctness.

My packages have large test suites reaching 100% or near 100% coverage over
thousands of lines of code, primarily with snapshot tests.  I've found
creation and maintenance of snapshots a delight in contrast to doing the same
with assertions.

Snapshot test maintenance is as simple as running a diff between the recorded
output and new output.  It is easy to verify correctness of changes, and
trivial to update the tests with them.

`aammrtf` is my second snapshot-centric test "framework".  I've also written
[`{unitizer}`][2], a full featured snapshot test package that I've used for
several years.  However, I needed `aammrtf` for `{unitizer}`'s own tests, and
also for [`{diffobj}`][7], which `{unitizer}` depends on.

There are [caveats](#caveats) to snapshot-first testing, but since assertion
tests are a special case of snapshot tests (implicitly a snapshot of the
assertion returning TRUE), we can always fall back to assertion tests for cases
where snapshots are impractical.

### Best Practices

Snapshots tests are most effective when the outputs are as small as you can make
them while still capturing the complexity of the functions being tested.  The
[`transpose` example](#what-is-it) used the smallest non-square matrix with more
than one row and column.

One of the dangers of snapshot tests is that it is easy to automatically record
larger than needed outputs.  These become difficult to interpret when they
change later, and might cause future maintainers to overwrite reference output
without fully understanding the changes.

Tests for which the result is not completely self-evident should be documented
with comments, possibly with one general comment for a section of related tests.

## Installation / Quick Start

Installation is to copy some files from this repository into the tests folder of
your package.  First check that you don't have pre-existing "zz-check.R" or
"aammrtf" files.  Then, for a minimal install, copy "aammrtf/check.R" into the
package "tests" folder.  E.g. for the imaginary `{add}` package we might use:

```
cd add/test
curl -L https://raw.githubusercontent.com/brodieG/aammrtf/master/aammrtf/check.R > zz-check.R
```

For helper scripts and cleaner error reporting copy the entire "aammrtf"
directory (still in the tests subdirectory):

```
curl -L https://github.com/brodieG/aammrtf/archive/refs/heads/master.zip \
  -o aammrtf.zip &&                                                      \
  unzip -j aammrtf.zip 'aammrtf-master/aammrtf/*' -d aammrtf &&          \
  mv aammrtf/check-0.R zz-check.R &&                                     \
  rm aammrtf.zip
```

Once installed, add tests files to the `"tests"` package subdirectory along with
matching `".Rout.save"` files with the output of running the test files.  Read
on for more details.

> `aammrtf` will never be a CRAN package.  It is small enough to embed in
> packages.

To re-install, delete previously installed files and repeat the installation
step.

## Basic Usage

Let's illustrate with our demo package `{add}`, which implements `add` to add
two vectors.  `{add}` includes a test script in the `"tests"` subdirectory:

```
cd add/tests
ls
## test-add.R   zz-check.R
```
```
cat test-add.R
## library(add)
## add(1, 2)
```

We generate the snapshot with:

```
R CMD BATCH --vanilla --no-timing test-add.R
```

Which creates or overwrites `"test-add.Rout"`:

```
ls
## test-add.R   test-add.Rout   zz-check.R
cat test-add.Rout                # R startup banner omitted for clarity
## > library(add)
## > add(1, 2)
## [1] 3                         # <--- Output!
```

If the output is as expected we rename it to `"test-add.Rout.save"` so that
`R CMD check` will use it as reference output:

```
mv test-add.Rout{,.save}
ls
## test-add.R   test-add.Rout.save   zz-check.R
```

Any future runs of `R CMD check` for our package will detect and report
regressions.  Suppose we mess up our function in a refactor, then we might see:

```
R CMD check add-0.2.tar.gz
## * using R Under development (unstable) (2021-07-17 r80639)
## <SNIP>
## * checking tests ...
##   Running ‘test-add.R’
##   Comparing ‘test-add.Rout’ to ‘test-add.Rout.save’ ...5c5
## < [1] -1
## ---
## > [1] 3
##   Running ‘zz-check.R’
##  ERROR
## Running the tests in ‘tests/zz-check.R’ failed.
## Last 13 lines of output:
##   Error: Test output files have differences:
##   'test-add.Rout'
##   Execution halted
## * checking PDF version of manual ... OK
## * DONE
##
## Status: 1 ERROR
```

The `R CMD check` output shows that `add(1, 2)` has become `-1` instead of `3`.
See [Interpreting Output](#interpreting-the-diff)  for tips on how to understand
what `R CMD check` is telling us.  In practice it is inconvenient to run `R CMD
check` during an iterative development cycle, and we'll see later [how to avoid
it](#without-r-cmd-check).

## Everything is a Test

The beauty of `aammrtf` snapshot testing is we (mostly) just write code as we
would in a normal script and everything is tested implicitly.  Testing for
warning or error messages doesn't require any special functions.

After fixing our earlier regression, we add tests that are expected to produce
warnings and errors:

```
cat test-add.R
## library(add)
## add(1, 2)
## all.equal(add(pi, "1"), 4.141592654)   # WARNING
## try(add("pi", 1))                      # ERROR
```
```
R CMD BATCH --vanilla --no-timing test-add.R
cat test-add.Rout         # output redacted for clarity
## > library(add)
## > add(1, 2)
## [1] 3
## > all.equal(add(pi, "1"), 4.141592654)   # WARNING
## [1] TRUE
## Warning message:
## In add(pi, "1") : `y` is not numeric, will attempt to coerce.
## > try(add("pi", 1))                      # ERROR
## Error in add("pi", 1) : `x` cannot be interpreted as a number
## In addition: Warning message:
## In add("pi", 1) : `x` is not numeric, will attempt to coerce.
```

We wrap expressions expected to cause errors in `try` so that the script
succeeds, but otherwise this could be the transcript of an interactive session
at the prompt.

## Caveats

R does not document why differences with `".Rout.save"` are not errors for
packages, but we infer it is to avoid spurious failures.  Indeed relying on
screen output is a double edged sword.  It saves us a lot of work when writing
the tests, but we must both visually review the results **and** take care to
avoid spurious failures.

> A significant but unlikely-to-occur risk is that R irreversibly changes a
> fundamental aspect of display of outputs, such as how vector indices are
> displayed, etc..  Be wary of output from 3rd party packages that may not be as
> stable as that of base R.

You'll notice we use `all.equal` around the `pi` test above, this is to avoid
spurious mismatches caused by small changes in the display of numeric values
with many decimal digits.  `zapsmall` can help with values that are intended to
be close to zero.

Other things to watch out for include:

* Translations of Error/Warning messages.
* Errors/Warnings from R itself or other packages (these could change).
* Errors/Warnings emitted from C-level R facilities (these currently change
  whether the call is displayed depending on whether the corresponding R
  entry-point is byte compiled or not - I believe this to be a bug).
* Output of characters in locales that do not support them.
* Output that could be inconsistent across sessions such as timestamps, package
  versions, etc..
* Options that affect display that change with locale, interactive status, or
  other factors (e.g `useFancyQuotes`, `crayon.enabled`, etc.).

See also the subsection on tests of the ["Writing Portable Packages" section in
WRE][13], as well as the documentation for `tools::Rdiff` which `R CMD check`
uses to remove some obvious sources of differences such as environment
addresses, the R startup banner, etc..

> R does fail a curated set of its own internal tests if their output does not
> match the recorded file.  Implicit in this is the concern that package authors
> will be too careless to avoid spurious failures.  Be sure to prove them wrong
> if you go down this road.

It would be better to compare values directly instead of their output to screen,
but doing so is far more involved (see [`unitizer`][2] for a snapshot framework
based on object values).

We also rely on `R CMD check` to run tests in lexical order so that
`"zz-check.R"` runs last.  Internally `R CMD check` uses `base::dir` which is
documented to do this, but it is not documented that `R CMD check` uses `dir`.
ASCII-only and lower case file names are safest to avoid any locale/collation
issues.

The solution to these issues is to recast "risky" expressions so they will
produce safe output (e.g. as with `all.equal`), and to preset options that could
cause issues.  For example, if you work in a non-English locale you might use
(`R CMD check` does this):

```
LANGAUGE=en R CMD BATCH ...
```

It may be helpful to include a  script in all tests files with common settings
that help with reproducibility.  For example `"test-add.R"` seen earlier might
become:

```
cat test-add.R
## source('aammrtf/init.R')     # <-- Source "init.R" file.
## library(add)
## add(1, 2)
```

The default [`"init.R"` file][10] sets a few options.  If you wish to add more
copy the file to a different location (so that it survives a re-install of
`aammrtf`), modify it, and source that one.

Finally, recall `aammrtf` is a thirteen line script.  Many features you may be
used to from other testing frameworks are missing, but they are secondary
features.

In practice `aammrtf` has worked well for me.  I've had `{diffobj}` on CRAN with
`aammrtf`-style tests since January 2021, and `{unitizer}` since August 2021.
`{diffobj}` and `{unitizer}` each have hundreds of tests covering thousands of
lines of code.  After the `{diffobj}` migration to `aammrtf` I ran its tests
back to R 3.3.3 (March 2017).  Over the different R versions I only found one
false positive issue due to output changing spuriously.  There were many more
false positives due to other changes (e.g. random seed changes with R 3.5,
`stringAsFactors`, changes to `{testthat}` or its dependencies, etc.), so
provided we take care to avoid the obvious sources of spurious errors I expect
them to be rare.

## Without R CMD check

During development we can use the following pattern:

```
cd tests
R CMD BATCH --vanilla --no-timing test-add.R
git diff --no-index -R tests/test-add.Rout*  # assuming a .Rout.save exists
```

This will re-run the tests and show any differences from the saved reference
file.  Some aliases might help:

```
alias rcb='R CMD BATCH --vanilla --no-timing'
alias gdni='git diff --no-index -R'
```

So the commands become:

```
rcb test-add.R
gdni test-add.Rout*
```

Within an R session, with the working directory set to the `"tests"` directory,
one can also use:

```{r}
tools:::.runPackageTests()
```

This will run **all** test files, create corresponding `".Rout"` files, compare
them to `".Rout.save"`, and produce `".Rout.fail"` files for tests that fail.
This is an un-exported function intended to run within R's own checking code,
the so you should only use during development with the understanding its
behavior or even existence could change without announcement in future R
versions.

> Stray `".Rout.fail"` files will cause the `gdni` alias we defined above to
> fail, so you will need to clean them up.

## Interpreting The Diff

This is a snippet from our failed test run earlier:

```
  Comparing ‘test-add.Rout’ to ‘test-add.Rout.save’ ...5c5
< [1] -1
---
> [1] 3
```

The `5c5` tells us that line 5 changed in both files. `< [1] -1` is from
'test-add.Rout', and `> [1] 3` from 'test-add.Rout.save'.  The `<` and the `>`
at the beginning of each line indicate whether it is from the left or right file
from the header:

```
  Comparing ‘test-add.Rout’ (<) to ‘test-add.Rout.save’ (>) ...5c5
```

One "gotcha" is that the diff is run after the typical R intro banner is removed
from the output.  So in reality line 5 is really line 20 in the `".Rout"` file.

Upon seeing one of these context-less errors in e.g. the CRAN `R CMD check`
output, you should open up the `".Rout.save"` file, navigate to the second
number in the location indicator (i.e. "5c**5**", so go to line five), skip
fifteen lines further, at which point you will see the context for the diff.
Ideally R would provide more context, but at the moment this is not an option.

## Not CRAN

I don't have a great solution for tests that should be run locally and on CI,
but not on CRAN.  The simplest approach is to forego snapshots, instead relying
on assertions e.g. with `stopifnot()` or similar to throw errors if tests fail.
Those tests can then be conditional on a `NOT_CRAN` environment variable as is
common practice with `{testthat}`:

```
cat test-not-cran.R
## if(!nzchar(Sys.getenv('NOT_CRAN'))) q()
## library(add)
## stopifnot(identical(add(1, 2), 3))
## ...
```

If you must absolutely have snapshots for these tests, an alternative is
is to put such tests in a file containing "not-cran" in its name, add
`"not-cran"` rule in the `".Rbuildignore"` file, and then remove it for local
tests / CI with e.g.:

```
cp .Rbuildignore{,.bak} &&                             \
  sed /not-cran/d .Rbuildignore.bak > .Rbuildignore && \
  R CMD BUILD . &&                                     \
  mv .Rbuildignore{.bak,}
```

This will cause tarballs built normally to exclude the "not-cran" files, but
will keep them if the build is carried as above.  As this requires remembering
to do the special build for local tests, and adds the risk of accidentally
submitting the wrong tarball to CRAN, it is probably best to implement this
pattern in a non-local CI.

## Extra Features

The `"aammrtf"` folder contains some additional functions that can be sourced
from within test files.

* ["ref.R"][12]: to facilitate storing reference output as "rds" or "txt" files.
  This is mostly to help transition assertion based tests that used reference
  output.  You should rarely need it with new snapshot tests.
* ["mock.R"][11]: for basic mocking functionality.
* ["init.R"][10]: for common code intended to be included in every test script.

You can [copy the `"aammrtf"`](#installation-quick-start) folder into your
project and source the files therein from test files that require the
functionality.

## Really, Why?

I migrated `{diffobj}` to this test framework for three reasons:

1. `{diffobj}` became a dependency to `{testthat}`, and I don't like the idea of
   circular dependencies, even if they are only of the "suggests" variety.
2. Over the years I've grown increasingly frustrated with even build/test time
   dependencies, both due to build overhead, but also the increased "surface
   area" exposed to breaking changes, intentional and otherwise.
3. To see if it could be done and be useful.

With `aammrtf` feasibility demonstrated by `{diffobj}`, it was only natural to
migrate `{unitizer}`, particularly because it was the only package that relied
on a "feature" of `{testthat}` that I had to rescue from deprecation twice (and
really probably should be deprecated).

## What's With The Name?

It's a phone book era SEO that gives the `aammrtf` folder a chance to
sort at the top of the file listing.  But mostly it's a bad joke that stuck.  It
might change in the future.

## Related Software

* [`{unitizer}`][2] for a full-featured low-dependency snapshot testing
  framework.
* [`{tinytest}`][3] for a zero dependency (other than the package itself)
  expectation based test framework, extended by [`{ttdo}`][4] to add
  [`{diffobj}`][7] diffs.
* [`{testthat}`][5].
* [`{RUnit}`][6].

Full disclosure: I wrote [`{unitizer}`][2].  I don't use it for [`{diffobj}`][7]
because it uses [`{diffobj}`][7], and I really don't like circular dependencies
/ bootstrapping.

If you are looking for an expectation based low-dependency package,
[`{tinytest}`][3] is likely the way to go.

## Acknowledgments

* R Core for developing and maintaining such a wonderful language.
* All open source developers out there that make their work freely available
  for others to use.
* [Github](https://github.com/), [Codecov](https://about.codecov.io/),
  [Vagrant](https://www.vagrantup.com/), [Docker](https://www.docker.com/),
  [Ubuntu](https://www.ubuntu.com/), [Brew](https://brew.sh/) for providing
  infrastructure that greatly simplifies open source development.
* [Free Software Foundation](https://www.fsf.org/) for developing the GPL
  license and promotion of the free software movement.


[1]: https://github.com/brodieG/aammrtf/blob/master/zz-check.R
[2]: https://github.com/brodieG/unitizer
[3]: https://github.com/markvanderloo/tinytest/tree/master/pkg
[4]: https://github.com/eddelbuettel/ttdo
[5]: https://testthat.r-lib.org/
[6]: https://cran.r-project.org/web/packages/RUnit/index.html
[7]: https://github.com/brodieG/diffobj
[8]: https://cran.r-project.org/doc/manuals/R-exts.html#Package-subdirectories
[9]: https://cran.r-project.org/doc/manuals/r-devel/R-exts.html#index-_002eRbuildignore-file
[10]: https://github.com/brodieG/aammrtf/blob/master/aammrtf/init.R
[11]: https://github.com/brodieG/aammrtf/blob/master/aammrtf/mock.R
[12]: https://github.com/brodieG/aammrtf/blob/master/aammrtf/ref.R
[13]: https://cran.r-project.org/doc/manuals/R-exts.html#Writing-portable-packages
