#' Process Document
#'
#' Processes a document using various types of extraction and classification.
#'
#' @param pmid A character string specifying the PubMed ID.
#' @param text The text of the document to be processed.
#' @param process_type A character vector specifying the type of processing to be done.
#' @param variables A character vector of variables, if needed.
#' @param user_message A character string specifying the user message.
#' @param system_message A character string specifying the system message.
#' @param cores An integer specifying the number of cores to use for parallel processing.
#' @param annotators An integer specifying the number of annotators.
#' @param model A character string specifying the model to use.
#' @return A data table containing the processed results.
#' @export
#' @examples
#' \dontrun{
#' cmd_process_document(pmid = "12345678", 
#'                      text = "Sample text for processing.",
#'                      process_type = "classify_texts")
#' }

cmd_process_document <- function(pmid, 
                                 text,
                                 
                                 process_type = c('classify_texts',
                                                  
                                                  'extract_summary',
                                                  'extract_variables',
                                                  'extract_attributes',
                                                  'extract_popchars',
                                                  
                                                  'manual'
                                                  ## Table A
                                 ), 
                                 
                                 variables = NULL,
                                 
                                 user_message = NULL, 
                                 system_message = NULL,
                                 
                                 cores = 5,
                                 annotators = 1,
                                 model = 'gpt-3.5-turbo') {
  
  
  
  
  # Create a data frame to hold pmid and repeated texts for each annotator
  text_df <- data.table::data.table(pmid = rep(pmid, annotators), 
                                    text = rep(text, annotators))
  
  # Setup a parallel cluster
  cl <- parallel::makeCluster(cores)
  
  # Export necessary variables to the cluster
  parallel::clusterExport(cl, 
                          varlist = c("user_message", 
                                      "system_message", 
                                      "model",
                                      
                                      ## likely won't be necessary as package -- 
                                      # ".complete_chat1",
                                      # ".build_prompt",
                                      # ".openai_chat_completions",
                                      # ".is_valid_json",
                                      
                                      "process_type",
                                      "variables"),
                          envir = environment())
  
  # Apply the function in parallel with a progress bar
  llm_output <- pbapply::pblapply(X = split(text_df, seq(nrow(text_df))), 
                                  FUN = function(row) .complete_chat1(row, 
                                                                      user_message, 
                                                                      system_message, 
                                                                      model,
                                                                      process_type,
                                                                      variables), 
                                  cl = cl)
  
  # Stop the cluster
  parallel::stopCluster(cl)
  
  names(llm_output) <- .generate_random_ids(length(llm_output))
  
  processed_list <- lapply(llm_output, function(element) {
    response_list <- jsonlite::fromJSON(element$response)
    response_df <- data.table::as.data.table(response_list)
    response_df[, pmid := element$pmid]
    return(response_df)
  })
  
  # Combine all data tables into a single data table
  df <- data.table::rbindlist(processed_list, idcol = 'annotator_id')
  
  # df[, c('pmid',
  #        'annotator_id', 
  #        'variable_name', 
  #        'variable_type', 
  #        'explanation', 
  #        'mesh_descriptor')]
  
  return(df)
}
