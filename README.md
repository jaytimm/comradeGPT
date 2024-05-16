# comradeGPT

## Installation

Get the development version from GitHub with:

``` r
remotes::install_github("jaytimm/comradeGPT")
```

------------------------------------------------------------------------

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

pp0 <- pmc_fulltext1 |> slice(1:10)
```

``` r
substr(pmc_fulltext1$json[2], 1, 3000) |> cat()
```

    ## [
    ##   [
    ##     {
    ##       "section": "Abstract",
    ##       "text": "Mild cognitive impairment and Alzheimer's dementia involve a grey matter disease, quantifiable by 18F-Fluorodeoxyglucose positron emission tomography (FDG-PET), but also white matter damage, evidenced by diffusion tensor magnetic resonance imaging (DTI), which may play an additional pathogenic role. This study aimed to determine whether such DTI and PET variations are also interrelated in a high-risk population of older hypertensive patients with only subjective memory complaints (SMC). Sixty older hypertensive patients (75 ± 5 years) with SMC were referred to DTI and FDG-PET brain imaging, executive and memory tests, as well as peripheral and central blood pressure (BP) measurements. Mean apparent diffusion coefficient (ADCmean) was determined in overall white matter and correlated with the grey matter distribution of the metabolic rate of glucose (CMRGlc) using whole-brain voxel-based analyses of FDG-PET images. ADCmean was variable between individuals, ranging from 0.82 to 1.01.10- 3 mm2 sec- 1, and mainly in relation with CMRGlc of areas involved in Alzheimer's disease such as internal temporal areas, posterior associative junctions, posterior cingulum but also insulo-opercular areas (global correlation coefficient: - 0.577, p < 0.001). Both the ADCmean and CMRGlc of the interrelated grey matter areas were additionally and concordantly linked to the results of executive and memory tests and to systolic central BP (all p < 0.05). Altogether, our findings show that cross-sectional variations in overall white brain matter are linked to the metabolism of Alzheimer-like cortical areas and to cognitive performance in older hypertensive patients with only subjective memory complaints. Additional relationships with central BP strengthen the hypothesis of a contributing pathogenic role of hypertension."
    ##     },
    ##     {
    ##       "section": "Introduction",
    ##       "text": "1Introduction\nSubjective cognitive impairment (SCI) is common in the elderly, and may serve as a symptomatic indicator of a precursor stage of Alzheimer's dementia (AD), even if subtle cognitive decline is difficult to detect on standardized cognitive testing (Jessen et al., 2014). While this condition is not considered to be a definite neurodegenerative process such as mild cognitive impairment (MCI) or AD, it may precede a further cognitive decline and the development of dementia (Kielb et al., 2017).In addition, impaired cognitive performance has been associated with cardiovascular (CV) risk factors such as hypertension (Ferreira et al., 2017, Muller et al., 2007, Rafnsson et al., 2007), in keeping with our recent observation that brain remodeling with age is linked to the level of central pulse pressure (Verger et al., 2015). Thus, older hypertensive patients with SCI may constitute a particularly high-risk group for subsequent dementia and may therefore benefit from dedicated modalities of medical management and of early diagnosis.

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
t1 <- strwrap(comradeGPT::cmd_prompts$user_classify_text, 
              width = 50)
writeLines(t1)
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
class <- comradeGPT::cmd_process_document(
  pmid = pp0$pmid,
  text = pp0$json,
  process_type = 'classify_texts',
  annotators = 3, 
  cores = 4
  )

class |> head() |> knitr::kable()
```

### 2. Table A

### 3. Population Characteristics

### 4. Variable extraction

#### Prompt

``` r
t2 <- strwrap(comradeGPT::cmd_prompts$user_extract_variables, 
              width = 50)
writeLines(t2)
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
  annotators = 5, 
  cores = 10
  )

variables |> head() |> knitr::kable()
```

| pmid     | annotator_id | variable_name        | variable_type | explanation                                                                  | mesh_descriptor      |
|:----|:------|:---------|:------|:---------------------------------|:---------|
| 28817241 | OMO5232      | Heart Failure        | OUTCOME       | Main outcome variable in the study related to heart failure risk assessment. | Heart Failure        |
| 28817241 | OMO5232      | Vitamin D deficiency | EXPOSURE      | Independent variable related to the risk of heart failure.                   | Vitamin D Deficiency |
| 28817241 | OMO5232      | Age                  | COVARIATE     | Covariate considering the age of the elderly participants.                   | Age                  |
| 28817241 | OMO5232      | Gender               | COVARIATE     | Covariate representing the gender of the elderly participants.               | Gender               |
| 28817241 | OMO5232      | Education            | COVARIATE     | Covariate indicating the educational level of the elderly participants.      | Education            |
| 28817241 | OMO5232      | Ethnicity            | COVARIATE     | Covariate describing the ethnic background of the elderly participants.      | Ethnic Groups        |

### 5. Variable attribute extraction

> NOTE – this will be more challenging than initially thought –
> specifically WRT aligning PMIDs in variable list with PMIDs in text –

``` r
sample_characteristics <- list(
  Biology_Genetics = list(
    "Biology/Genetics"
  ),
  Family_Planning = list(
    "1st trimester care",
    "Use of ART"
  ),
  Health_Behaviors = list(
    "Drinking",
    "Smoking",
    "Substance use"
  ),
  Implicit_Racial_Bias = list(
    "Structural racism"
  ),
  Reproductive_Hx = list(
    "Hx of abortion",
    "Hx of pregnancy loss",
    "Hx of perinatal death",
    "Hx of preterm birth",
    "Parity/Gravidity",
    "Previous C-section",
    "Previous birth weight",
    "Prior pregnancy outcome"
  ),
  Sociodemographics = list(
    "Geographic area",
    "Maternal age",
    "Marital status",
    "Race/ethnicity",
    "Paternity"
  ),
  Socioeconomics = list(
    "Education",
    "Insurance",
    "Income assistance",
    "SES category"
  ),
  Underlying_Health = list(
    "Chronic diseases",
    "Diabetes",
    "Hypertension",
    "Maternal weight",
    "Maternal BMI"
  )
)
```

#### Prompt

``` r
t3 <- strwrap(comradeGPT::cmd_prompts$user_extract_attributes, 
              width = 50)
writeLines(t3)
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

## Evaluation Framework

> this is very specific to variables at present – needs to be made
> generic to all task types –

### Precision Calculation:

-   Purpose: To measure the consistency with which LLM annotators
    identify specific variables.

-   Calculation: Precision is calculated as the proportion of annotators
    who identified a specific variable out of the total number of
    annotators.

``` r
precision <- variables |> comradeGPT::cmd_calc_precision(cols = c('variable_name', 'variable_type'))
precision |> head() |> knitr::kable()
```

| pmid     | variable_name        | variable_type | annotators | var_freq | agree_rate |
|:--------|:-------------------|:-------------|----------:|--------:|----------:|
| 28817241 | HEART FAILURE        | OUTCOME       |          5 |        5 |          1 |
| 28817241 | VITAMIN D DEFICIENCY | EXPOSURE      |          5 |        5 |          1 |
| 28817241 | AGE                  | COVARIATE     |          5 |        5 |          1 |
| 28817241 | GENDER               | COVARIATE     |          5 |        5 |          1 |
| 28817241 | EDUCATION            | COVARIATE     |          5 |        5 |          1 |
| 28817241 | ETHNICITY            | COVARIATE     |          5 |        5 |          1 |

### Consensus Variables:

-   Definition: Variables that have a high precision (e.g., precision ≥
    60%).

-   Purpose: To form a reliable set of variables that most LLM
    annotators agree upon, reflecting strong consensus.

### Consensus Annotations:

-   Definition: An aggregate annotation derived from the consensus
    variables.

-   Purpose: To create a reference standard based on the most
    consistently identified variables by LLM annotators.

### Inter-Rater Agreement:

-   Purpose: To measure the overall agreement among LLM annotators
    across all variables.

-   Metrics: Use Fleiss’ Kappa or Krippendorff’s Alpha to assess the
    level of agreement, adjusting for chance agreement.

``` r
# 30180830
agreement <- variables |> 
  comradeGPT::cmd_calc_agreement(cols = c('variable_name', 'variable_type'))
agreement |> knitr::kable()
```

| pmid     | kappa |   z | p_value | annotators | type | token | min_vars | max_vars | mean_vars | rate_consensus | n_consensus_vars |
|:-----|----:|---:|-----:|------:|---:|----:|-----:|-----:|------:|---------:|----------:|
| 28817241 | 0.579 | 8.2 | 0.00000 |          5 |   20 |    95 |       19 |       19 |      19.0 |          0.990 |               19 |
| 29276677 | 0.101 | 1.8 | 0.07174 |          5 |   30 |    57 |        8 |       14 |      11.9 |          0.491 |                7 |
| 29330643 | 0.237 | 3.9 | 0.00010 |          5 |   26 |    79 |        9 |       18 |      16.5 |          0.835 |               16 |
| 29574441 | 0.047 | 1.0 | 0.33760 |          5 |   35 |    72 |       12 |       16 |      14.6 |          0.392 |                7 |
| 29596471 | 0.099 | 2.4 | 0.01835 |          5 |   50 |   102 |        9 |       40 |      25.7 |          0.518 |               13 |
| 29796587 | 0.231 | 2.8 | 0.00473 |          5 |   14 |    47 |        9 |       10 |       9.4 |          0.746 |                8 |
| 30180830 | 0.454 | 5.6 | 0.00000 |          5 |   15 |    63 |       11 |       13 |      12.7 |          0.968 |               13 |
| 30337868 | 0.574 | 6.0 | 0.00000 |          5 |   11 |    38 |        7 |        9 |       7.7 |          0.897 |                7 |
| 30368247 | 0.325 | 5.3 | 0.00000 |          5 |   27 |    80 |       14 |       18 |      16.1 |          0.775 |               14 |
| 30656187 | 0.302 | 4.3 | 0.00002 |          5 |   20 |    42 |        6 |       13 |       9.5 |          0.642 |                6 |

### Accuracy of LLM-Based Annotations:

-   Definition: The agreement between human annotations and consensus
    annotations generated by a Large Language Model (LLM).

-   Purpose: To evaluate the performance of LLM-based consensus
    annotation against a human-derived standard.

-   Metrics: Use Cohen’s Kappa or a similar metric to compare the binary
    presence/absence of variables between human and LLM annotations.

------------------------------------------------------------------------

### Conceptual Framework Diagram

``` r
+------------------------------------+
|           Annotator Data           |
+------------------------------------+
            |
            v
+------------------------------------+
|        Calculate Precision         |
|  (Proportion of annotators who     |
|   identified each variable)        |
+------------------------------------+
            |
            v
+------------------------------------+
|       Determine Consensus          |
|      Variables (Precision ≥ 60%)   |
+------------------------------------+
            |
            v
+------------------------------------+
|       Generate Consensus           |
|          Annotations               |
| (Aggregate high-precision variables)|
+------------------------------------+
            |
            v
+------------------------------------+
|    Calculate Inter-Rater Agreement |
|   (Fleiss' Kappa, Krippendorff's    |
|    Alpha) among LLM annotators      |
+------------------------------------+
            |
            v
+------------------------------------+
|    Accuracy of LLM-Based Annotations|
| (Compare human annotations with     |
|   Consensus LLM annotations using   |
|   Cohen's Kappa)                    |
+------------------------------------+
```

## Summary
