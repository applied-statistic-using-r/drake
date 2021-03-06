#' @title Create a workflow plan data frame
#' for the \code{plan} argument of \code{\link{make}}.
#' @description Turns a named collection of target/command pairs into
#' a workflow plan data frame for \code{\link{make}()} and
#' \code{\link{check}()}. You can give the commands
#' as named expressions, or you can use the \code{list}
#' argument to supply them as character strings.
#' @details A workflow plan data frame is a data frame
#' with a \code{target} column and a \code{command} column.
#' Targets are the objects and files that drake generates,
#' and commands are the pieces of R code that produce them.
#'
#' For file inputs and targets, drake uses single quotes.
#' Double quotes are reserved for ordinary strings.
#' The distinction is important because drake thinks about
#' how files, objects, targets, etc. depend on each other.
#' Quotes in the \code{list} argument are left alone,
#' but R messes with quotes when it parses the free-form
#' arguments in \code{...}, so use the \code{strings_in_dots}
#' argument to control the quoting in \code{...}.
#' @export
#' @return A data frame of targets and commands.
#' @param ... A collection of symbols/targets
#' with commands assigned to them. See the examples for details.
#' @param list A named list of targets, where the values
#' are commands.
#' @param file_targets logical, whether the targets should be
#' (single-quoted) external file targets.
#' @param strings_in_dots Character scalar,
#' how to treat quoted character strings in the commands
#' specified through \code{...}.
#' Set to \code{"filenames"} to treat all these strings as
#' external file targets/imports (single-quoted),
#' or to \code{"literals"} to treat them all as literal
#' strings (double-quoted).
#' Unfortunately, because of how R deparses code,
#' you cannot simply leave literal quotes alone in the
#' \code{...} argument. R will either convert all these quotes
#' to single quotes or double quotes. Literal quotes in the
#' \code{list} argument are left alone.
#' @examples
#' # Create example workflow plan data frames for make()
#' drake_plan(small = simulate(5), large = simulate(50))
#' # Commands can be multi-line code chunks.
#' small_plan <- drake_plan(
#'   small_target = {
#'     local_object <- 1 + 1
#'     2 + sqrt(local_object)
#'   }
#' )
#' small_plan
#' \dontrun{
#' make(small_plan)
#' cached()
#' readd(small_target)
#' # local_object only applies to the code chunk.
#' ls() # your environment is protected (local_object not found)
#' }
#' # For tighter control over commands, use the `list` argument.
#' drake_plan(list = c(x = "1 + 1", y = "sqrt(x)"))
#' # This becomes important for file targets,
#' # which you must put in single quotes.
#' # (Double quotes are for string literals.)
#' drake_plan(data = readRDS("my_data.rds"))
#' drake_plan(my_file.rds = saveRDS(1+1, "my_file.rds"), file_targets = TRUE,
#'   strings_in_dots = "literals")
drake_plan <- function(
  ...,
  list = character(0),
  file_targets = FALSE,
  strings_in_dots = c("filenames", "literals")
){
  strings_in_dots <- match.arg(strings_in_dots)
  dots <- match.call(expand.dots = FALSE)$...
  commands_dots <- lapply(dots, wide_deparse)
  names(commands_dots) <- names(dots)
  commands <- c(commands_dots, list)
  targets <- names(commands)
  commands <- as.character(commands)
  if (!length(commands)){
    return(
      data.frame(
        target = character(0),
        command = character(0)
      )
    )
  }
  plan <- data.frame(
    target = targets,
    command = commands,
    stringsAsFactors = FALSE
  )
  from_dots <- plan$target %in% names(commands_dots)
  if (file_targets){
    plan$target <- drake::drake_quotes(plan$target, single = TRUE)
  }
  if (strings_in_dots == "filenames"){
    plan$command[from_dots] <- gsub("\"", "'", plan$command[from_dots])
  }
  sanitize_plan(plan)
}

drake_plan_override <- function(target, field, config){
  in_plan <- config$plan[[field]]
  if (is.null(in_plan)){
    return(config[[field]])
  } else {
    return(in_plan[config$plan$target == target])
  }
}
