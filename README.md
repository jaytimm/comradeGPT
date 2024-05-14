## comradeGPT

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

myPackage/ ├── DESCRIPTION ├── NAMESPACE ├── R/ │ ├──
cmd_process_document.R │ ├── cmd_get_consensus.R │ ├── utils.R ├── man/

## Classify study using abstract

-   Subject Matter: Is the text discussing human subjects?

-   Study Type: Is the study observational?

-   Data Source: Is the data derived from real-world settings without
    manipulation?

### Prompt

``` r
wrapped_text <- strwrap(comradeGPT::cmd_prompts$user_classify_text, width = 50)
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

``` r
#######
pp0 <- pmc_fulltext1 |> slice(1:3)

xx <- comradeGPT::cmd_process_document(pmid = pp0$pmid,
                                       text = pp0$json,
                                       process_type = 'extract_variables',
                                       annotators = 3, 
                                       cores = 4 
                                       )

xx |> head() |> knitr::kable()
```

| annotator_id | variable_name        | variable_type | explanation                                                     | mesh_descriptor      | pmid     |
|:------|:----------|:-------|:------------------------------|:----------|:-----|
| OTI2613      | Heart Failure        | OUTCOME       | Main outcome variable being predicted in the study.             | Heart Failure        | 28817241 |
| OTI2613      | Vitamin D Deficiency | EXPOSURE      | Independent variable representing the exposure factor analyzed. | Vitamin D Deficiency | 28817241 |
| OTI2613      | Age                  | COVARIATE     | Demographic variable used as a covariate in the analysis.       | Age                  | 28817241 |
| OTI2613      | Gender               | COVARIATE     | Demographic variable used as a covariate in the analysis.       | Gender               | 28817241 |
| OTI2613      | Education            | COVARIATE     | Sociodemographic variable used as a covariate in the analysis.  | Education            | 28817241 |
| OTI2613      | Ethnicity            | COVARIATE     | Sociodemographic variable used as a covariate in the analysis.  | Ethnicity            | 28817241 |

## 1. Table A

## 2. Population Characteristics

## 3a. Variable extraction

## 3b. Variable attribute extraction
