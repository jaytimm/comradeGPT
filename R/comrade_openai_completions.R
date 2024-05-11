


comrade_openai_completions <- function(model = 'gpt-3.5-turbo',
                                   messages = NULL,
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