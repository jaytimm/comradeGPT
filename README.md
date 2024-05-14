# comradeGPT

``` r
if (!require(pacman)) install.packages("pacman")
pacman::p_load(puremoe,
               
               jsonlite, 
               readxl, 
               openai, 
               httr, 
               pbapply, 
               data.table, 
               dplyr)
```

``` r
PMIDs <- readxl::read_xlsx('results_filtered.xlsx')
```

## Get data

### Abstracts

``` r
abstracts <- puremoe::get_records(pmids = PMIDs$PMID, 
                                  endpoint = 'pubmed_abstracts',
                                  cores = 3) 

abstracts0 <- abstracts |>
  mutate(section = 'Abstract', id = 0) |>
  rename(text = abstract) |>
  select(pmid, section, text, id)
```

``` r
abstracts |> select(-abstract, -annotations) |> head() |> knitr::kable()
```

| pmid     | year | journal                                           | articletitle                                                                                                                                            |
|:---|:--|:----------------|:------------------------------------------------|
| 33083543 | 2020 | Learning health systems                           | Data-driven discovery of probable Alzheimer’s disease and related dementia subphenotypes using electronic health records.                               |
| 38464316 | 2024 | medRxiv : the preprint server for health sciences | Association of Long-Term Blood Pressure Variability with Cerebral Amyloid Angiopathy-related Brain Injury and Cognitive Decline.                        |
| 38370526 | 2024 | Frontiers in neurology                            | Machine learning-based prediction of mild cognitive impairment among individuals with normal cognitive function.                                        |
| 38293179 | 2024 | medRxiv : the preprint server for health sciences | Beyond Hypertension: Examining Variable Blood Pressure’s Role in Cognition and Brain Structure.                                                         |
| 38225967 | 2023 | Journal of Alzheimer’s disease reports            | Prevalence of Mild Cognitive Impairment in Southern Regions of Colombia.                                                                                |
| 38169646 | 2023 | Frontiers in cardiovascular medicine              | Propensity score analysis of red cell distribution width to serum calcium ratio in acute myocardial infarction as a predictor of in-hospital mortality. |

### Full text

``` r
pmclist <- puremoe::data_pmc_list(use_persistent_storage = T)
pmc_pmids <- pmclist[PMID %in% PMIDs$PMID]

pmc_fulltext <- pmc_pmids$fpath |> 
  puremoe::get_records(endpoint = 'pmc_fulltext', cores = 4) 
```

### As JSON

> Abstract + full text (by section)

``` r
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
```

## Process/annotate texts

> The `cmd_process_document()` function:

-   Ensures JSON output is properly formatted;

-   Allows user to specify the number of annotators to utilize;

-   Parallel processing of annotation processes.

> The `process_type` paramater specifies the relevant task, which simply
> involves selecting the appropriate prompt structure under the hood.

``` r
process_type = c('classify_texts',
                 'extract_variables',
                 'extract_attributes',
                 'extract_popchars',
                 'manual'
                 ## Table A
                 ) 
```

### 1. Classify study

-   Subject Matter: Is the text discussing human subjects?

-   Study Type: Is the study observational?

-   Data Source: Is the data derived from real-world settings without
    manipulation?

#### Prompt

``` r
wrapped_text <- strwrap(comradeGPT::cmd_prompts$user_classify_text, 
                        width = 50)
writeLines(wrapped_text)
```

    ## Your task is to classify scientific texts by
    ## answering the following questions:
    ## 
    ## Subject Matter: Is the text discussing human
    ## subjects? Study Type: Is the study observational?
    ## Data Source: Is the data derived from real-world
    ## settings without manipulation?
    ## 
    ## This will help determine the nature and
    ## methodology of the studies discussed in the
    ## texts.
    ## 
    ## Ouput format:
    ## 
    ## Provide the results as a JSON array. Expected
    ## format is detailed below:
    ## 
    ## [ { "question": "is_subject_human", "answer":
    ## "yes", "explanation": "The text discusses
    ## observational data collected from a group of
    ## human participants, focusing on their health
    ## outcomes over several years."  }, { "question":
    ## "is_study_observational", "answer": "yes",
    ## "explanation": "The study is classified as
    ## observational because it involves monitoring
    ## subjects without intervening or altering their
    ## normal behaviors."  }, { "question":
    ## "is_data_from_real_world", "answer": "yes",
    ## "explanation": "The data were collected in
    ## real-world settings, such as hospitals and
    ## community centers, without any experimental
    ## manipulation."  } ]
    ## 
    ## Ensure there is no trailing comma after the last
    ## element. DO NOT include the "```json " code block
    ## notation in the output.
    ## 
    ## TEXT:

#### Function/API call

``` r
pp0 <- pmc_fulltext1 |> slice(1:3)

class <- comradeGPT::cmd_process_document(
  pmid = pp0$pmid,
  text = pp0$json,
  process_type = 'classify_texts',
  annotators = 3, 
  cores = 4
  )

class |> head() |> knitr::kable()
```

| annotator_id | question                | answer | explanation                                                                                                                                                                                                                                 | pmid     |
|:---|:------|:--|:------------------------------------------------------|:---|
| OTI2613      | is_subject_human        | yes    | The text discusses elderly patients who were subjects in the study conducted at cardiology outpatient clinics.                                                                                                                              | 28817241 |
| OTI2613      | is_study_observational  | yes    | The study is observational as it evaluates the association between vitamin D deficiency and risk of heart failure without any intervention on the participants.                                                                             | 28817241 |
| OTI2613      | is_data_from_real_world | yes    | The data were collected in real-world settings, specifically from cardiology outpatient clinics of a hospital, involving the analysis of clinical and sociodemographic characteristics of elderly patients.                                 | 28817241 |
| SNC1554      | is_subject_human        | yes    | The text discusses a study involving older hypertensive patients with subjective memory complaints, focusing on brain imaging, cognitive tests, and blood pressure measurements.                                                            | 29276677 |
| SNC1554      | is_study_observational  | yes    | The study is observational as it involves imaging data collection, cognitive assessments, and blood pressure measurements without any intervention on the participants.                                                                     | 29276677 |
| SNC1554      | is_data_from_real_world | yes    | The data in the study were derived from real-world settings, such as clinical examinations, brain imaging, neuropsychological assessments, and blood pressure measurements conducted on older hypertensive patients with memory complaints. | 29276677 |

### 2. Table A

### 3. Population Characteristics

### 4. Variable extraction

#### Prompt

``` r
wrapped_text <- strwrap(comradeGPT::cmd_prompts$user_extract_variables, 
                        width = 50)
writeLines(wrapped_text)
```

    ## Task: Extract all EXPOSURE, OUTCOME, and
    ## COVARIATE variables included in the medical study
    ## presented below.
    ## 
    ## Instructions: Identify Variables: Carefully read
    ## the study to identify variables used in the
    ## analysis. Ensure each variable is considered
    ## independently, even if presented in a list or
    ## grouped with others.
    ## 
    ## Classifications: EXPOSURE: These are the
    ## variables representing factors analyzed for their
    ## potential effects on an outcome. Factors can
    ## include lifestyle choices such as diet and
    ## physical activity, environmental influences like
    ## pollution, or genetic predispositions. Every
    ## study has at least ONE exposure variable.
    ## 
    ## OUTCOME: This is the variable being predicted or
    ## explained in the study. It is the main effect or
    ## condition the research aims to understand through
    ## its relation to various exposures. Every study
    ## has at least ONE outcome variable.
    ## 
    ## COVARIATE: These variables are included in the
    ## analysis to control for confounding factors that
    ## might influence both the exposure and the
    ## outcome. Common covariates include age, gender,
    ## and socioeconomic status.
    ## 
    ## Please list only the fundamental concept of each
    ## variable, excluding any specific details related
    ## to age, timing, or measurement intervals. Focus
    ## on the general category or type of each variable
    ## to ensure the output is concise and universally
    ## applicable, without being tied to a particular
    ## time frame or demographic detail.
    ## 
    ## For each extracted variable, please determine the
    ## most appropriate Medical Subject Headings (MeSH)
    ## descriptor using your specialized knowledge. For
    ## linking extracted variables to MeSH terms, assign
    ## EXPOSURE variables to categories related to
    ## environmental or behavioral influences, COVARIATE
    ## variables to demographic or baseline
    ## characteristics, and OUTCOME variables to
    ## specific health conditions or disease outcomes.
    ## 
    ## Output Format: Provide the results as a JSON
    ## array. Each object in the array should include
    ## four elements: "variable_name", "variable_type",
    ## "explanation", and "mesh_descriptor".
    ## 
    ## Example format:
    ## 
    ## [ {"variable_name": "Systolic Blood Pressure",
    ## variable_type": "EXPOSURE", "explanation":
    ## "Measure of blood pressure being analyzed for
    ## association with dementia.", "mesh_descriptor":
    ## "Blood pressure"}, {"variable_name": "Age",
    ## "variable_type": "COVARIATE", "explanation":
    ## "Sociodemographic factor adjusted for in the
    ## analyses.", "mesh_descriptor": "age"},
    ## {"variable_name": "Dementia","variable_type":
    ## "OUTCOME", "explanation": "Outcome variable being
    ## predicted or explained in the study.",
    ## "mesh_descriptor": "Dementia"} ]
    ## 
    ## Ensure there is no trailing comma after the last
    ## element. DO NOT include the "```json " code block
    ## notation in the output.
    ## 
    ## Extract each covariate variable as a separate
    ## JSON object. Specifically, avoid grouping
    ## variables under broad categories such as "Health
    ## Behaviors" or "Sociodemographic Factors".
    ## Instead, specify each factor individually, such
    ## as "age", "ethnicity", "smoking", "alcohol
    ## consumption", "BMI", and "diabetes". Each entry
    ## should be clearly separated and presented as an
    ## independent JSON object.
    ## 
    ## Extract the OUTCOME variable first. Only after
    ## the OUTCOME variable has been extracted, extract
    ## the EXPOSURE and COVARIATE variables.
    ## 
    ## STUDY:

``` r
variables <- comradeGPT::cmd_process_document(
  pmid = pp0$pmid,
  text = pp0$json,
  process_type = 'extract_variables',
  annotators = 3, 
  cores = 4
  )

variables |> head() |> knitr::kable()
```

| annotator_id | variable_name        | variable_type | explanation                                                | mesh_descriptor      | pmid     |
|:-------|:----------|:-------|:----------------------------|:----------|:-----|
| OTI2613      | Heart Failure        | OUTCOME       | Main health condition being predicted in the study.        | Heart Failure        | 28817241 |
| OTI2613      | Vitamin D deficiency | EXPOSURE      | Factor analyzed for its potential effect on heart failure. | Vitamin D Deficiency | 28817241 |
| OTI2613      | Age                  | COVARIATE     | Demographic factor controlled for in the analysis.         | Age Factors          | 28817241 |
| OTI2613      | Gender               | COVARIATE     | Demographic factor controlled for in the analysis.         | Sex Factors          | 28817241 |
| OTI2613      | Education            | COVARIATE     | Demographic factor controlled for in the analysis.         | Education            | 28817241 |
| OTI2613      | Ethnicity            | COVARIATE     | Demographic factor controlled for in the analysis.         | Ethnic Groups        | 28817241 |

### 5. Variable attribute extraction

#### Prompt

``` r
wrapped_text <- strwrap(comradeGPT::cmd_prompts$user_extract_attributes, 
                        width = 50)
writeLines(wrapped_text)
```

    ## You are tasked with creating a JSON output that
    ## includes structured data for a predefined LIST OF
    ## VARIABLES. Each entry in the JSON array should
    ## correspond to one variable, capturing various
    ## essential details such as its type and key
    ## descriptive attributes and features.
    ## 
    ## Variable features include:
    ## 
    ## Construct: Definition: Represents the biomedical
    ## concept used in research to denote the broader
    ## variable of interest. Example: "Body Mass Index
    ## (BMI)" as a construct for "Obesity".
    ## 
    ## Variable Concept Category: Definition: Describes
    ## broader categories that individual constructs
    ## belong to, from genetics to socioeconomics.
    ## Example: "Biology/Genetics" for APOEe4 status.
    ## 
    ## Source Terminology: Definition: Specifies
    ## terminologies or classification systems used for
    ## clarity in variable definitions. Example: "LOINC"
    ## for laboratory tests.
    ## 
    ## Codes: Definition: Contains specific codes from
    ## medical terminologies that correspond to the
    ## variable. Example: "E11" for Type 2 Diabetes
    ## Mellitus in ICD-10.
    ## 
    ## Timing Logic: Definition: Outlines criteria for
    ## when and how data related to the variable is
    ## collected and analyzed. Example: Blood pressure
    ## measurements taken annually over 20 years for a
    ## study on hypertension.
    ## 
    ## Complexity Indicator: Definition: Identifies
    ## variables with complex definitions derived from
    ## multiple sources. As Yes or No. Example: Major
    ## depressive disorder determined by diagnostic
    ## codes and prescription data.
    ## 
    ## Complex Definition: Definition: Describes
    ## intricate phenotype definitions for complex
    ## scenarios. Example: Diabetes definition involving
    ## multiple criteria including medication history.
    ## 
    ## Data Type: Definition: Classifies the nature of
    ## data for each variable, influencing analysis
    ## methods. Example: "Continuous" for variables like
    ## "Blood Pressure".
    ## 
    ## Ascertainment Source: Definition: Indicates the
    ## source or method by which the variable's data was
    ## obtained. Example: "EHR" for data from Electronic
    ## Health Records.
    ## 
    ## Ascertainment Notes: Definition: Contains a
    ## simple description of how the variable was
    ## ascertained. Example: Blood pressure measured
    ## using a standard sphygmomanometer after 5 minutes
    ## of rest.
    ## 
    ## OUTPUT: Please provide ouput in a JSON array. The
    ## number of objects in the output JSON should equal
    ## the number of variables in the LIST OF VARIABLES.
    ## Each object should be structured with
    ## straightforward, flat hierarchy, avoiding nested
    ## structures.
    ## 
    ## "variable_name" and "variable_type" in output
    ## should be the same as variable_name and
    ## varable_type in LIST OF VARIABLES.
    ## 
    ## An incomplete example:
    ## 
    ## [ { "variable_name": "AGE", "variable_type":
    ## "COVARIATE", "Construct": "Chronological measure
    ## of time since birth",
    ## "Variable_Concept_Category": "Demographics",
    ## "Source_Terminology": "Not applicable", "Codes":
    ## "Not applicable", "Timing_Logic": "Recorded at
    ## the time of study enrollment",
    ## "Complexity_Indicator": "No",
    ## "Complex_Definition": "Not applicable",
    ## "Data_Type": "Continuous",
    ## "Ascertainment_Source": "Self-reported or
    ## administrative records", "Ascertainment_Notes":
    ## "Verified by checking official documents when
    ## possible" },
    ## 
    ## # ...  { "variable_name": "DIABETES",
    ## "variable_type": "COVARIATE", "Construct":
    ## "Metabolic disorder characterized by high blood
    ## sugar levels", "Variable_Concept_Category":
    ## "Underlying Health", "Source_Terminology":
    ## "ICD-10", "Codes": "E11 for Type 2 Diabetes
    ## Mellitus", "Timing_Logic": "Measured annually
    ## during routine check-ups",
    ## "Complexity_Indicator": "Yes",
    ## "Complex_Definition": "Based on glucose levels,
    ## HbA1c measurements, and/or medication usage",
    ## "Data_Type": "Categorical",
    ## "Ascertainment_Source": "Electronic Health
    ## Records (EHR)", "Ascertainment_Notes": "Confirmed
    ## by laboratory glucose tests and medication
    ## records" } ]
    ## 
    ## Ensure there is no trailing comma after the last
    ## element. DO NOT include the "```json " code block
    ## notation in the output.

## Establishing consensus among annotators

> As generic across annotation tasks
