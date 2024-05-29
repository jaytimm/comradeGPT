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
                                                  'manual'), 
                                 variables = NULL,
                                 user_message = NULL, 
                                 system_message = NULL,
                                 cores = 5,
                                 annotators = 1,
                                 model = 'gpt-3.5-turbo') {
  
  # Create a data frame to hold pmid and repeated texts for each annotator
  text_df <- data.table::data.table(pmid = rep(pmid, annotators), 
                                    text = rep(text, annotators),
                                    variables = rep(variables, annotators))
  
  if (cores > 1) {
    # Setup a parallel cluster
    cl <- parallel::makeCluster(cores)
    
    # Export necessary variables to the cluster
    parallel::clusterExport(cl, 
                            varlist = c("user_message", 
                                        "system_message", 
                                        "model",
                                        "process_type"),
                            envir = environment())
    
    # Apply the function in parallel with a progress bar
    llm_output <- pbapply::pblapply(X = split(text_df, seq(nrow(text_df))), 
                                    FUN = function(row) .complete_chat1(row, 
                                                                        user_message, 
                                                                        system_message, 
                                                                        model,
                                                                        process_type), 
                                    cl = cl)
    
    # Stop the cluster
    parallel::stopCluster(cl)
  } else {

    # for_llm <- list() 
    # for(i in 2:10){
    # Sequential processing with a progress bar
    llm_output <- pbapply::pblapply(split(text_df, seq(nrow(text_df))), 
                                    function(row) .complete_chat1(row, 
                                                                  user_message, 
                                                                  system_message, 
                                                                  model,
                                                                  process_type))
  #   for_llm[[i]] <- llm_output
  #   print(i)
  }
  # 
  # llm_output <- unlist(for_llm, recursive = FALSE)
  #llm_output[3] <- NA
  # Generate random IDs for each element in llm_output
    
  names(llm_output) <- .generate_random_ids(length(llm_output))
  
  # # Process the output
  processed_list <- lapply(llm_output, function(element) {
    response_list <- jsonlite::fromJSON(element$response)
    response_df <- data.table::as.data.table(response_list)
    response_df[, pmid := element$pmid]
    return(response_df)
  })
  
  # Combine all data tables into a single data table
  
  #df <- data.table::rbindlist(processed_list, idcol = 'annotator_id', fill=TRUE)
  df <- llm_output
  
  
  # # Melt the data.table to long format
  if(process_type == 'extract_attributes'){

    df <- data.table::melt(df,
                           id.vars = c("pmid",
                                       "annotator_id",
                                       "variable_name",
                                       "variable_type"),

                          measure.vars = c("Construct",
                                           "Variable_Concept_Category",
                                           "Source_Terminology",
                                           "Codes",
                                           "Timing_Logic",
                                           "Complexity_Indicator",
                                           "Complex_Definition",
                                           "Data_Type",
                                           "Ascertainment_Source",
                                           "Ascertainment_Notes"))
  }
  # 

  
  
  
  return(df)
}
