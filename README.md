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

pp0 <- pmc_fulltext1 |> slice(1:5)
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
    ## STUDY:

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

### 2. Summary characteristics

#### Prompt

``` r
t5 <- strwrap(comradeGPT::cmd_prompts$user_extract_summary, 
              width = 50)
writeLines(t5)
```

    ## Task: Extract and categorize detailed information
    ## from the medical study presented below.
    ## 
    ## Instructions:
    ## 
    ## Identify Study Characteristics: Carefully read
    ## the study to identify key details such as study
    ## design, population size, covariate definitions,
    ## major results, effect size, confidence intervals,
    ## and p-value. Ensure each characteristic is
    ## considered independently, even if presented in a
    ## list or grouped with others.
    ## 
    ## Use Direct Text Extraction: To ensure precision
    ## and consistency across multiple annotators,
    ## extract the language directly from the text. Do
    ## not paraphrase or interpret beyond what is
    ## necessary to classify the characteristic.
    ## 
    ## Classifications:
    ## 
    ## Study Design: Provides a comprehensive
    ## description of the study's methodology, capturing
    ## specific design types and other pertinent
    ## information such as study duration, setting, and
    ## interventions or exposures assessed.
    ## 
    ## Population Size: Contains the total number of
    ## participants in the study, specifying the number
    ## of cases and controls, if applicable.
    ## 
    ## Covariate Definitions in Maintext: Indicates
    ## whether the main text of the research article
    ## mentions covariates used to adjust for
    ## confounding factors. Annotators mark "Y" if
    ## covariate details are explicitly stated, "N" if
    ## not mentioned, and "S" if details are in
    ## supplementary materials.
    ## 
    ## Major Results: Summarizes the primary findings of
    ## the study in a concise manner.
    ## 
    ## Effect Size: Provides the quantitative measure of
    ## the strength of the association between the
    ## exposure and the outcome.
    ## 
    ## Lower Confidence Interval: Contains the lower
    ## boundary of the confidence interval for the
    ## effect size, indicating the range of uncertainty
    ## surrounding the estimate.
    ## 
    ## Upper Confidence Interval: Contains the upper
    ## boundary of the confidence interval for the
    ## effect size, indicating the range of uncertainty
    ## surrounding the estimate.
    ## 
    ## P-Value: Contains the p-value of the study
    ## findings, indicating the likelihood that the
    ## observed association is not due to chance.
    ## 
    ## Output Format: Provide the results as a JSON
    ## array. Each object in the array should include
    ## three elements: "field", "value", and
    ## "explanation".
    ## 
    ## Example format:
    ## 
    ## [ { "field": "Study Design", "value":
    ## "cross-sectional study", "explanation": "The
    ## study description specified it as a
    ## cross-sectional study."  }, { "field":
    ## "Population Size", "value": "800 participants,
    ## with 400 cases and 400 controls", "explanation":
    ## "The study comprised 800 participants, with 400
    ## cases and 400 controls."  }, { "field":
    ## "Covariate Definitions in Maintext", "value":
    ## "S", "explanation": "The article states that
    ## covariate details can be found in Supplement A,
    ## Table C."  }, { "field": "Major Results",
    ## "value": "Participants with high levels of
    ## physical activity had a 25% lower risk of
    ## developing dementia compared to those with low
    ## activity levels, aOR=0.75.", "explanation": "This
    ## was the primary finding reported in the results
    ## section."  }, { "field": "Effect Size", "value":
    ## "0.75", "explanation": "The odds ratio (OR) for
    ## developing dementia in the high physical activity
    ## group was reported as 0.75."  }, { "field":
    ## "Lower Confidence Interval", "value": "0.60",
    ## "explanation": "The lower limit of the 95%
    ## Confidence Interval (CI) for the OR was reported
    ## as 0.60."  }, { "field": "Upper Confidence
    ## Interval", "value": "0.90", "explanation": "The
    ## upper limit of the 95% CI for the OR was reported
    ## as 0.90."  }, { "field": "P-Value", "value":
    ## "0.02", "explanation": "The p-value for the
    ## association between physical activity and
    ## dementia risk was reported as 0.02."  } ]
    ## 
    ## Ensure there is no trailing comma after the last
    ## element. DO NOT include the "```json " code block
    ## notation in the output.
    ## 
    ## STUDY:

#### Function/API call

``` r
sumstats <- comradeGPT::cmd_process_document(
  pmid = pp0$pmid,
  text = pp0$json,
  process_type = 'extract_summary',
  annotators = 5, 
  cores = 10
  )
```

``` r
sumstats |> head() |> knitr::kable()
```

| annotator_id | field                             | value                                                                                                                                                                                                                                                                                                         | explanation                                                                                                                                                                                                                                                                                   | pmid     |
|:--|:----|:-------------------------------|:------------------------------|:-|
| OSM5611      | Study Design                      | analytical cross-sectional study                                                                                                                                                                                                                                                                              | The research article describes an analytical cross-sectional epidemiological study evaluating the association between vitamin D deficiency and the risk of heart failure in elderly patients of cardiology outpatient clinics.                                                                | 28817241 |
| OSM5611      | Population Size                   | 137 elderly participants                                                                                                                                                                                                                                                                                      | The study included 137 elderly individuals from the Care Center for the Elderly and outpatient clinic of cardiology at the Hospital das Clínicas, UFPE.                                                                                                                                       | 28817241 |
| OSM5611      | Covariate Definitions in Maintext | Y                                                                                                                                                                                                                                                                                                             | The main text explicitly mentions covariates used for adjusting in the study, including age, gender, education, ethnicity, hypertension, diabetes mellitus, hypothyroidism, renal failure, dementia, stroke, dyslipidaemia, depression, smoking, alcoholism, obesity, and cardiac arrhythmia. | 28817241 |
| OSM5611      | Major Results                     | The risk of heart failure was significantly associated with vitamin D deficiency (OR: 12.19; 95% CI = 4.23-35.16; P = 0.000), male gender (OR: 15.32; 95% CI = 3.39-69.20, P = 0.000), obesity (OR: 4.17; 95% CI = 1.36-12.81; P = 0.012), and cardiac arrhythmia (OR: 3.69; 95% CI = 1.23-11.11; P = 0.020). | The primary finding indicates a significant association between vitamin D deficiency and heart failure risk, along with other risk factors identified in the elderly population.                                                                                                              | 28817241 |
| OSM5611      | Effect Size                       | 12.19 (for vitamin D deficiency), 15.32 (for male gender), 4.17 (for obesity), 3.69 (for cardiac arrhythmia)                                                                                                                                                                                                  | The odds ratios (ORs) for heart failure risk associated with vitamin D deficiency, male gender, obesity, and cardiac arrhythmia are reported in the results section.                                                                                                                          | 28817241 |
| OSM5611      | Lower Confidence Interval         | 4.23 (for vitamin D deficiency), 3.39 (for male gender), 1.36 (for obesity), 1.23 (for cardiac arrhythmia)                                                                                                                                                                                                    | The lower boundaries of the 95% confidence intervals (CIs) for the odds ratios related to heart failure risk factors are provided in the study results.                                                                                                                                       | 28817241 |

### 3. Population Characteristics

#### Prompt

``` r
t4 <- strwrap(comradeGPT::cmd_prompts$user_extract_popchars , 
              width = 50)
writeLines(t4)
```

    ## 
    ## 
    ## Task: Extract and categorize all details
    ## regarding the sample characteristics used in the
    ## medical study presented below.
    ## 
    ## Instructions:
    ## 
    ## Identify Sample Characteristics: Carefully read
    ## the study to identify detailed descriptions of
    ## the sample characteristics. These can include
    ## demographic, geographic, temporal, and other
    ## relevant population characteristics. Ensure each
    ## characteristic is considered independently, even
    ## if presented in a list or grouped with others.
    ## 
    ## Use Direct Text Extraction: To ensure precision
    ## and consistency across multiple annotators,
    ## extract the language directly from the text. Do
    ## not paraphrase or interpret beyond what is
    ## necessary to classify the characteristic.
    ## 
    ## Classifications:
    ## 
    ## Demographic Information: Information related to
    ## the population's age, gender, ethnicity,
    ## socioeconomic status, and educational background.
    ## Geographic Characteristics: Details on the
    ## specific regions, urban vs. rural settings, and
    ## relevant climate or environmental conditions
    ## where the study was conducted. Health-Related
    ## Factors: Prevalence of certain medical
    ## conditions, behavioral aspects, and access to
    ## healthcare services. Sampling Method Details:
    ## Type of sampling, inclusion and exclusion
    ## criteria, sample size, and how it was determined.
    ## Temporal Aspects: Timeframe and periodicity of
    ## data collection. Other Relevant Characteristics:
    ## Occupational data, lifestyle factors, and
    ## psychosocial factors. List each characteristic
    ## individually: Avoid grouping variables under
    ## broad categories. Specify each factor clearly and
    ## separately.
    ## 
    ## Output Format: Provide the results as a JSON
    ## array. Each object in the array should include
    ## four elements: "characteristic_name",
    ## "characteristic_type", "explanation", and
    ## "value".
    ## 
    ## Example format:
    ## 
    ## [ { "characteristic_name": "Age range",
    ## "characteristic_type": "Demographic Information",
    ## "explanation": "The range of ages of the
    ## participants in the study.", "value": "18-65" },
    ## { "characteristic_name": "Gender distribution",
    ## "characteristic_type": "Demographic Information",
    ## "explanation": "The proportion of male and female
    ## participants in the study.", "value": "50%
    ## female, 50% male" }, { "characteristic_name":
    ## "Ethnicity", "characteristic_type": "Demographic
    ## Information", "explanation": "The racial or
    ## ethnic background of the participants.", "value":
    ## "40% Caucasian, 30% Hispanic, 20% African
    ## American, 10% Asian" }, { "characteristic_name":
    ## "Specific regions", "characteristic_type":
    ## "Geographic Characteristics", "explanation": "The
    ## regions or countries where the study was
    ## conducted.", "value": "Urban areas in the
    ## Northeastern United States" }, {
    ## "characteristic_name": "Prevalence of medical
    ## conditions", "characteristic_type":
    ## "Health-Related Factors", "explanation": "The
    ## percentage of participants with certain medical
    ## conditions.", "value": "15% with diabetes" } ]
    ## 
    ## Ensure there is no trailing comma after the last
    ## element. DO NOT include the "```json " code block
    ## notation in the output.
    ## 
    ## STUDY:

#### Function/API call

``` r
popchars <- comradeGPT::cmd_process_document(
  pmid = pp0$pmid,
  text = pp0$json,
  process_type = 'extract_popchars',
  annotators = 5, 
  cores = 10
  )
```

``` r
popchars |> head() |> knitr::kable()
```

| annotator_id | characteristic_name       | characteristic_type     | explanation                                                             | value                                                                                           | pmid     |
|:----|:--------|:-------|:--------------------|:---------------------------|:---|
| OSM5611      | Age classes               | Demographic Information | The distribution of age groups among the elderly participants.          | 60–69 (46.6%), 70–79 (43.8%), 80+ (9.5%)                                                        | 28817241 |
| OSM5611      | Sex                       | Demographic Information | The proportion of male and female participants in the study.            | Male: 24.1%, Female: 75.9%                                                                      | 28817241 |
| OSM5611      | Self-referred skin colour | Demographic Information | The distribution of participants based on self-reported skin colour.    | White: 36.5%, Mixed colour: 50.4%, Black: 13.1%                                                 | 28817241 |
| OSM5611      | Marital status            | Demographic Information | The marital status of the elderly participants.                         | Single: 7.3%, Married or stable union: 62.0%, Widow/er: 27.0%, Divorced or separated: 3.6%      | 28817241 |
| OSM5611      | Education of the elder    | Demographic Information | The educational background of the elderly participants.                 | Illiterate: 18.0%, Basic I: 28.5%, Basic II: 29.9%, High school: 21.9%, Higher education: 11.7% | 28817241 |
| OSM5611      | Economic class, Brazil    | Demographic Information | The distribution of economic classes based on Brazilian classification. | A: 21.5%, B1: 21.5%, B2: 10.2%, C1: 24.8%, C2: 14.5%, D and E: 17.5%                            | 28817241 |

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
```

``` r
variables |> head() |> knitr::kable()
```

| annotator_id | variable_name        | variable_type | explanation                                                      | mesh_descriptor      | pmid     |
|:------|:----------|:-------|:------------------------------|:----------|:-----|
| OSM5611      | Heart Failure        | OUTCOME       | Main health condition being predicted or explained in the study. | Heart Failure        | 28817241 |
| OSM5611      | Vitamin D deficiency | EXPOSURE      | Factor analyzed for its potential effect on heart failure risk.  | Vitamin D Deficiency | 28817241 |
| OSM5611      | Age                  | COVARIATE     | Baseline characteristic controlled for in the analyses.          | Age                  | 28817241 |
| OSM5611      | Gender               | COVARIATE     | Demographic characteristic controlled for in the analyses.       | Gender               | 28817241 |
| OSM5611      | Education            | COVARIATE     | Baseline characteristic controlled for in the analyses.          | Education            | 28817241 |
| OSM5611      | Ethnicity            | COVARIATE     | Baseline characteristic controlled for in the analyses.          | Ethnic Groups        | 28817241 |

### 5. Variable attribute extraction

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

#### API call

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
precision <- variables |> 
  comradeGPT::cmd_calc_precision(cols = c('variable_name', 
                                          'variable_type'))
precision |> head() |> knitr::kable()
```

| pmid     | variable_name        | variable_type | annotators | var_freq | agree_rate |
|:--------|:-------------------|:-------------|----------:|--------:|----------:|
| 28817241 | HEART FAILURE        | OUTCOME       |          5 |        3 |        0.6 |
| 28817241 | VITAMIN D DEFICIENCY | EXPOSURE      |          5 |        5 |        1.0 |
| 28817241 | AGE                  | COVARIATE     |          5 |        5 |        1.0 |
| 28817241 | GENDER               | COVARIATE     |          5 |        5 |        1.0 |
| 28817241 | EDUCATION            | COVARIATE     |          5 |        5 |        1.0 |
| 28817241 | ETHNICITY            | COVARIATE     |          5 |        5 |        1.0 |

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
  comradeGPT::cmd_calc_agreement(cols = c('variable_name', 
                                          'variable_type'))
agreement |> knitr::kable()
```

| pmid     | kappa |   z | p_value | annotators | type | token | min_vars | max_vars | mean_vars | rate_consensus | n_consensus_vars |
|:-----|----:|---:|-----:|------:|---:|----:|-----:|-----:|------:|---------:|----------:|
| 28817241 | 0.441 | 6.4 | 0.00000 |          5 |   21 |    94 |       18 |       19 |      18.8 |          0.966 |               19 |
| 29276677 | 0.067 | 1.0 | 0.32172 |          5 |   20 |    41 |        5 |       10 |       8.6 |          0.462 |                5 |
| 29330643 | 0.101 | 2.1 | 0.04005 |          5 |   40 |    87 |        8 |       25 |      19.9 |          0.689 |               17 |
| 29574441 | 0.039 | 0.7 | 0.46250 |          5 |   27 |    64 |        8 |       15 |      13.3 |          0.299 |                4 |
| 29596471 | 0.056 | 1.1 | 0.27493 |          5 |   31 |    82 |       11 |       21 |      17.4 |          0.647 |               15 |

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
