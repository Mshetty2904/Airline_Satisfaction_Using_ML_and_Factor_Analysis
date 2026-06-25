library(shiny)
library(bslib)
library(bsicons)
library(plotly)
library(dplyr)
library(htmltools)

# 1. Load the pre-trained model artifact
model <- readRDS("airplane_log_model.rds")

# 2. Custom CSS for Smooth Transitions & Glowing Hover Effects
custom_css <- "
  /* Smooth transitions for all cards */
  .card {
    transition: transform 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275), box-shadow 0.4s ease !important;
    border: 1px solid rgba(56, 189, 248, 0.1) !important;
  }
  /* Holographic lift effect on hover */
  .card:hover {
    transform: translateY(-4px);
    box-shadow: 0 12px 24px rgba(56, 189, 248, 0.15) !important;
    border: 1px solid rgba(56, 189, 248, 0.4) !important;
  }
  /* Pulse animation for the Status Box */
  @keyframes pulse {
    0% { box-shadow: 0 0 0 0 rgba(56, 189, 248, 0.4); }
    70% { box-shadow: 0 0 0 10px rgba(56, 189, 248, 0); }
    100% { box-shadow: 0 0 0 0 rgba(56, 189, 248, 0); }
  }
  .status-pulse { animation: pulse 2s infinite; }
"

# 3. Enterprise Aviation Theme
enterprise_theme <- bs_theme(
  version = 5,
  bg = "#080F1A",         # Deepest void navy
  fg = "#F8FAFC",         # Crisp white
  primary = "#38BDF8",    # Cyan active
  secondary = "#111827",  # Panel background
  success = "#10B981",    # Cleared / Green
  warning = "#F5A623",    # Alert Gold
  danger = "#EF4444",     # Critical Red
  base_font = font_google("Inter"),
  heading_font = font_google("Montserrat", wght = c(400, 600, 700))
)

# 4. User Interface (UI)
ui <- page_navbar(
  theme = enterprise_theme,
  tags$head(tags$style(HTML(custom_css))), 
  title = span(bsicons::bs_icon("radar"), " AeroPredict | Flight Operations Center"),
  fillable = TRUE,
  
  nav_panel("Live Flight Manifest",
            layout_sidebar(
              sidebar = sidebar(
                width = 400,
                title = "Manifest Configuration",
                bg = "#111827", 
                
                accordion(
                  open = c("Flight Details", "Digital & Booking", "Cabin Experience"),
                  multiple = TRUE,
                  
                  accordion_panel("Flight Details", icon = bsicons::bs_icon("ticket-detailed"),
                                  layout_columns(
                                    col_widths = c(6, 6),
                                    selectInput("travel_type", "Travel Type", choices = c("Business travel", "Personal Travel")),
                                    selectInput("class", "Cabin", choices = c("Business", "Eco", "Eco Plus"))
                                  ),
                                  sliderInput("age", "Passenger Age", min = 10, max = 85, value = 42, step = 1)
                  ),
                  
                  accordion_panel("Digital & Booking", icon = bsicons::bs_icon("laptop"),
                                  sliderInput("online_booking", "Booking Ease", min = 0, max = 5, value = 4, step = 1),
                                  sliderInput("online_boarding", "Online Boarding", min = 0, max = 5, value = 4, step = 1),
                                  sliderInput("wifi", "Inflight Wi-Fi", min = 0, max = 5, value = 3, step = 1)
                  ),
                  
                  accordion_panel("Cabin Experience", icon = bsicons::bs_icon("cup-hot"),
                                  sliderInput("seat", "Seat Comfort", min = 0, max = 5, value = 4, step = 1),
                                  sliderInput("food", "Food & Beverage", min = 0, max = 5, value = 3, step = 1),
                                  sliderInput("entertainment", "Entertainment", min = 0, max = 5, value = 4, step = 1),
                                  sliderInput("cleanliness", "Cleanliness", min = 0, max = 5, value = 4, step = 1)
                  ),
                  
                  accordion_panel("Crew & Handling", icon = bsicons::bs_icon("person-badge"),
                                  sliderInput("checkin", "Check-in Service", min = 0, max = 5, value = 4, step = 1),
                                  sliderInput("baggage", "Baggage Handling", min = 0, max = 5, value = 3, step = 1),
                                  sliderInput("onboard_service", "On-board Service", min = 0, max = 5, value = 4, step = 1),
                                  sliderInput("inflight_service", "Inflight Service", min = 0, max = 5, value = 4, step = 1)
                  )
                )
              ),
              
              # Main Command Dashboard
              layout_columns(
                col_widths = c(12, 12),
                row_heights = c("auto", "1fr", "1fr"),
                
                # Row 1: KPI Top Bar & Dynamic Narrative
                layout_columns(
                  col_widths = c(3, 3, 6),
                  value_box(
                    title = "SYSTEM STATUS",
                    value = textOutput("pred_class"),
                    showcase = bsicons::bs_icon("shield-check"),
                    theme_color = "primary",
                    class = "status-pulse"
                  ),
                  value_box(
                    title = "PROBABILITY INDEX",
                    value = textOutput("pred_prob_text"),
                    showcase = bsicons::bs_icon("graph-up-arrow"),
                    theme_color = "success"
                  ),
                  card(
                    style = "background-color: #111827; border-left: 4px solid #38BDF8 !important;",
                    card_body(
                      class = "d-flex align-items-center",
                      uiOutput("rich_narrative")
                    )
                  )
                ),
                
                # Row 2: Altimeter & Radar
                layout_columns(
                  col_widths = c(5, 7),
                  card(
                    style = "background-color: #111827;",
                    card_header("Predictive Altimeter", class = "border-bottom-0 text-info fw-bold text-uppercase"),
                    card_body(plotlyOutput("prob_gauge", height = "100%"))
                  ),
                  card(
                    style = "background-color: #111827;",
                    card_header("Experience Footprint (Radar)", class = "border-bottom-0 text-info fw-bold text-uppercase"),
                    card_body(plotlyOutput("radar_chart", height = "100%"))
                  )
                ),
                
                # Row 3: Service Delta Waterfall/Bar
                card(
                  style = "background-color: #111827;",
                  card_header("Service Delta Analysis (Deviation from Baseline)", class = "border-bottom-0 text-info fw-bold text-uppercase"),
                  card_body(plotlyOutput("delta_chart", height = "200px"))
                )
              )
            )
  )
)

# 5. Server Logic Engine
server <- function(input, output, session) {
  
  # Reactive Base Data
  prediction_data <- reactive({
    new_data <- data.frame(
      Gender = factor("Female", levels = c("Female", "Male")),
      Customer.Type = factor("Loyal Customer", levels = c("Loyal Customer", "disloyal Customer")),
      Age = input$age,
      Type.of.Travel = factor(input$travel_type, levels = c("Business travel", "Personal Travel")),
      Class = factor(input$class, levels = c("Business", "Eco", "Eco Plus")),
      Flight.Distance = 1500,
      Inflight.wifi.service = input$wifi,
      Departure.Arrival.time.convenient = 3,
      Ease.of.Online.booking = input$online_booking,
      Gate.location = 3,
      Food.and.drink = input$food,
      Online.boarding = input$online_boarding,
      Seat.comfort = input$seat,
      Inflight.entertainment = input$entertainment,
      On.board.service = input$onboard_service,
      Leg.room.service = 3,
      Baggage.handling = input$baggage,
      Checkin.service = input$checkin,
      Inflight.service = input$inflight_service,
      Cleanliness = input$cleanliness,
      Departure.Delay.in.Minutes = 0,
      Arrival.Delay.in.Minutes = 0
    )
    
    prob <- predict(model, newdata = new_data, type = "response")
    class <- ifelse(prob > 0.5, "CLEARED", "AT RISK")
    list(probability = prob, classification = class)
  })
  
  # Text Outputs
  output$pred_class <- renderText({ prediction_data()$classification })
  output$pred_prob_text <- renderText({ paste0(round(prediction_data()$probability * 100, 1), "%") })
  
  # Dynamic Narrative Generator
  output$rich_narrative <- renderUI({
    prob <- prediction_data()$probability
    
    # Identify pain points and highlights
    scores <- c(
      "Wi-Fi" = input$wifi, "Boarding" = input$online_boarding, 
      "Seat" = input$seat, "Food" = input$food, 
      "Service" = input$inflight_service, "Baggage" = input$baggage
    )
    lowest <- names(scores)[which.min(scores)]
    highest <- names(scores)[which.max(scores)]
    
    status_text <- ifelse(prob > 0.5, 
                          "<span style='color:#10B981; font-weight:bold;'>maintaining high loyalty indicators</span>", 
                          "<span style='color:#EF4444; font-weight:bold;'>exhibiting critical churn risk</span>")
    
    HTML(paste0(
      "<div style='font-size: 1.1rem; line-height: 1.6;'>",
      "<strong>AI Passenger Briefing:</strong> This ", input$age, "-year-old passenger traveling in <strong>", input$class, 
      "</strong> for ", tolower(input$travel_type), " is currently ", status_text, ". ",
      "Predictive models indicate satisfaction is heavily anchored by their experience with <strong>", highest, 
      "</strong>, while current operational friction is originating from <strong>", lowest, "</strong>.",
      "</div>"
    ))
  })
  
  # Viz 1: The Predictive Altimeter (Gauge) - Fixed text overlap
  output$prob_gauge <- renderPlotly({
    prob_val <- prediction_data()$probability * 100
    gauge_color <- ifelse(prob_val > 50, "#10B981", "#EF4444")
    
    plot_ly(
      domain = list(x = c(0, 1), y = c(0, 1)),
      value = prob_val,
      # Removed the internal title that was overlapping the arc ticks
      type = "indicator",
      mode = "gauge+number",
      number = list(suffix = "%", font = list(color = "#F8FAFC", size = 36)),
      gauge = list(
        axis = list(range = list(NULL, 100), tickwidth = 1, tickcolor = "#334155", font = list(color = "#64748B")),
        bar = list(color = gauge_color),
        bgcolor = "rgba(0,0,0,0)", borderwidth = 1, bordercolor = "#1E293B",
        steps = list(list(range = c(0, 50), color = "#080F1A"), list(range = c(50, 100), color = "#0F172A")),
        threshold = list(line = list(color = "#F5A623", width = 3), thickness = 0.75, value = 50)
      )
    ) %>% 
      layout(
        paper_bgcolor = "transparent", 
        plot_bgcolor = "transparent", 
        margin = list(t = 20, b = 10, l = 20, r = 20)
      ) %>%
      config(displayModeBar = FALSE)
  })
  
  # Viz 2: Experience Footprint (Radar Chart) - Fixed label clipping
  output$radar_chart <- renderPlotly({
    r_values <- c(
      mean(c(input$wifi, input$online_booking, input$online_boarding)),
      mean(c(input$seat, input$food, input$entertainment, input$cleanliness)),
      mean(c(input$checkin, input$baggage, input$onboard_service, input$inflight_service))
    )
    r_values <- c(r_values, r_values[1]) 
    theta_values <- c('Digital & Booking', 'Cabin Comfort', 'Crew Service', 'Digital & Booking')
    
    plot_ly(
      type = 'scatterpolar', r = r_values, theta = theta_values, fill = 'toself',
      fillcolor = 'rgba(56, 189, 248, 0.2)', line = list(color = '#38BDF8', width = 2),
      marker = list(color = '#38BDF8', size = 6)
    ) %>%
      layout(
        polar = list(
          # Slightly increased range to prevent shape from hitting labels
          radialaxis = list(visible = TRUE, range = c(0, 5.5), color = "#64748B", gridcolor = "#1E293B"),
          angularaxis = list(tickfont = list(color = "#94A3B8", size = 12), gridcolor = "#1E293B"),
          bgcolor = "transparent"
        ),
        paper_bgcolor = "transparent", 
        plot_bgcolor = "transparent", 
        # Expanded L and R margins to prevent text clipping
        margin = list(t = 30, b = 30, l = 60, r = 60)
      ) %>% config(displayModeBar = FALSE)
  })
  
  # Viz 3: Service Delta (Diverging Bar Chart) - Fixed Y-axis cutoff
  output$delta_chart <- renderPlotly({
    services <- c("Wi-Fi", "Boarding", "Seat", "Entertainment", "Inflight Svc", "Baggage")
    scores <- c(input$wifi, input$online_boarding, input$seat, input$entertainment, input$inflight_service, input$baggage)
    delta <- scores - 3 
    
    colors <- ifelse(delta > 0, "#10B981", ifelse(delta < 0, "#EF4444", "#64748B"))
    
    plot_ly(
      x = services, y = delta, type = 'bar', marker = list(color = colors),
      text = paste0(ifelse(delta>0, "+", ""), delta), textposition = 'outside', textfont = list(color = "#F8FAFC")
    ) %>%
      layout(
        # Added automargin to ensure titles are never cut off
        yaxis = list(title = "Deviation from Baseline (3.0)", range = c(-3.5, 3.5), gridcolor = "#1E293B", zerolinecolor = "#94A3B8", automargin = TRUE),
        xaxis = list(title = "", tickfont = list(color = "#94A3B8"), automargin = TRUE),
        paper_bgcolor = "transparent", 
        plot_bgcolor = "transparent", 
        margin = list(t = 10, b = 20, l = 40, r = 20)
      ) %>% config(displayModeBar = FALSE)
  })
}

# 6. Execute 
shinyApp(ui = ui, server = server)