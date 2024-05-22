#' Internal function to calculate Fleiss' Kappa for a single matrix
#'
#' This function calculates Fleiss' Kappa for a given matrix of annotations.
#'
#' @param matrix_data A matrix of annotation data.
#' @return A list with the Fleiss' Kappa value, z statistic, and p-value.
#' @importFrom irr kappam.fleiss
#' @noRd
.fleiss_kappa <- function(matrix_data) {
  kappa_result <- irr::kappam.fleiss(matrix_data)
  list(
    kappa = round(kappa_result$value, 3),
    z = round(kappa_result$statistic, 1),
    p_value = round(kappa_result$p.value, 5)
  )
}

#' Calculate Agreement Metrics for Variables Extracted by Annotators
#'
#' This function calculates various agreement metrics, including Fleiss' Kappa,
#' for variables extracted by multiple annotators. It summarizes the results
#' and provides consensus rates and other relevant statistics.
#'
#' @param x A data.frame or data.table containing the extracted variables
#' with columns for 'pmid', 'annotator_id', and the specified variable columns.
#' @param cols A character vector specifying the columns to be used for variable
#' extraction.
#' @param consensus_threshold A numeric value indicating the threshold for consensus
#' rate. Defaults to 0.6.
#' @return A data.table containing the agreement metrics, including Fleiss' Kappa,
#' consensus rates, and other summary statistics for each PMID.
#' @import data.table
#' @importFrom irr kappam.fleiss
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
#' result <- cmd_calc_agreement(variables, cols)
#' print(result)
#' @export

cmd_calc_agreement <- function(x, cols, consensus_threshold = 0.6) {
  # Convert to data.table and remove duplicates
  variables <- unique(data.table::as.data.table(x))
  
  # Ensure 'pmid' is present in the data
  if (!"pmid" %in% colnames(variables)) {
    stop("The input data must contain a 'pmid' column.")
  }
  
  # Ensure required columns are present
  required_cols <- c("pmid", "annotator_id", cols)
  missing_cols <- setdiff(required_cols, colnames(variables))
  if (length(missing_cols) > 0) {
    stop("The input data is missing the following required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # Text normalization: Convert to uppercase and remove parentheses
  for (col in cols) {
    variables[, (col) := toupper(gsub(' \\(.*\\)', '', get(col)))]
  }
  
  # Calculate the number of variables extracted by annotator for a given PMID
  variables[, n_vars := .N, by = .(pmid, annotator_id)]
  
  # Calculate the number of annotators per pmid
  variables[, annotators := data.table::uniqueN(annotator_id), by = pmid]
  
  # Combine specified columns into a single variable for frequency calculation
  variables[, variable_combined := do.call(paste, .SD), .SDcols = cols]
  
  # Calculate the frequency of each variable across annotations
  variables[, var_freq := .N, by = .(pmid, variable_combined)]
  variables[, var_consensus := round(var_freq / annotators, 2), by = .(pmid, variable_combined)]
  
  # Calculate the consensus rate for each annotation
  variables[, n_vars_cons := sum(var_consensus >= consensus_threshold), by = .(pmid, annotator_id)]
  variables[, rate_consensus := round(n_vars_cons / n_vars, 2), by = .(pmid, annotator_id)]
  
  # Summarize the results for each pmid
  summary_stats <- variables[, .(
    annotators = mean(annotators),
    type = length(unique(variable_combined)),
    token = .N,
    min_vars = min(n_vars),
    max_vars = max(n_vars),
    mean_vars = round(mean(n_vars), 1),
    rate_consensus = round(mean(rate_consensus), 3),
    n_consensus_vars = length(unique(variable_combined[var_consensus >= consensus_threshold]))
  ), by = pmid]
  
  # Create a binary pivot table for each pmid and the specified columns
  pivot_data <- dcast(unique(variables[, .(pmid, annotator_id, variable_combined)]),
                      pmid + variable_combined ~ annotator_id, 
                      value.var = "variable_combined", fun.aggregate = function(x) as.integer(length(x) > 0), fill = 0)
  
  # Split pivot_data into a list of matrices per pmid
  pivot_list <- split(pivot_data, by = "pmid")
  
  # Calculate Fleiss' Kappa for each pmid and store the results in a list
  kappa_results <- lapply(pivot_list, function(df) {
    matrix_data <- as.matrix(df[, -c("pmid", "variable_combined"), with = FALSE])
    matrix_data <- matrix_data[, colSums(matrix_data) > 0, drop = FALSE]
    
    kappa_info <- .fleiss_kappa(matrix_data)
    c(pmid = df$pmid[1], kappa_info)
  })
  
  # Convert list of results into a data.table
  kappa_results_dt <- rbindlist(kappa_results)
  
  # Merge the kappa results with summary statistics
  result <- merge(kappa_results_dt, summary_stats, by = "pmid")
  
  return(result)
}