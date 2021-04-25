# An Almost Most Minimal R Test Framework

## Overview

R comes with a built-in testing framework that consists of putting tests scripts
in the "tests" sub-folder of a package.  These are run by `R CMD check` and test
fail if they trigger and error e.g. via an unsatisfied `stopifnot` statement.

R will also compare the output produced by the test to a previously saved
version if it is provided.  This is purely informative as output differences are
displayed, but do not cause the tests to fail.

We find that forcing failure on output differences turns the built-in tools into
an effective "snapshot" testing framework.  Target applications are those that
prioritize a minimal dependency footprint, but are unwilling to go as far as
turning every test into a `stopifnot` predicate.

## Implementation

R automatically records the output of every test file run via `R CMD check` in
the resulting check folder as ".Rout" files.  These files can be [copied
back](#step-by-step-example) into the test folder as ".Rout.save" files.

Once the reference files are in the tests folder, adding the ["zz-check.R"][1]
file in this repository to the same folder will cause tests to fail if future
output differs from that recorded in the ".Rout.save" files.

That's it.

This is what the "tests" folder of an imagined `{add}` package with one test
file ("test-add.R") will look like:

```
$ ls add/tests
test-add.R              test-add.Rout.save      zz-check.R
```

## Installation

The only requirement is to copy the "zz-check.R" into the "tests" directory of
your package, e.g. for `{add}` we might use:

```
$ curl https://raw.githubusercontent.com/brodieG/aammrtf/master/zz-check.R >\
     add/tests/zz-check.R
```

Internally `R CMD check` will list files to test with `dir`, which orders them
alphabetically.  It is possible such ordering will be affected by locale
collation, so you should ensure your test files are named in such a way that the
"zz-check.R" file always sorts last.  Alternatively, rename "zz-check.R" to
produce the same affect.  It is likely safest to use ASCII only same-case file
names.

## Step by Step Example

Suppose "add/tests/test-add.R" contains:

```{r}
library(add)
add(1, 2)
all.equal(add(pi, 1), 4.141592654)
all.equal(add(pi, "1"), 4.141592654)
try(add("pi", 1))
```

These test normal usage, but also warning and error cases.  We have installed
copied over "zz-check.R", but do not have our ".Rout.save" file:

```
$ ls add/tests/
test-add.R      zz-check.R
```

The next step is to run `R CMD check`.  From the terminal.

```
$ cd add
$ R CMD build .                    # builds add_0.0.1.tar.gz
$ R CMD check add_0.0.1.tar.gz
* using R Under development (unstable) (2021-03-31 r80136)

<--SNIP-->

* DONE
Status: OK
```

We gain the "add.Rcheck" folder with the artifacts from the R CMD check run:

```
$ ls
DESCRIPTION             add.Rcheck              tests
NAMESPACE               add_0.0.1.tar.gz
R                       man

$ ls add.Rcheck/tests
startup.Rs      test-add.R      test-add.Rout
```

"test-add.Rout" contains the output from running "test-add.R" (redacted for
clarity):

```
$ cat add.Rcheck/tests/test-add.Rout

<-- SNIP -->

> library(add)
> add(1, 2)
[1] 3
> all.equal(add(pi, "1"), 4.141592654)
[1] TRUE
Warning message:
In add(pi, "1") : `y` is not numeric, will attempt to coerce.
> try(add("pi", 1))
Error in add("pi", 1) : `x` cannot be interpreted as a number
In addition: Warning message:
In add("pi", 1) : `x` is not numeric, will attempt to coerce.

<-- SNIP -->
```

The trick is to copy back into our package test directory as a ".Rout.save":

```
$ cp add.Rcheck/tests/test-add.Rout \
     tests/test-add.Rout.save

$ ls tests
test-add.R              test-add.Rout.save      zz-check.R
```

If we introduce a regression in our next version then we might see:

```
$ R CMD check add_0.0.2.tar.gz
* using R Under development (unstable) (2021-03-31 r80136)

<--SNIP-->

  Running ‘test-add.R’
  Comparing ‘test-add.Rout’ to ‘test-add.Rout.save’ ...5c5
< [1] -1
---
> [1] 3
7c7
< [1] "Mean relative difference: 0.9338844"
---
> [1] TRUE
  Running ‘zz-check.R’
 ERROR
Running the tests in ‘tests/zz-check.R’ failed.
Last 13 lines of output:

<--SNIP-->

  Error: Test output files have differences:
  'test-add.Rout'
  Execution halted
* checking PDF version of manual ... OK
* DONE

Status: 1 ERROR
```

The `R CMD check` output shows that `1 + 2` has become `-1` instead of `3`, etc.
See [Interpreting Output](#interpreting-output) for details.

## Snapshot Testing

Instead of declaring explicit expectations we simply record prior output and
make that the expectation.  This will catch changes in values, and also changes
in warnings, errors, and anything else you would observe from terminal output.
Doing all of this with `stopifnot` and predicates would be tedious.

In some cases we might prefer traditional predicate tests, e.g. to avoid
vagaries of precision as we did with:

```
all.equal(add(pi, "1"), 4.141592654)
```

Even though this is still technically a snapshot test against:

```
[1] TRUE
```

For all intents and purposes it behaves like a traditional predicate test.
Similarly, large outputs can be compared against stored objects, etc.

If we are reckless about our tests, e.g. by displaying very high levels of
precision or other things that are likely to vary across test systems, we might
trigger false positive failures.  This might be the reason why R Core chose not
to let output differences fail tests.

Some possible mitigation strategies:

* Wrap sensitive tests in functions such as `all.equal` that reduce the result
  to a single TRUE value.
* Use `zapsmall` or similar to reduce precision issues with numerics.
* Try to stick to ASCII output in tests if you can.  If you are testing
  functionality that requires non-ASCII output, test the strings directly
  against stored values or similar rather than letting them go to output.
* Avoid dates, unseeded random numbers, file paths, etc., in the output.

## Tips And Tricks

### Interpreting Output

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
from:

```
  Comparing ‘test-add.Rout’ (<) to ‘test-add.Rout.save’ (>) ...5c5
```

One "gotcha" is that the diff is run after the typical R intro banner is removed
from the output.  So in reality line 5 is really line 20 in the ".Rout" file.

The default R diff does not provide much context, but it is easy enough to get
more with your favorite diff, e.g.:

```
$ git diff --no-index add.Rcheck/tests/test-add.Rout*
```

### Without R CMD check

`R CMD check` does a lot of things that we don't need during the development
cycle prior to CRAN submission.  A shortcut is to set the working directory to
the "tests" folder and running:

```{r}
tools:::.runPackageTests()
```

This will create the ".Rout" files directly in the test folder, along with some
other artifacts.

Of course this is an unexported function intended to run within the `R CMD
check` folder, so we are taking some risks for the convenience.

If you just want to run a single file you can always use something like (after
installing the package):

```
$ R --vanilla -f tests/test-add.R &> tests/test-add.Rout
$ git diff --no-index tests/test-add.Rout*
```

## Why? Does It Work In Practice?

I migrated `{diffobj}` to this test framework for three reasons:

1. `{diffobj}` became a dependency to `{testthat}`, and I don't like the idea of
   circular dependencies, even if they are only of the "suggests" variety.
2. Over the years I've grown increasingly frustrated with even build/test time
   dependencies.
3. To see if it could be done and be useful.

I'm usually picky with run time dependencies, but more recently decided that
build/test time dependencies are also problematic.  I like test on R-devel on
underpowered VMs without having to wait forever for packages to download and
compile, or without dealing with missing system dependencies, or figuring out
why one of the twenty packages isn't installing, or narrowing down what changed
to break my code, etc.

Features grow linearly with dependencies, but the agony of stuff not working
grows exponentially with them.

`{diffobj}` has hundreds of tests covering close to four thousand lines of code.
After migration I ran the tests back to R 3.3, which is now over four years old.
Over the different R versions since I only found one false positive issue due to
output changing spuriously.  There were many more false positives due to other
changes (e.g. random seed changes with R 3.5, `stringAsFactors`, `{testthat}`
changes, etc.), so provided one takes care to avoid the obvious sources of
spurious FALSE positives I would expect them to be rare.

`{diffobj}` has been on CRAN with this test framework for over three
months now, including one maintenance update.  So far I'm very satisfied.

## Related Software

* [`{unitizer}`](https://github.com/brodieG/unitizer) for a full-featured
  low-dependency snapshot testing framework.
* [`{tinytest}`](https://github.com/markvanderloo/tinytest/tree/master/pkg) for
  a zero dependency (other than the package itself) test framework, extended by
  [`{ttdo}`](https://github.com/eddelbuettel/ttdo) to add `{diffobj}` diffs.
* [`{testthat}`](https://testthat.r-lib.org/).
* [`{runit}`](https://cran.r-project.org/web/packages/RUnit/index.html).

Full disclosure: I wrote `{unitizer}`.  I don't use it for `{diffobj}` because
it uses `{diffobj}`, and I really don't like circular dependencies /
bootstrapping.

## Acknowledgments

* R Core for developing and maintaining such a wonderful language.
* All open source developers out there that make their work freely available
  for others to use.
* [Github](https://github.com/), [Travis-CI](https://travis-ci.org/),
  [Codecov](https://about.codecov.io/), [Vagrant](https://www.vagrantup.com/),
  [Docker](https://www.docker.com/), [Ubuntu](https://www.ubuntu.com/),
  [Brew](https://brew.sh/) for providing infrastructure that greatly simplifies
  open source development.
* [Free Software Foundation](https://www.fsf.org/) for developing the GPL
  license and promotion of the free software movement.


[1]: https://github.com/brodieG/aammrtf/blob/master/zz-check.R
