

# LOAD relevant packages
remotes::install_github("jaytimm/comradeGPT")
if (!require(pacman)) install.packages("pacman")
pacman::p_load(puremoe,
               
               jsonlite, 
               readxl, 
               openai, 
               httr, 
               pbapply, 
               data.table, 
               dplyr)


#############################################################
## USER NEEDS TO INPUT SOME LOCAL FILE NAMES/PATHS HERE -!!!

### LOAD PMIDs -- somehow -- 
input_dir <- '/home/jtimm/pCloudDrive/GitHub/packages/comradeGPT/input-pmids'

setwd(input_dir)
ris <- readLines('hypernatremia Ovid MEDLINE 20240524 line46.ris') # rbibutils
pmids <- gsub('ID  - ', '',
              grep('^ID ', ris, value = T))

# PMIDs <- readxl::read_xlsx('results_filtered.xlsx')
# pmids <- PMIDs$PMID


### Local directory where results will be output -- 
output_dir <- '/home/jtimm/Desktop/demo'


## USER NEEDS TO INPUT PARAM info here !!

#  Sys.setenv(OPENAI_API_KEY = 'XXXXXXXXXXXXX')

n_annotators = 10
n_cores = 30
n_sample = 10

seed = 99




#########################################################
## Get data from PubMed and PMC fulltext 
abstracts <- puremoe::get_records(pmids = pmids, 
                                  endpoint = 'pubmed_abstracts',
                                  cores = 3) 
###
abstracts0 <- abstracts |>
  mutate(section = 'Abstract', id = 0) |>
  rename(text = abstract) |>
  select(pmid, section, text, id)


###
pmclist <- puremoe::data_pmc_list(use_persistent_storage = T)
pmc_pmids <- pmclist[PMID %in% PMIDs$PMID]

pmc_fulltext <- pmc_pmids$fpath |> 
  puremoe::get_records(endpoint = 'pmc_fulltext', cores = 4) 


### Create Abstract + Full text JSON - with section labels
pmc_fulltext1 <- pmc_fulltext |>
  group_by(pmid) |>
  mutate(id = row_number()) |> ungroup() |>
  bind_rows(abstracts0) |>
  arrange(pmid, id) |>
  select(-id) |>
  group_by(pmid) |>
  summarize(
    json = jsonlite::toJSON(list(data.frame(section, text)), 
                            pretty = TRUE, 
                            auto_unbox = TRUE),
    .groups = 'drop'  )


### SAMPLE data set
set.seed(seed)
pp0 <- pmc_fulltext1 |> sample_n(n_sample)





############################################################

### Get summary info -- ~Table A
gpt_sumstats <- comradeGPT::cmd_process_document(
  pmid = pp0$pmid,
  text = pp0$json,
  process_type = 'extract_summary',
  annotators = n_annotators, 
  cores = n_cores
)

### Calculate precision of LLM outputs
gpt_sumstats_precision <- gpt_sumstats |>
  comradeGPT::cmd_calc_precision(cols = c('field', 
                                          'value'))

### Calculate Inter-Rater Agreement values -- including Fleiss' Kappa
gpt_sumstats_agreement <- gpt_sumstats |>
  comradeGPT::cmd_calc_agreement(cols =  c('field', 
                                           'value'))






############################################################

### Extract VARIABLES and varaiable types
gpt_variables <- comradeGPT::cmd_process_document(
  pmid = pp0$pmid,
  text = pp0$json,
  process_type = 'extract_variables',
  annotators = n_annotators, 
  cores = n_cores
)


### OLD consensus/normalization of extracted variables
get_consensus <- function(data) {
  # Filter variables with precision >= 0.6
  consensus_variables <- data[data$precision >= 0.6, ]
  
  # Ensure at least one variable per type with the highest precision score is included
  min_vars_per_type <- do.call(rbind, lapply(split(data, list(data$variable_type, data$pmid)), function(subdata) {
    subdata[subdata$precision == max(subdata$precision), ][1, , drop = FALSE]  # Take the first occurrence in case of ties
  }))
  
  # Combine both filtered and minimum required variables
  combined_variables <- rbind(consensus_variables, min_vars_per_type)
  
  # Remove duplicates, keeping the highest precision entries
  final_variables <- combined_variables[order(combined_variables$precision, decreasing = TRUE), ]
  final_variables <- final_variables[!duplicated(final_variables[, c("variable_name", "variable_type", "pmid")]), ]
  final_variables <- final_variables[final_variables$pmid != "NA", ]
  
  return(final_variables)
}


### Get consensus variables
gpt_variables_precision <- gpt_variables |> 
  comradeGPT::cmd_calc_precision(cols = c('variable_name', 
                                          'variable_type'))
  

gpt_variables_agreement <- gpt_variables |> 
  comradeGPT::cmd_calc_agreement(cols = c('variable_name', 
                                          'variable_type'))

gpt_consensus_variables <- gpt_variables_precision |> get_consensus() ## above --




# NEW consensus procedure --

## TO DO !!!!!!!!!!!



##############################################################

### Extract variable attributes

### restructure data/json for attribute xtraction
cvs_json <- gpt_consensus_variables |>
  group_by(pmid) |>
  summarize(
    json_vars = jsonlite::toJSON(list(variable_name), 
                                 pretty = TRUE, 
                                 auto_unbox = TRUE),
    .groups = 'drop'  )

pp1 <- pp0 |> left_join(cvs_json)


### Get attributes
gpt_atts <- comradeGPT::cmd_process_document(
  pmid = pp1$pmid,
  text = pp1$json,
  
  variables = pp1$json_vars,
  
  process_type = 'extract_attributes',
  annotators = n_annotators, 
  cores = n_cores
) 


### Reshape data
gpt_atts_long <- data.table::melt(gpt_atts,
                       id.vars = c("pmid",
                                   "annotator_id",
                                   "variable_name",
                                   "variable_type"),
                       
                       measure.vars = c("construct",
                                        "variable_concept_category",
                                        "source_terminology",
                                        "codes",
                                        "timing_logic",
                                        "complexity_indicator",
                                        "complex_definition",
                                        "data_type",
                                        "ascertainment_source",
                                        "ascertainment_notes"))

### Calc precision
gpt_atts_precision <- gpt_atts_long |>
  filter(!value %in% c(NA)) |>
  comradeGPT::cmd_calc_precision(cols = c('variable_name', 
                                          'variable',
                                          'value'))

### Calc inter-agreement
gpt_atts_agreement <- gpt_atts_long |>
  comradeGPT::cmd_calc_agreement(cols =  c('variable_name', 
                                           'variable',
                                           'value'))



################################################
### OUTPUT to some local folder as XLSX -- 

setwd(output_dir)
write.csv(gpt_sumstats_agreement, 'gpt_sumstats_agreement.csv', row.names = F)
write.csv(gpt_sumstats_precision, 'gpt_sumstats_precision.csv', row.names = F)

write.csv(gpt_sumstats_agreement, 'gpt_variables_agreement.csv', row.names = F)
write.csv(gpt_sumstats_precision, 'gpt_variables_precision.csv', row.names = F)

write.csv(gpt_sumstats_agreement, 'gpt_attributes_agreement.csv', row.names = F)
write.csv(gpt_sumstats_precision, 'gpt_attributes_precision.csv', row.names = F)




