
#----0.Setup and Libraries---------------------------------------------------------------------------

library(dplyr)
library(stringr)
library(readxl)
library(openxlsx)
library(car)
library(tidyverse)
library(broom)

#----1.Creating state level dataset---------------------------------------------------------------------------
# Getting a list of all state folders in the parent folder
state_folders <- list.dirs(getwd(), recursive = FALSE, full.names = FALSE)

#Combining the datasets under each state folder using for loop
for (state in state_folders) {
  # Creating the full path to the current state folder
  state_folder_path <- file.path(getwd(), state)
  
  # Listing all Excel files in the folder
  excel_files <- list.files(state_folder_path,
                            pattern = "\\.xlsx$|\\.xls$",
                            full.names = TRUE)
  
  # Skipping if no Excel files are found
  if (length(excel_files) == 0) {
    print(paste("No Excel files found in", state, ". Skipping."))
    next
  }
  
  #Combining the data
  data_list <- lapply(excel_files, function(file) {
    #Skipping if file not found
    read_excel(file, skip = 1)  
  })
  combined_data <- do.call(rbind, data_list)
  
  # Defining the output file path
  output_file_path <- file.path(state_folder_path, paste0(state, "_combined.xlsx"))
  
  # Writing the combined data to a new Excel file
  write.xlsx(combined_data, output_file_path)
  
  print(paste("Successfully combined files for", state, "and saved to", output_file_path))
}

#Adding a state name column to the state datasets
all_state_data_list <- list()
for (state in state_folders) {
  # Constructing the expected combined file name
  combined_file_name <- paste0(state, "_combined.xlsx")
  combined_file_path <- file.path(getwd(), state, combined_file_name)
  
  # Checking if the combined file exists
  if (file.exists(combined_file_path)) {
    state_data <- read_excel(combined_file_path)
    state_data_with_state <- state_data %>%
      mutate(State = state)
    
    # Adding the modified data frame to our list
    all_state_data_list[[state]] <- state_data_with_state
    
    print(paste("Successfully read and added state name to data from", state))
  } else {
    print(paste("Combined file not found for", state, ". Skipping."))
  }
}

#----2.Creating a master dataset---------------------------------------------------------------------------

# Combining all state datasets into a master dataset
master_combined_data <- bind_rows(all_state_data_list)
master_output_file_path <- file.path(getwd(), "All_States_Combined_Master.xlsx")

# Saving the master data frame to a new Excel file
write.xlsx(master_combined_data, master_output_file_path)
print(paste("All combined files have been merged into a single master file:", master_output_file_path))
print(head(master_combined_data$`Gram Panchayat Details`))

#Extracting the panchayat, block and district names from the string in column 1 using sapply
split_names <- sapply(strsplit(as.character(master_combined_data$`Gram Panchayat Details`), "-\\["), `[`, 1)
final_names <- sub("GP - ", "", split_names)

# Assigning the names to new columns
master_combined_data$Extracted_GP_Name <- final_names
block_district_data <- sapply(strsplit(as.character(master_combined_data$`Gram Panchayat Details`), "Block - "), `[`, 2)
master_combined_data$Extracted_Block_Name <- sapply(strsplit(block_district_data, "District - "), `[`, 1)
master_combined_data$Extracted_District_Name <- sapply(strsplit(as.character(master_combined_data$`Gram Panchayat Details`), "District - "), `[`, 2)

#Checking for the column names
names(master_combined_data)

#Creating a dataset with the required columns only
PAI_data <- master_combined_data %>%
  select(State,Extracted_GP_Name,Extracted_Block_Name,Extracted_District_Name,
         `Overall PAI Score` ,                                  
        `T1 - Poverty Free and Enhanced Livelihoods Panchayat`,
       `T2 - Healthy Panchayat`  ,                            
        `T3 - Child Friendly Panchayat`   ,                    
         `T4 - Water Sufficient Panchayat`,                     
      `T5 - Clean and Green Panchayat`   ,                   
         `T6 - Self-sufficient Infrastructure in Panchayat`,    
        `T7 - Socially Just and Socially Secured Panchayat`   ,
        `T8 - Panchayat with Good Governance`    ,             
          `T9 - Women Friendly Panchayat`) %>%
  rename("Gram Panchayat" = "Extracted_GP_Name",
         "Block" = "Extracted_Block_Name",
         "District" = "Extracted_District_Name",
         "T1" = "T1 - Poverty Free and Enhanced Livelihoods Panchayat" ,
         "T2"= "T2 - Healthy Panchayat",
         "T3"="T3 - Child Friendly Panchayat",
         "T4"="T4 - Water Sufficient Panchayat",
         "T5"="T5 - Clean and Green Panchayat",
         "T6"="T6 - Self-sufficient Infrastructure in Panchayat",
         "T7"="T7 - Socially Just and Socially Secured Panchayat",
         "T8"="T8 - Panchayat with Good Governance",
         "T9"="T9 - Women Friendly Panchayat")

#Checking the column names
names(PAI_data)
#Getting the summary of the dataset
summary(PAI_data)


#----3.Cleaning the master dataset---------------------------------------------------------------------------

#Splitting the data in columns 5 to 14
columns_to_split <- names(PAI_data)[5:14] 
print(columns_to_split)
head(PAI_data$`Overall PAI Score`)

# Looping through each of the specified columns
for (col_name in columns_to_split) {
  column_data <- as.character(PAI_data[[col_name]])
  
  # Replacing NA values with an empty string to prevent errors
  column_data[is.na(column_data)] <- ""
  
  # Splitting the string by one or more spaces
  split_data <- strsplit(column_data, "\\s+")
  #Extracting the value
  value <- sapply(split_data, function(x) if (length(x) > 0) x[1] else NA_character_)
  rating <- sapply(split_data, function(x) if (length(x) > 1) x[2] else NA_character_)
  
  # Creating new columns with the extracted data
  PAI_data[[paste0(col_name, " Value")]] <- as.numeric(value)
  PAI_data[[paste0(col_name, " Rating")]] <- rating
}

#Checking for column names
names(PAI_data)
PAI_data_raw <- PAI_data

#Arranging the dataset using select
PAI_data <- PAI_data_raw %>%
  select("State","Gram Panchayat","Block" , 
         "District",    "Overall PAI Score Value" ,
         "Overall PAI Score Rating", "T1 Value",      "T1 Rating",
         "T2 Value",      "T2 Rating",     "T3 Value", 
         "T3 Rating",     "T4 Value",      "T4 Rating",
         "T5 Value",      "T5 Rating",     "T6 Value" , 
         "T6 Rating",     "T7 Value",      "T7 Rating", 
         "T8 Value",      "T8 Rating",     "T9 Value" ,
         "T9 Rating"    )

#Trimming the white spaces in the dataset
PAI_data <- PAI_data %>%
  mutate(across(where(is.character), trimws))


#----4.Estimating the weights using a regression model---------------------------------------------------------------------------

#Using a regression model to estimate the weights used to aggregate the overall PAI score
weight_est <- `Overall PAI Score Value` ~ `T1 Value` + `T2 Value` + `T3 Value`+ `T4 Value` + `T5 Value` + `T6 Value` + `T7 Value` + `T8 Value`+ `T9 Value`
weight_est_model <- lm(weight_est, data = PAI_data)
summary(weight_est_model)

#Checking the reliability of the model using vif function
vif(weight_est_model)

# Extracting and normalizing weights
weights <- coef(weight_est_model)
normalized_weights <- weights[-1] / sum(weights[-1])

# Weighted standard deviation function
weighted_sd_func <- function(scores, weights) {
  values <- !is.na(scores)
  scores <- scores[values]
  weights <- weights[values]
  weighted_mean <- sum(scores * weights) / sum(weights)
  weighted_variance <- sum(weights * (scores - weighted_mean)^2) / sum(weights)
  return(sqrt(weighted_variance))
}

#----5.Creating metrics for analysis---------------------------------------------------------------------------

# Computing weighted SD and other metrics for each panchayat
PAI_Metric <- PAI_data %>%
  rowwise() %>%
  mutate(
    Weighted_SD = weighted_sd_func(
      scores = c(`T1 Value`, `T2 Value`, `T3 Value`, `T4 Value`, `T5 Value`, `T6 Value`, `T7 Value`, `T8 Value`, `T9 Value`),
      weights = normalized_weights
    ),
    Weighted_Mean = sum(c(`T1 Value`, `T2 Value`, `T3 Value`, `T4 Value`, `T5 Value`, `T6 Value`, `T7 Value`, `T8 Value`, `T9 Value`) * normalized_weights) / sum(normalized_weights),
    Performance_Gap = `Overall PAI Score Value` - Weighted_Mean
  ) %>%
  ungroup()

# Ranking panchayats based on stability (low SD) and performance
PAI_Metric <- PAI_Metric %>%
  mutate(
    Stability_Rank = rank(Weighted_SD, ties.method = "min"),
    Performance_Rank = rank(desc(`Overall PAI Score Value`), ties.method = "min")
  )

         
#Ranking panchayats within states
PAI_Ranks <- PAI_Metric
PAI_State_Ranks <- PAI_Metric %>%
  group_by(State) %>%
  mutate(
    Stability_State_Rank = rank(Weighted_SD, ties.method = "min"),
    Performance_State_Rank = rank(desc(`Overall PAI Score Value`), ties.method = "min")
  ) %>%
  ungroup()

#Saving the datasets
write.xlsx(PAI_Ranks,"PAI_Ranks.xlsx",row.names = FALSE)
write.xlsx(PAI_State_Ranks,"PAI_State_Ranks.xlsx",row.names = FALSE)

#----6.Ranking the panchayats based on the metrics---------------------------------------------------------------------------

#Getting the range of all three metrics for analysis
PAI_State_Ranks_data <- read.xlsx("PAI_State_Ranks.xlsx")
names(PAI_State_Ranks_data)
range_overall_PAI <- range(PAI_State_Ranks_data$Overall.PAI.Score.Value, na.rm = TRUE)
print(range_overall_PAI)
range_SD <- range(PAI_State_Ranks_data$Weighted_SD, na.rm = TRUE)
print(range_SD)
range_performance <- range(PAI_State_Ranks_data$Performance_Gap, na.rm = TRUE)
print(range_performance)

#----7.Creating state level dataset with aggregated metric scores---------------------------------------------------------------------------

#Aggregating the metrics at state level 
state_summary <- PAI_State_Ranks_data %>%
  group_by(State) %>%
  summarise(
    Mean_Overall = mean(Overall.PAI.Score.Value, na.rm = TRUE),
    Mean_Weighted_SD = mean(Weighted_SD, na.rm = TRUE)
  ) %>%
  ungroup()
state_summary <- state_summary %>%
  mutate(
    Category = case_when(
      Mean_Overall >= median(Mean_Overall, na.rm = TRUE) & Mean_Weighted_SD <= median(Mean_Weighted_SD, na.rm = TRUE) ~ "High Perf & High Balance",
      Mean_Overall >= median(Mean_Overall, na.rm = TRUE) & Mean_Weighted_SD > median(Mean_Weighted_SD, na.rm = TRUE) ~ "High Perf & Low Balance",
      Mean_Overall < median(Mean_Overall, na.rm = TRUE) & Mean_Weighted_SD <= median(Mean_Weighted_SD, na.rm = TRUE) ~ "Low Perf & High Balance",
      TRUE ~ "Low Perf & Low Balance"
    )
  )

#Saving the dataset
write.csv(state_summary,"State_Summary.csv")


#----------------------------------------------------------------------------------------------------------------------------------------------------------



