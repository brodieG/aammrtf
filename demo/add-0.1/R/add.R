add <- function(x, y) {
  if(!is.numeric(x)) warning("`x` is not numeric, will attempt to coerce.")
  if(!is.numeric(y)) warning("`y` is not numeric, will attempt to coerce.")
  if(!suppressWarnings(is.numeric(x)|| !is.na(as.numeric(x))))
    stop("`x` cannot be interpreted as a number")
  if(!suppressWarnings(is.numeric(y)|| !is.na(as.numeric(y))))
    stop("`y` cannot be interpreted as a number")
  as.numeric(x) + as.numeric(y)
}
