# cmd_prompts.R

#' Command Prompts for ResearchTextProcessor Package
#'
#' This list contains descriptions of various tasks related to processing and classifying scientific texts,
#' extracting key variables, and generating structured outputs for epidemiological and clinical research data.
#'
#' @name cmd_prompts
#' @export


cmd_prompts = list(
  
  
  
system_classify_text = 'You are an expert scientist skilled in analyzing observational, human-based studies. You excel at identifying whether research involves human subjects, uses non-interventional methods, and sources data from real-world settings. Your ability to quickly categorize and interpret complex academic texts makes you a valuable resource for researchers.',


system_extract_variables = "You are an epidemiologist creating a database for chronic disease research. This tool will catalog definitions of risk factors, treatments, outcomes, and covariates from studies. It will help researchers identify essential variables for data collection and offer methods for accurately annotating these variables in texts. Additionally, the database supports benchmarking causal feature selection methods that utilize structured knowledge.",


user_extract_variables = 'Task: Extract all EXPOSURE, OUTCOME, and COVARIATE variables included in the medical study presented below.

Instructions:
Identify Variables: Carefully read the study to identify variables used in the analysis. Ensure each variable is considered independently, even if presented in a list or grouped with others. 

Classifications:
EXPOSURE: These are the variables representing factors analyzed for their potential effects on an outcome. Factors can include lifestyle choices such as diet and physical activity, environmental influences like pollution, or genetic predispositions. Every study has at least ONE exposure variable.

OUTCOME: This is the variable being predicted or explained in the study. It is the main effect or condition the research aims to understand through its relation to various exposures. Every study has at least ONE outcome variable.

COVARIATE: These variables are included in the analysis to control for confounding factors that might influence both the exposure and the outcome. Common covariates include age, gender, and socioeconomic status.

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

STUDY:',


user_extract_attributes = 'You are tasked with creating a JSON output that includes structured data for a predefined LIST OF VARIABLES. Each entry in the JSON array should correspond to one variable, capturing various essential details such as its type and key descriptive attributes and features.

Variable features include:

Construct:
Definition: Represents the biomedical concept used in research to denote the broader variable of interest.
Example: "Body Mass Index (BMI)" as a construct for "Obesity".

Variable Concept Category:
Definition: Describes broader categories that individual constructs belong to, from genetics to socioeconomics.
Example: "Biology/Genetics" for APOEe4 status.

Source Terminology:
Definition: Specifies terminologies or classification systems used for clarity in variable definitions.
Example: "LOINC" for laboratory tests.

Codes:
Definition: Contains specific codes from medical terminologies that correspond to the variable.
Example: "E11" for Type 2 Diabetes Mellitus in ICD-10.

Timing Logic:
Definition: Outlines criteria for when and how data related to the variable is collected and analyzed.
Example: Blood pressure measurements taken annually over 20 years for a study on hypertension.

Complexity Indicator:
Definition: Identifies variables with complex definitions derived from multiple sources. As Yes or No.
Example: Major depressive disorder determined by diagnostic codes and prescription data.

Complex Definition:
Definition: Describes intricate phenotype definitions for complex scenarios.
Example: Diabetes definition involving multiple criteria including medication history.

Data Type:
Definition: Classifies the nature of data for each variable, influencing analysis methods.
Example: "Continuous" for variables like "Blood Pressure".

Ascertainment Source:
Definition: Indicates the source or method by which the variable\'s data was obtained.
Example: "EHR" for data from Electronic Health Records.

Ascertainment Notes:
Definition: Contains a simple description of how the variable was ascertained.
Example: Blood pressure measured using a standard sphygmomanometer after 5 minutes of rest.



OUTPUT:
Please provide ouput in a JSON array. The number of objects in the output JSON should equal the number of variables in the LIST OF VARIABLES. Each object should be structured with straightforward, flat hierarchy, avoiding nested structures.

"variable_name" and "variable_type" in output should be the same as variable_name and varable_type in LIST OF VARIABLES.


An incomplete example:

[
  {
    "variable_name": "AGE",
    "variable_type": "COVARIATE",
    "Construct": "Chronological measure of time since birth",
    "Variable_Concept_Category": "Demographics",
    "Source_Terminology": "Not applicable",
    "Codes": "Not applicable",
    "Timing_Logic": "Recorded at the time of study enrollment",
    "Complexity_Indicator": "No",
    "Complex_Definition": "Not applicable",
    "Data_Type": "Continuous",
    "Ascertainment_Source": "Self-reported or administrative records",
    "Ascertainment_Notes": "Verified by checking official documents when possible"
  },
  
  # ... 
  {
    "variable_name": "DIABETES",
    "variable_type": "COVARIATE",
    "Construct": "Metabolic disorder characterized by high blood sugar levels",
    "Variable_Concept_Category": "Underlying Health",
    "Source_Terminology": "ICD-10",
    "Codes": "E11 for Type 2 Diabetes Mellitus",
    "Timing_Logic": "Measured annually during routine check-ups",
    "Complexity_Indicator": "Yes",
    "Complex_Definition": "Based on glucose levels, HbA1c measurements, and/or medication usage",
    "Data_Type": "Categorical",
    "Ascertainment_Source": "Electronic Health Records (EHR)",
    "Ascertainment_Notes": "Confirmed by laboratory glucose tests and medication records"
  }
]


Ensure there is no trailing comma after the last element. DO NOT include the "```json " code block notation in the output.',



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

TEXT: '




)
