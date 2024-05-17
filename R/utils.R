

.generate_random_ids <- function(n) {
  set.seed(123)  # Optional: for reproducibility
  alpha_part <- apply(matrix(sample(LETTERS, n * 3, replace = TRUE), nrow = n), 1, paste0, collapse = "")
  numeric_part <- sprintf("%04d", sample(1000:9999, n, replace = TRUE))
  paste0(alpha_part, numeric_part)
}



.openai_chat_completions <- function(model = 'gpt-3.5-turbo',
                                        #messages = NULL,
                                        
                                        system_message = '',
                                        user_message = '',
                                        
                                        temperature = 1,
                                        top_p = 1,
                                        n = 1,
                                        stream = FALSE,
                                        stop = NULL,
                                        max_tokens = NULL,
                                        presence_penalty = 0,
                                        frequency_penalty = 0,
                                        logit_bias = NULL,
                                        user = NULL,
                                        openai_api_key = Sys.getenv("OPENAI_API_KEY"),
                                        openai_organization = NULL,
                                        
                                        is_json_output = TRUE) {
  
  # Ensure that the OpenAI API key is provided
  if (is.null(openai_api_key) || openai_api_key == "") {
    stop("OpenAI API key is missing.", call. = FALSE)
  }
  
  messages = list(
    list(
      "role" = "system",
      "content" = system_message
    ),
    
    list(
      "role" = "user",
      "content" = user_message
    )
  )
  
  # Internal function to make the API call
  make_call <- function() {
    response <- httr::POST(
      url = "https://api.openai.com/v1/chat/completions",
      httr::add_headers(
        "Authorization" = paste("Bearer", openai_api_key),
        "Content-Type" = "application/json"
      ),
      body = list(
        model = model,
        messages = messages,
        temperature = temperature,
        top_p = top_p,
        n = n,
        stream = stream,
        stop = stop,
        max_tokens = max_tokens,
        presence_penalty = presence_penalty,
        frequency_penalty = frequency_penalty,
        logit_bias = logit_bias,
        user = user
      ),
      encode = "json"
    )
    
    # Handle HTTP errors
    if (httr::http_error(response)) {
      stop("API request failed with status code: ", httr::status_code(response), call. = FALSE)
    }
    
    out <- httr::content(response, "text", encoding = "UTF-8")
    jsonlite::fromJSON(out, flatten = TRUE)
  }
  
  # Make the initial API call
  output <- make_call()$choices$message.content
  
  # Check and retry for valid JSON output if necessary
  # If JSON validation is required
  if (is_json_output) {
    attempt <- 1
    max_attempts <- 10
    
    # Loop to ensure valid JSON response
    while (!.is_valid_json(output) && attempt <= max_attempts) {
      # Print attempt information
      cat("Attempt", attempt, ": Invalid JSON received. Regenerating...\n")
      # Retry API call
      output <- make_call()$choices$message.content
      attempt <- attempt + 1
    }
    
    # If valid JSON is not received after max attempts, stop execution
    if (!.is_valid_json(output)) {
      stop("Failed to receive valid JSON after ", max_attempts, " attempts.", call. = FALSE)
    }
  }
  
  # Return the final output
  output
}

# Internal helper function to check if a string is valid JSON
# @noRd
.is_valid_json <- function(json_string) {
  tryCatch({
    # Attempt to parse the JSON string
    jsonlite::fromJSON(json_string)
    # Return TRUE if parsing is successful
    TRUE
  }, error = function(e) {
    # Return FALSE if an error occurs (invalid JSON)
    FALSE
  })
}



.build_prompt <- function(process_type, 
                          text, 
                          variables, 
                          user_message, 
                          system_message) {
  
  switch(process_type,
         
         classify_texts = list(
           user_message = paste(comradeGPT::cmd_prompts$user_classify_text, text, sep = '\n\n'),
           system_message = if (!is.null(system_message)) system_message else comradeGPT::cmd_prompts$system_classify_text
         ),
         
         extract_summary = list(
           user_message = paste(comradeGPT::cmd_prompts$user_extract_summary, text, sep = '\n\n'),
           system_message = if (!is.null(system_message)) system_message else comradeGPT::cmd_prompts$system_extract_variables
         ),
         
         extract_variables = list(
           user_message = paste(comradeGPT::cmd_prompts$user_extract_variables, text, sep = '\n\n'),
           system_message = if (!is.null(system_message)) system_message else comradeGPT::cmd_prompts$system_extract_variables
         ),
         
         extract_attributes = list(
           user_message = paste(comradeGPT::cmd_prompts$user_extract_attributes, 
                                'STUDY: ', text, 
                                'LIST OF VARIABLES: ', variables, 
                                sep = '\n\n'),
           system_message = if (!is.null(system_message)) system_message else comradeGPT::cmd_prompts$system_extract_variables
         ),
         
         extract_popchars = list(
           user_message = paste(comradeGPT::cmd_prompts$user_extract_popchars, text, sep = '\n\n'),
           system_message = if (!is.null(system_message)) system_message else comradeGPT::cmd_prompts$system_extract_variables
         ),
         
         manual = list(
           user_message = paste(user_message, text, sep = '\n\n'),
           system_message = system_message
         )
  )
}


.complete_chat1 <- function(row, 
                            user_message, 
                            system_message, 
                            model, 
                            process_type) {
  
  
  prompt_messages <- .build_prompt(process_type, 
                                   row$text, 
                                   row$variables, 
                                   user_message, 
                                   system_message)
  
  
  response <- .openai_chat_completions(
    user_message = prompt_messages$user_message,
    system_message = prompt_messages$system_message,
    model = model,
    is_json_output = TRUE
  )
  return(list(pmid = row$pmid, response = response))
}


