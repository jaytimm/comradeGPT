# cmd_prompts.R

#' Command Prompts for comradeGPT
#'
#' This list contains descriptions of various tasks related to processing and classifying scientific texts,
#' extracting key variables, and generating structured outputs for epidemiological and clinical research data.
#'
#' @name cmd_prompts
#' @export


cmd_prompts = list(
  
  
  
system_classify_text = 'You are an expert scientist skilled in analyzing observational, human-based studies. You excel at identifying whether research involves human subjects, uses non-interventional methods, and sources data from real-world settings. Your ability to quickly categorize and interpret complex academic texts makes you a valuable resource for researchers.',


system_extract_variables = "As an expert epidemiologist, your primary responsibility is to identify and extract detailed information from chronic disease research studies. This includes not only definitions of risk factors, treatments, outcomes, and covariates, but also population characteristics, study overviews, study characteristics, and variable attributes. Utilizing your expertise in epidemiology and data annotation, you will ensure the precise extraction and accurate classification of these elements. Your skills in structured knowledge and causal feature selection methods will support researchers in identifying essential variables for data collection and ensuring the reliability of the annotated data for further research.",


user_extract_variables = 'Task: Extract all EXPOSURE, OUTCOME, and COVARIATE variables included in the medical study presented below.

Instructions:
Identify Variables: Carefully read the study to identify variables used in the analysis. Ensure each variable is considered independently, even if presented in a list or grouped with others. 

Classifications:
EXPOSURE: These are the variables representing factors analyzed for their potential effects on an outcome. Factors can include lifestyle choices such as diet and physical activity, environmental influences like pollution, or genetic predispositions. Every study has at least ONE exposure variable.

OUTCOME: This is the variable being predicted or explained in the study. It is the main effect or condition the research aims to understand through its relation to various exposures. Every study has at least ONE outcome variable.

COVARIATE: These variables are included in the analysis to control for confounding factors that might influence both the exposure and the outcome. Common covariates include age, gender, and socioeconomic status. Treat Race and Ethnicity as a single variable labeled as RACE.

Please list only the fundamental concept of each variable, excluding any specific details related to age, timing, or measurement intervals. Focus on the general category or type of each variable to ensure the output is concise and universally applicable, without being tied to a particular time frame or demographic detail.


For each extracted variable, please determine the most appropriate Medical Subject Headings (MeSH) descriptor using your specialized knowledge. For linking extracted variables to MeSH terms, assign EXPOSURE variables to categories related to environmental or behavioral influences, COVARIATE variables to demographic or baseline characteristics, and OUTCOME variables to specific health conditions or disease outcomes.

Output Format:
Provide the results as a JSON array.
Each object in the array should include four elements: "variable_name", "variable_type", "explanation", and "mesh_descriptor".

Example format:

[
  {"variable_name": "Systolic Blood Pressure", variable_type": "EXPOSURE", "explanation": "Measure of blood pressure being analyzed for association with dementia.", "mesh_descriptor": "Blood pressure"},
  {"variable_name": "Age", "variable_type": "COVARIATE", "explanation": "Sociodemographic factor adjusted for in the analyses.", "mesh_descriptor": "age"},
  {"variable_name": "Dementia","variable_type": "OUTCOME", "explanation": "Outcome variable being predicted or explained in the study.", "mesh_descriptor": "Dementia"}
]

Ensure there is no trailing comma after the last element.
DO NOT include the "```json " code block notation in the output.

Extract each covariate variable as a separate JSON object. Specifically, avoid grouping variables under broad categories such as "Health Behaviors" or "Sociodemographic Factors".  Instead, specify each factor individually, such as "age", "ethnicity", "smoking", "alcohol consumption", "BMI", and "diabetes". Each entry should be clearly separated and presented as an independent JSON object.


Extract the OUTCOME variable first. Only after the OUTCOME variable has been extracted, extract the EXPOSURE and COVARIATE variables.

Do NOT use acronymns in output -- use full, expanded names for variables.

STUDY:',



# Each object should have 12 key-value pairs: "variable_name", "variable_type", "construct", "variable_concept_category", "source_terminology", "codes", "timing_logic", "complexity_indicator", "complex_definition", "data_type", "ascertainment_source", and "ascertainment_notes".


user_extract_attributes = 'You are tasked with extracting ELEVEN attributes for each variable in a predefined LIST OF VARIABLES from a PubMed article. 

Variable attributes include:

Variable Type:
Definition: Exposure variables are assessed for their impact on outcomes and include factors such as lifestyle, environment, or genetics, with each study requiring at least one. Outcome variables are the primary focus of a study, intended to be explained or predicted, and covariate variables control for confounders like age, gender, and socioeconomic status,
Value type: string ["EXPOSURE", "OUTCOME", "COVARIATE"]

Construct:
Definition: Represents the biomedical concept used in research to denote the broader variable of interest.
Example: "Body Mass Index (BMI)" as a construct for "Obesity". 
Value type: string or NA.

Variable Concept Category:
Definition: Describes broader categories that individual constructs belong to, from genetics to socioeconomics.
Example: "Biology/Genetics" for APOEe4 status. 
Value type: string or NA.

Source Terminology:
Definition: Specifies terminologies or classification systems used for clarity in variable definitions.
Example: "LOINC" for laboratory tests.
Value type: string or NA.

Codes:
Definition: Contains specific codes from medical terminologies that correspond to the variable.
Example: "E11" for Type 2 Diabetes Mellitus in ICD-10.
Value type: string or NA.

Timing Logic:
Definition: Outlines criteria for when and how data related to the variable is collected and analyzed.
Example: Blood pressure measurements taken annually over 20 years for a study on hypertension.
Value type: string or NA.

Complexity Indicator:
Definition: Identifies variables with complex definitions derived from multiple sources. 
Example: Major depressive disorder determined by diagnostic codes and prescription data.
Value type: string ["yes", "no"] or NA.

Complex Definition:
Definition: Describes intricate phenotype definitions for complex scenarios.
Example: Diabetes definition involving multiple criteria including medication history.
Value type: string or NA.

Data Type:
Definition: Classifies the nature of data for each variable, influencing analysis methods.
Example: "Continuous" for variables like "Blood Pressure".
Value type: string ["continuous", "categorical", "binary"] or NA.

Ascertainment Source:
Definition: Indicates the source or method by which the variable\'s data was obtained.
Example: "EHR" for data from Electronic Health Records.
Value type: string or NA.

Ascertainment Notes:
Definition: Contains a simple description of how the variable was ascertained.
Example: Blood pressure measured using a standard sphygmomanometer after 5 minutes of rest.
Value type: string or NA.


OUTPUT:

For each variable attribute, set the value to \'NA\' if it is not explicitly mentioned or cannot be directly derived from the article. However, for attributes such as \'variable_concept_category\', \'construct\', and \'data_type\', you may infer these attributes based on widely accepted definitions.

Please provide ouput in a JSON array. The number of objects in the output JSON should equal the number of variables in the LIST OF VARIABLES. "variable_name" in output JSON should be the same as the "variable_name" in the LIST OF VARIABLES.

An incomplete example of well-structured output:

[
  {
    "variable_name": "VITAMIN D DEFICIENCY",
    "variable_type": "EXPOSURE",
    "construct": "Deficiency in vitamin D levels",
    "variable_concept_category": "Biomarkers",
    "source_terminology": "NA",
    "codes": "NA",
    "timing_logic": "Measured at the time of study enrollment",
    "complexity_indicator": "no",
    "complex_definition": "NA",
    "data_type": "categorical",
    "ascertainment_source": "Laboratory tests",
    "ascertainment_notes": "Measured using serum concentration of 25‐hydroxyvitamin D"
  },
  {
    "variable_name": "HYPERTENSION",
    "variable_type": "COVARIATE",
    "construct": "Condition characterized by high blood pressure",
    "variable_concept_category": "Underlying Health",
    "source_terminology": "ICD-10",
    "codes": "I10 for Essential (primary) hypertension",
    "timing_logic": "Measured during routine check-ups",
    "complexity_indicator": "no",
    "complex_definition": "NA",
    "data_type": "categorical",
    "ascertainment_source": "Medical records",
    "ascertainment_notes": "Diagnosed based on blood pressure measurements"
  },
  
  # ...
  
  {
    "variable_name": "DIABETES MELLITUS",
    "variable_type": "COVARIATE",
    "construct": "Metabolic disorder characterized by high blood sugar levels",
    "variable_concept_category": "Underlying Health",
    "source_terminology": "ICD-10",
    "codes": "E11 for Type 2 Diabetes Mellitus",
    "timing_logic": "Measured annually during routine check-ups",
    "complexity_indicator": "yes",
    "complex_definition": "Based on glucose levels, HbA1c measurements, and/or medication usage",
    "data_type": "categorical",
    "ascertainment_source": "Electronic Health Records (EHR)",
    "ascertainment_notes": "Confirmed by laboratory glucose tests and medication records"
  },
  {
    "variable_name": "RISK OF HEART FAILURE",
    "variable_type": "OUTCOME",
    "construct": "Likelihood of developing heart failure",
    "variable_concept_category": "Clinical Outcome",
    "source_terminology": "NA",
    "codes": "NA",
    "timing_logic": "Assessed during routine check-ups",
    "complexity_indicator": "yes",
    "complex_definition": "Based on Health ABC HF score",
    "data_type": "categorical",
    "ascertainment_source": "Clinical assessments",
    "ascertainment_notes": "Determined using the Health ABC scale"
  }
]


Ensure there is no trailing comma after the last element. 
DO NOT include the "```json " code block notation in the output.',



user_classify_text = 'Your task is to classify scientific texts by answering the following questions:

Subject Matter: Is the text discussing human subjects?
Study Type: Is the study observational?
Data Source: Is the data derived from real-world settings without manipulation?

This will help determine the nature and methodology of the studies discussed in the texts.

Ouput format:

Provide the results as a JSON array. Expected format is detailed below:

[
  {
    "question": "is_subject_human",
    "answer": "yes",
    "explanation": "The text discusses observational data collected from a group of human participants, focusing on their health outcomes over several years."
  },
  {
    "question": "is_study_observational",
    "answer": "yes",
    "explanation": "The study is classified as observational because it involves monitoring subjects without intervening or altering their normal behaviors."
  },
  {
    "question": "is_data_from_real_world",
    "answer": "yes",
    "explanation": "The data were collected in real-world settings, such as hospitals and community centers, without any experimental manipulation."
  }
]


Ensure there is no trailing comma after the last element.
DO NOT include the "```json " code block notation in the output.

STUDY: ',


user_extract_popchars = '

Task: Extract and categorize all details regarding the sample characteristics used in the medical study presented below.

Instructions:
  
Extract Sample Characteristics: Carefully read the study to identify and extract characteristics of study sample. Treat each characteristic independently, even if presented in a grouped format.

Extract "Categories": "Categories" refer to specific groups within a characteristic, used to segment participants. For instance, if the study segments participants by age, you might see categories such as "Under 18", "19-35", "36-55", and "Over 55". For geographic distribution, categories could be "Urban", "Suburban", "Rural". Health-related categories might include "With Diabetes", "Without Diabetes".

Use Direct Text Extraction: Extract the text directly from the study without paraphrasing. Only interpret to classify the characteristic accurately.

Define class: For each identified sample characteristic, classify it into one of the following classes: "Demographic", "Geographic", "Health-Related", or "Other".
  
Output Requirements:

Structured Details: For each sample characteristic identified, extract categories, counts and percentages. If not specified, use "NA".

Output Format: The output must be a JSON array. Each object in the array must include the following fields: "characteristic", "class", "explanation", "categories", "counts", and "percentages".

Example Format:

[
  {
    "characteristic": "Age",
    "class": "Demographic",
    "explanation": "The distribution of age groups among the elderly participants.",
    "categories": ["60-69", "70-79", "80+"],
    "counts": [46, 43, 9],
    "percentages": ["46.6%", "43.8%", "9.5%"]
  },
  {
    "characteristic": "Gender",
    "class": "Demographic",
    "explanation": "The distribution of male and female participants.",
    "categories": ["Male", "Female"],
    "counts": [48, 152],
    "percentages": ["24.1%", "75.9%"]
  },
  {
    "characteristic": "Region",
    "class": "Geographic",
    "explanation": "The distribution of participants by region.",
    "categories": ["North", "South", "East", "West"],
    "counts": [20, 30, 25, 25],
    "percentages": ["20%", "30%", "25%", "25%"]
  },
  {
    "characteristic": "Prevalence of Diabetes",
    "class": "Health-Related",
    "explanation": "The distribution of participants with and without a diagnosis of diabetes.",
    "categories": ["With Diabetes", "Without Diabetes"],
    "counts": [15, 85],
    "percentages": ["15%", "85%"]
  },
  {
    "characteristic": "Employment Status",
    "class": "Other",
    "explanation": "The employment status of participants.",
    "categories": ["Employed", "Unemployed", "Retired"],
    "counts": [100, 40, 60],
    "percentages": ["50%", "20%", "30%"]
  },
  {
    "characteristic": "Prevalence of Hypertension",
    "class": "Health-Related",
    "explanation": "The distribution of participants with and without a diagnosis of hypertension.",
    "categories": ["With Hypertension", "Without Hypertension"],
    "counts": [50, 150],
    "percentages": ["25%", "75%"]
}

]

Ensure there is no trailing comma after the last element. Output should not include any code block notation (e.g., \'```json\').

STUDY:

',


user_extract_summary = '
Task: Extract and categorize detailed information from the medical study presented below.

Instructions:

Identify Study Characteristics: Carefully read the study to identify key details such as study design, population size, covariate definitions, major results, effect size, confidence intervals, and p-value. Ensure each characteristic is considered independently, even if presented in a list or grouped with others.

Use Direct Text Extraction: To ensure precision and consistency across multiple annotators, extract the language directly from the text. 


Characteristics:

Study Design: 
Definition: Provides a comprehensive description of the study\'s methodology, capturing specific design types and other pertinent information such as study duration, setting, and interventions or exposures assessed.
Data type: string or NA.

Population Size: 
Definition: Contains the total number of participants in the study, specifying the number of cases and controls, if applicable. 
Data type: integer or NA.

Covariate Definitions in Maintext: 
Definition: Indicates whether the main text of the research article mentions covariates used to adjust for confounding factors. Annotators mark "Y" if covariate details are explicitly stated, "N" if not mentioned, and "S" if details are in supplementary materials. 
Data type: string ["Y", "N", "S"] or NA.

Major Results: 
Definition: Summarizes the primary findings of the study in a concise manner. 
Data type: string.

Effect Size: 
Definition: Provides the quantitative measure of the strength of the association between the exposure and the outcome. 
Data type: numeric or NA.

Lower Confidence Interval: 
Definition: Contains the lower boundary of the confidence interval for the effect size, indicating the range of uncertainty surrounding the estimate. 
Data type: numeric or NA.

Upper Confidence Interval: 
Defintion: Contains the upper boundary of the confidence interval for the effect size, indicating the range of uncertainty surrounding the estimate. 
Data type: numeric or NA.

P-Value: 
Definition: Contains the p-value of the study findings, indicating the likelihood that the observed association is not due to chance. 
Data type: numeric or NA.

Output Format:
Provide the results as a JSON array. Each object in the array should include three elements: "field", "value", and "explanation".

For each study characteristic, set the value to \'NA\' if it is not explicitly mentioned or cannot be directly derived from the article.

Example format:

  [
    {
      "field": "Study Design",
      "value": "cross-sectional study",
      "explanation": "The study description specified it as a cross-sectional study."
    },
    {
      "field": "Population Size",
      "value": "800",
      "explanation": "The study comprised 800 participants, with 400 cases and 400 controls."
    },
    {
      "field": "Covariate Definitions in Maintext",
      "value": "S",
      "explanation": "The article states that covariate details can be found in Supplement A, Table C."
    },
    {
      "field": "Major Results",
      "value": "Participants with high levels of physical activity had a 25% lower risk of developing dementia compared to those with low activity levels, aOR=0.75.",
      "explanation": "This was the primary finding reported in the results section."
    },
    {
      "field": "Effect Size",
      "value": "0.75",
      "explanation": "The odds ratio (OR) for developing dementia in the high physical activity group was reported as 0.75."
    },
    {
      "field": "Lower Confidence Interval",
      "value": "0.60",
      "explanation": "The lower limit of the 95% Confidence Interval (CI) for the OR was reported as 0.60."
    },
    {
      "field": "Upper Confidence Interval",
      "value": "0.90",
      "explanation": "The upper limit of the 95% CI for the OR was reported as 0.90."
    },
    {
      "field": "P-Value",
      "value": "0.02",
      "explanation": "The p-value for the association between physical activity and dementia risk was reported as 0.02."
    }
  ]

Ensure there is no trailing comma after the last element. DO NOT include the "```json " code block notation in the output.

STUDY:
',



user_normalize_variables = '

TASK: Normalize the following variable names to a consistent format using standardized medical terminology. This involves addressing variations in spelling, plural forms, acronyms, synonyms, and phrasing, and simplifying lengthy and complex names to their CORE CONCEPTS by removing unnecessary modification terms. For each normalized variable, determine the most appropriate Medical Subject Headings (MeSH) descriptor using your specialized knowledge.


Examples of Normalization

Variations in Spelling, Plural Forms, Acronyms, Synonyms, and Phrasing:
"smoking" and "smoking status" should be unified as "SMOKING".
"body-mass index", "BMI", and "body mass indices" should be unified as "BODY MASS INDEX".
"amyloid-β status", "amyloid-β positivity/negativity", and "amyloid beta status" should be unified as "AMYLOID STATUS".
"gender" and "sex" should be unified as "SEX".


Simplification of Lengthy and Complex Variable Names:
"LEFT VENTRICULAR END-DIASTOLIC VOLUME INDEX" should be simplified to "LEFT VENTRICULAR VOLUME".
"FASTING PLASMA GLUCOSE CONCENTRATION AT MORNING" should be simplified to "PLASMA GLUCOSE".
"BLOOD PRESSURE DURING EXERCISE TEST" should be simplified to "BLOOD PRESSURE".
"SERUM C-REACTIVE PROTEIN LEVEL IN ADULTS" should be simplified to "C-REACTIVE PROTEIN".
"PRE-OPERATIVE BODY MASS INDEX" should be simplified to "BODY MASS INDEX".
Output Format:

Provide the results as a JSON array. Each object in the array should include three elements: "variable_name", "variable_concept", and "mesh_descriptor". 

Ensure that the "mesh_descriptor" accurately reflects the standardized medical terminology for each concept.

Use MesH DescriptorName not MeSH TermName.

If the variable name does not make sense or if it has no equivalent MeSH descriptor, set the mesh_descriptor element in the JSON output to "NA".

An incomplete example of well-structured output:

[
{
"variable_name": "SMOKING STATUS",
"variable_concept": "SMOKING",
"mesh_descriptor": "Smoking"
},
{
"variable_name": "BMI",
"variable_concept": "BODY MASS INDEX",
"mesh_descriptor": "Body Mass Index"
},
{
"variable_name": "AMYLOID-Β POSITIVITY/NEGATIVITY",
"variable_concept": "AMYLOID STATUS",
"mesh_descriptor": "Amyloid beta-Peptides"
},
{
"variable_name": "CHILDHOOD COGNITION SCORE",
"variable_concept": "CHILDHOOD COGNITION",
"mesh_descriptor": "Cognition"
},
{
"variable_name": "GENDER",
"variable_concept": "SEX",
"mesh_descriptor": "Sex"
}
]

Ensure there is no trailing comma after the last element. DO NOT include the "```json " code block notation in the output.

VARIABLE NAMES:

'


)