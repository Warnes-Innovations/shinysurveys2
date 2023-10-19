#' Generate the UI Code for demographic questions
#'
#' @param df One element (a dataframe) in the list of unique questions.
#'
#' @keywords internal
#' @return UI Code for a Shiny App.
#'
# == Insert
# library(shinyRadioMatrix)
splitter <- function(text){
  sapply(str_split(text, ","),str_trim) %>% as.vector()
}
# == End Insert

surveyOutput_individual <- function(df) {
  inputType <- base::unique(df$input_type)

  if (length(inputType) != 1) {
    if (!"instructions" %in% inputType) {
      stop("Please double check your data frame and ensure that the input type for all questions is supported.")
    } else if ("instructions" %in% inputType) {
      instructions <- df[which(df$input_type == "instructions"), "question", drop = FALSE]$question
      instructions <- shiny::tagList(
        shiny::div(class = "question-instructions",
                   instructions)
      )

      inputType <- inputType[which(inputType != "instructions")]
      df <- df[which(df$input_type != "instructions"),]
    }
  } else if (length(inputType == 1)) {
    instructions <- NULL
  }

  if (grepl("rank_{{", inputType, perl = T)) {
    stop('Ranking input types have been superseded by the "matrix" input type.')
  }

  if (!is.na(df$dependence)) {
      dependence_id <- df$dependence
      dependence_value <- df$dependence_value
      temp <- read_sheet(URL(), "survey_responses")
      id <- ifelse(nrow(temp) == 0, 1, max(temp$subject_id) + 1)
      response_df <- getSurveyData(id)
      print("In individual function")
      # Get the response for the dependent question
      dependent_response <- response_df[response_df$question_id == dependence_id, "response"]
  
      if (is.na(dependence_value)) {
        # Handle cases where dependence_value is NA, meaning any non-empty response triggers the dependent question
        has_response <- sum(!is.na(dependent_response) & dependent_response != "") > 0
      } else {
        # Handle cases where a specific value triggers the dependent question
        has_response <- sum(dependent_response == dependence_value) > 0
      }
  }
  else {
    has_response <- TRUE
  }
  output <- NULL

  survey_env$current_question <- df
  if(has_response){
    if (inputType ==  "select") {
      output <-
        shiny::selectizeInput(
          inputId = base::unique(df$input_id),
          label = addRequiredUI_internal(df),
          choices = df$option,
          options = list(
            placeholder = '',
            onInitialize = I('function() { this.setValue(""); }')
          )
        )
    } else if (inputType == "numeric") {
      output <-
        numberInput(
          inputId = base::unique(df$input_id),
          label = addRequiredUI_internal(df),
          placeholder = df$option
        )
  
    } else if (inputType == "mc") {
  
      output <-
        shiny::radioButtons(
          inputId = base::unique(df$input_id),
          label = addRequiredUI_internal(df),
          selected = base::character(0),
          choices = df$option
        )
    } else if (inputType == "multicheckbox") {
     # Create a checkbox group input for multiple choices
      output <- shiny::checkboxGroupInput(
        inputId = base::unique(df$input_id),
        label = addRequiredUI_internal(df),
        choices = df$option,
        selected = NULL
      )
    } else if (inputType == "text") {
  
      output <-
        shiny::textInput(inputId = base::unique(df$input_id),
                         label = addRequiredUI_internal(df),
                         placeholder = df$option)
  
    } else if (inputType == "y/n") {
  
      output <-
        shiny::radioButtons(
          inputId = base::unique(df$input_id),
          label = addRequiredUI_internal(df),
          selected = base::character(0),
          choices = df$option
        )
   # Insert ========
    } else if (inputType == "matrix") {
  
      required_matrix <- ifelse(all(df$required), TRUE, FALSE)
  
      #output <-
        #radioMatrixInput(
          #inputId = base::unique(df$input_id),
          #responseItems = base::unique(df$question),
          #choices = base::unique(df$option),
          #selected = NULL,
          #.required = required_matrix
        #)
      output <- matrixInput(
        # Comment
          inputId = base::unique(df$input_id),
          label = addRequiredUI_internal(df),
          value = matrix("",
                                 nrow=length(splitter(str_split(df$option,"/")[[1]][1])),
                                 ncol=length(splitter(str_split(df$option,"/")[[1]][2])),
                                 dimnames = list(splitter(str_split(df$option,"/")[[1]][1]),
                                                 splitter(str_split(df$option,"/")[[1]][2]))
          )
        )
  
    }
    else if(inputType == "radiomatrix"){
      required_matrix <- ifelse(all(df$required), TRUE, FALSE)
      question_prompt <- addRequiredUI_internal(df)
      #rowlabels
      s1 <- splitter(str_split(df$option,"/")[[1]][1])
      #choices
      s2 <- splitter(str_split(df$option,"/")[[1]][2])
      #row IDs
      s3 <-  splitter(str_split(df$option,"/")[[1]][3])
      # For IDs, create sequence starting from s3 of length equal to s1 length.
      # So each row of radio matrix has unique ID
      output <- shinyRadioMatrix::radioMatrixInput(
                                         inputId = base::unique(df$input_id),
                                         rowIDs = as.numeric(s3):(as.numeric(s3) + length(s1) - 1),
                                         rowLLabels = s1,
                                         rowRLabels = NULL,
                                         choices = s2,
                                         selected = NULL,
                                         choiceNames = NULL,
                                         choiceValues = NULL,
                                         rowIDsName="",
                                         labelsWidth = list(NULL, NULL))
  
      output <- shiny::tagList(
        shiny::div(class = "question-prompt", question_prompt),
        output
      )
    }
  # End Insert ========
    else if (inputType == "instructions") {
  
      output <- shiny::div(
        class = "instructions-only",
        shiny::markdown(df$question)
      )
  
    } else if (inputType %in% survey_env$input_type) {
      output <- eval(survey_env$input_extension[[inputType]])
    } else {
      stop(paste0("Input type '", inputType, "' from the supplied data frame of questions is not recognized by {shinysurveys}.
                  Did you mean to register a custom input extension with `extendInputType()`?"))
    }
  }

  return(output)

}

surveyOutput <- function(df, url, survey_title, survey_description, theme = "#63B8FF", ...) {

  survey_env$theme <- theme
  survey_env$question_df <- df
  survey_env$unique_questions <- listUniqueQuestions(df)
  if (!missing(survey_title)) {
    survey_env$title <- survey_title
  }
  if (!missing(survey_description)) {
    survey_env$description <- survey_description
  }

  if ("page" %in% names(df)) {
    main_ui <- multipaged_ui(df = df)
  } else if (!"page" %in% names(df)) {
    main_ui <- shiny::tagList(
      check_survey_metadata(survey_title = survey_title, survey_description = survey_description),
      lapply(survey_env$unique_questions, function(df) surveyOutput_individual(df, url)),
      shiny::div(class = "survey-buttons",
                 shiny::actionButton("submit", "Submit", ...)
      )
    )
  }

  if (!is.null(survey_env$theme)) {
    survey_style <- sass::sass(list(
      list(color = survey_env$theme),
      readLines(
        system.file("render_survey.scss",
                    package = "shinysurveys")
      )
    ))
  } else if (is.null(survey_env$theme)) {
    survey_style <- NULL
  }


  shiny::tagList(shiny::includeScript(system.file("shinysurveys-js.js",
                                                  package = "shinysurveys")),
                 shiny::includeScript(system.file("save_data.js",
                                                  package = "shinysurveys")),
                 shiny::tags$style(shiny::HTML(survey_style)),
                 shiny::div(class = "survey",
                            shiny::div(style = "display: none !important;",
                                       shiny::textInput(inputId = "userID",
                                                        label = "Enter your username.",
                                                        value = "NO_USER_ID")),
                            main_ui))

}
