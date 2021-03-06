#' Impute Numeric Data Below the Threshold of Measurement
#'
#' `step_lowerimpute` creates a *specification* of a recipe step
#'  designed for cases where the non-negative numeric data cannot be
#'  measured below a known value. In these cases, one method for
#'  imputing the data is to substitute the truncated value by a
#'  random uniform number between zero and the truncation point.
#'
#' @inheritParams step_center
#' @param ... One or more selector functions to choose which
#'  variables are affected by the step. See [selections()]
#'  for more details. For the `tidy` method, these are not
#'  currently used.
#' @param role Not used by this step since no new variables are
#'  created.
#' @param threshold A named numeric vector of lower bounds This is
#'  `NULL` until computed by [prep.recipe()].
#' @return An updated version of `recipe` with the new step
#'  added to the sequence of existing steps (if any). For the
#'  `tidy` method, a tibble with columns `terms` (the
#'  selectors or variables selected) and `value` for the estimated
#'  threshold.
#' @keywords datagen
#' @concept preprocessing imputation
#' @export
#' @details `step_lowerimpute` estimates the variable minimums
#'  from the data used in the `training` argument of `prep.recipe`.
#'  `bake.recipe` then simulates a value for any data at the minimum
#'  with a random uniform value between zero and the minimum.
#' @examples
#' library(recipes)
#' data(biomass)
#' 
#' ## Truncate some values to emulate what a lower limit of
#' ## the measurement system might look like
#' 
#' biomass$carbon <- ifelse(biomass$carbon > 40, biomass$carbon, 40)
#' biomass$hydrogen <- ifelse(biomass$hydrogen > 5, biomass$carbon, 5)
#' 
#' biomass_tr <- biomass[biomass$dataset == "Training",]
#' biomass_te <- biomass[biomass$dataset == "Testing",]
#' 
#' rec <- recipe(HHV ~ carbon + hydrogen + oxygen + nitrogen + sulfur,
#'               data = biomass_tr)
#' 
#' impute_rec <- rec %>%
#'   step_lowerimpute(carbon, hydrogen)
#' 
#' tidy(impute_rec, number = 1)
#' 
#' impute_rec <- prep(impute_rec, training = biomass_tr)
#' 
#' tidy(impute_rec, number = 1)
#' 
#' transformed_te <- bake(impute_rec, biomass_te)
#' 
#' plot(transformed_te$carbon, biomass_te$carbon,
#'      xlab = "pre-imputation", ylab = "imputed")


step_lowerimpute <-
  function(recipe,
           ...,
           role = NA,
           trained = FALSE,
           threshold = NULL,
           skip = FALSE) {
    add_step(
      recipe,
      step_lowerimpute_new(
        terms = check_ellipses(...),
        role = role,
        trained = trained,
        threshold = threshold,
        skip = skip
      )
    )
  }

step_lowerimpute_new <-
  function(terms = NULL,
           role = NA,
           trained = FALSE,
           threshold = NULL,
           skip = FALSE) {
    step(
      subclass = "lowerimpute",
      terms = terms,
      role = role,
      trained = trained,
      threshold = threshold,
      skip = skip
    )
  }

#' @export
prep.step_lowerimpute <- function(x, training, info = NULL, ...) {
  col_names <- terms_select(x$terms, info = info)
  if (any(info$type[info$variable %in% col_names] != "numeric"))
    stop("All variables for mean imputation should be numeric")
  threshold <-
    vapply(training[, col_names],
           min,
           numeric(1),
           na.rm = TRUE)
  if (any(threshold < 0))
    stop(
      "Some columns have negative values. Lower bound ",
      "imputation is intended for data bounded at zero.",
      call. = FALSE
    )
  step_lowerimpute_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    threshold = threshold,
    skip = x$skip
  )
}

#' @export
bake.step_lowerimpute <- function(object, newdata, ...) {
  for (i in names(object$threshold)) {
    affected <- which(newdata[[i]] <= object$threshold[[i]])
    if (length(affected) > 0)
      newdata[[i]][affected] <- runif(length(affected),
                                      max = object$threshold[[i]])
  }
  as_tibble(newdata)
}

print.step_lowerimpute <-
  function(x, width = max(20, options()$width - 30), ...) {
    cat("Lower Bound Imputation for ", sep = "")
    printer(names(x$threshold), x$terms, x$trained, width = width)
    invisible(x)
  }

#' @rdname step_lowerimpute
#' @param x A `step_lowerimpute` object.
tidy.step_lowerimpute <- function(x, ...) {
  if (is_trained(x)) {
    res <- tibble(terms = names(x$threshold),
                  value = x$threshold)
  } else {
    term_names <- sel2char(x$terms)
    res <- tibble(terms = term_names, value = na_dbl)
  }
  res
}

#' @importFrom stats runif
utils::globalVariables(c("estimate"))