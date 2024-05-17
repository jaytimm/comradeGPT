#' Calculate Precision Metrics for Annotated Variables
#'
#' This function calculates precision metrics for variables extracted by multiple annotators. 
#' It normalizes the text, calculates the frequency of each variable, and computes the agreement rate.
#'
#' @param x A data.frame or data.table containing the extracted variables with columns for 'pmid', 'annotator_id', and the specified variable columns.
#' @param cols A character vector specifying the columns to be used for variable extraction.
#' @return A data.table containing the precision metrics, including the frequency of each variable and the agreement rate for each PMID.
#' @import data.table
#' @examples
#' library(data.table)
#' variables <- data.table(
#'   pmid = c(28817241, 28817241, 28817241, 28817241, 28817241, 28817241,
#'            28817242, 28817242, 28817242, 28817242, 28817242, 28817242),
#'   annotator_id = c("OSM5611", "OSM5611", "OSM5611", "OSM5611", "OSM5611", "OSM5611",
#'                    "OSM5611", "OSM5611", "OSM5611", "OSM5611", "OSM5611", "OSM5611"),
#'   variable_name = c("Heart Failure", "Vitamin D Deficiency", "Age", "Gender", 
#'                     "Education", "Ethnicity", "Diabetes", "Hypertension", 
#'                     "Age", "Gender", "Education", "Ethnicity"),
#'   variable_type = c("Outcome", "Exposure", "Covariate", "Covariate", "Covariate", 
#'                     "Covariate", "Outcome", "Exposure", "Covariate", "Covariate", 
#'                     "Covariate", "Covariate")
#' )
#' cols <- c("variable_name", "variable_type")
#' result <- cmd_calc_precision(variables, cols)
#' print(result)
#' @export
cmd_calc_precision <- function(x, cols) {
  # Ensure required columns are present
  required_cols <- c("pmid", "annotator_id", cols)
  missing_cols <- setdiff(required_cols, colnames(x))
  if (length(missing_cols) > 0) {
    stop("The input data is missing the following required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # Convert to data.table and remove duplicates
  variables <- unique(data.table::as.data.table(x))
  
  # Text normalization: Convert to uppercase and remove parentheses
  for (col in cols) {
    variables[, (col) := toupper(gsub(' \\(.*\\)', '', get(col)))]
  }
  
  # Calculate the number of annotators per pmid
  variables[, annotators := data.table::uniqueN(annotator_id), by = pmid]
  
  # Group by the specified columns and calculate frequency
  agg_data <- variables[, .(var_freq = .N), by = c("pmid", cols, "annotators")]
  
  # Calculate the agreement rate
  agg_data[, precision := var_freq / annotators]
  
  return(agg_data)
}
