library(shiny)
library(datasets)
library(dplyr)

mpgData <- mtcars
mpgData$am <- factor(mpgData$am, labels= c("Automatic", "Manual"))


ui <- pageWithSidebar(
  headerPanel("Miles Per gallon"),
  
  sidebarPanel(
    selectInput("variable","Variable:",list("Cylinders" = "cyl",
                                            "Transmission" = "am",
                                            "Gears" = "gear")),
    checkboxInput("outliers", "Show outliers", FALSE),
    selectInput("select","select a kind of element",c("All","Automatic","Manual"),multiple = TRUE)
  ),
  mainPanel(
    h3(textOutput("caption")),
    plotOutput("mpgPlot"),
    verbatimTextOutput("summary"),
    tableOutput("table")
  )
)


server <- function(input, output){
  formulaText <- reactive({
    paste("mpg ~", input$variable)
  })
  
  #it is fine to use paste("mpg ~", input$variable) directly, 
  #but define a new name is easier to reuse
  
  output$caption <- renderText({
    formulaText()
    #    paste("mpg ~", input$variable)
  })
  
  output$mpgPlot <- renderPlot({
    #    boxplot(as.formula(paste("mpg ~", input$variable)),
    boxplot(as.formula(formulaText()),
            data = mpgData,
            outline = input$outliers)
  })
  #mpg~variable
  #mpg is a vector to be split by variable; 
  #variable is a factor to define group
  output$summary <- renderPrint({
    summary(mpgData)
    input$select
  })
  output$table <- renderTable({
    mpgData
#    if (input$select=="All")
#      mpgData
#    else
#      filter(mpgData,am==input$select)
  })
}

shinyApp(ui = ui, server = server)