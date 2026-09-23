# ============================================================================
# AeroPredict | Flight Operations Center (v2.2) — complete, corrected file
# ----------------------------------------------------------------------------
# Assumes "airplane_log_model.rds" is a binomial model whose predict() gives
# P(satisfied). Exact factor LEVELS below must match your training data.
# Requires: shiny, bslib (>= 0.5.1), bsicons, plotly (>= 4.10), htmltools
# ============================================================================

library(shiny)
library(bslib)
library(bsicons)
library(plotly)
library(htmltools)

# -- 1. Model artifact --------------------------------------------------------
model_path <- "airplane_log_model.rds"
if (!file.exists(model_path)) stop("Model artifact not found: ", model_path)
model <- readRDS(model_path)

# -- 2. Palette + defaults ----------------------------------------------------
COL <- list(ok = "#10B981", bad = "#EF4444", pri = "#38BDF8",
            mut = "#64748B", grid = "#1E293B", txt = "#F8FAFC", sub = "#94A3B8")

DEFAULTS <- list(
  gender = "Female", customer_type = "Loyal Customer", age = 42,
  travel_type = "Business travel", cabin = "Business",
  distance = 1500, delay = 0,
  online_booking = 4, online_boarding = 4, wifi = 3,
  seat = 4, food = 3, entertainment = 4, cleanliness = 4,
  checkin = 4, baggage = 3, onboard_service = 4, inflight_service = 4
)

# -- 3. Complete stylesheet ---------------------------------------------------
custom_css <- '
  :root { color-scheme: dark; }
  body {
    background:
      radial-gradient(1100px 520px at 85% -10%, rgba(56,189,248,.07), transparent 60%),
      radial-gradient(900px 480px at -10% 110%, rgba(16,185,129,.05), transparent 60%),
      #080F1A;
  }
  ::selection { background: rgba(56,189,248,.35); }
  ::-webkit-scrollbar { width: 10px; height: 10px; }
  ::-webkit-scrollbar-track { background: #0B1220; }
  ::-webkit-scrollbar-thumb { background: #1E293B; border-radius: 8px; border: 2px solid #0B1220; }
  ::-webkit-scrollbar-thumb:hover { background: #334155; }

  .card, .value-box {
    background-color: #111827;
    border: 1px solid rgba(56,189,248,.10);
    transition: transform .35s cubic-bezier(.2,.8,.25,1), box-shadow .35s ease, border-color .35s ease;
  }
  .card:hover, .value-box:hover {
    transform: translateY(-3px);
    box-shadow: 0 10px 26px rgba(56,189,248,.12);
    border-color: rgba(56,189,248,.38);
  }
  .narrative-card { border-left: 3px solid #38BDF8 !important; }

  .card-header {
    background: transparent; border-bottom: 1px solid rgba(56,189,248,.12);
    color: #38BDF8; font-weight: 600; text-transform: uppercase; letter-spacing: .08em;
  }
  .navbar { border-bottom: 1px solid rgba(56,189,248,.15); }

  @keyframes pulse-cyan {
    0%   { box-shadow: 0 0 0 0 rgba(56,189,248,.40); }
    70%  { box-shadow: 0 0 0 10px rgba(56,189,248,0); }
    100% { box-shadow: 0 0 0 0 rgba(56,189,248,0); }
  }
  @keyframes pulse-red {
    0%   { box-shadow: 0 0 0 0 rgba(239,68,68,.45); }
    70%  { box-shadow: 0 0 0 10px rgba(239,68,68,0); }
    100% { box-shadow: 0 0 0 0 rgba(239,68,68,0); }
  }
  .status-ok   { animation: pulse-cyan 2.4s infinite; }
  .status-risk { animation: pulse-red  1.5s infinite; }

  @keyframes rise { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: none; } }
  main .layout-columns > *        { animation: rise .5s ease backwards; }
  main .layout-columns > *:nth-child(1) { animation-delay: .05s; }
  main .layout-columns > *:nth-child(2) { animation-delay: .12s; }
  main .layout-columns > *:nth-child(3) { animation-delay: .19s; }

  label.control-label { color: #94A3B8; font-size: .85rem; text-transform: uppercase; letter-spacing: .05em; }
  hr { border-color: rgba(56,189,248,.15); opacity: 1; }

  .accordion-button { background: #0B1220; color: #F8FAFC; }
  .accordion-button:not(.collapsed) { background: #0F1B2D; color: #38BDF8; }
  .accordion-body { background: #0B1220; }

  .irs--shiny .irs-line { background: #1E293B; }
  .irs--shiny .irs-bar  { background: #38BDF8; border-color: #38BDF8; }
  .irs--shiny .irs-handle { background: #0B1220; border: 2px solid #38BDF8; box-shadow: 0 0 8px rgba(56,189,248,.5); }
  .irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single { background: #38BDF8; color: #080F1A; }

  .selectize-control.single .selectize-input {
    background: #0B1220; border-color: #334155; color: #F8FAFC;
  }

  @media (prefers-reduced-motion: reduce) {
    * { animation: none !important; transition: none !important; }
  }
'

# -- 4. Theme -----------------------------------------------------------------
enterprise_theme <- bs_theme(
  version = 5,
  bg = "#080F1A", fg = "#F8FAFC",
  primary = "#38BDF8", secondary = "#111827",
  success = "#10B981", warning = "#F5A623", danger = "#EF4444",
  base_font = font_google("Inter"),
  heading_font = font_google("Montserrat", wght = c(400, 600, 700))
)

# -- 5. UI --------------------------------------------------------------------
ui <- page_navbar(
  theme = enterprise_theme,
  tags$head(tags$style(HTML(custom_css))),
  title = span(bs_icon("radar"), " AeroPredict | Flight Operations Center"),
  fillable = TRUE,
  
  nav_panel("Live Flight Manifest",
            layout_sidebar(
              fillable = TRUE,
              sidebar = sidebar(
                width = 350, open = "desktop", bg = "#111827",
                title = span(bs_icon("sliders"), " Manifest Configuration"),
                
                div(class = "d-grid gap-2",
                    actionButton("simulate", span(bs_icon("shuffle"), " Simulate Passenger"),
                                 class = "btn-outline-info w-100"),
                    actionButton("reset_manifest", span(bs_icon("arrow-counterclockwise"), " Reset Manifest"),
                                 class = "btn-outline-secondary w-100")
                ),
                hr(),
                
                accordion(
                  open = c("Flight Details", "Digital & Booking", "Cabin Experience"),
                  multiple = TRUE,
                  
                  accordion_panel("Flight Details", icon = bs_icon("ticket-detailed"),
                                  layout_columns(col_widths = c(6, 6),
                                                 selectInput("travel_type", "Travel Type",
                                                             choices = c("Business travel", "Personal Travel")),
                                                 selectInput("cabin", "Cabin",
                                                             choices = c("Business", "Eco", "Eco Plus"))),
                                  selectInput("gender", "Gender",
                                              choices = c("Female", "Male")),
                                  selectInput("customer_type", "Customer Type",
                                              choices = c("Loyal Customer" = "Loyal Customer",
                                                          "Disloyal Customer" = "disloyal Customer")),
                                  sliderInput("age", "Passenger Age", min = 10, max = 85, value = DEFAULTS$age),
                                  sliderInput("distance", "Flight Distance (km)", min = 50, max = 4000,
                                              value = DEFAULTS$distance, step = 50),
                                  sliderInput("delay", "Departure Delay (min)", min = 0, max = 300,
                                              value = DEFAULTS$delay, step = 5)
                  ),
                  accordion_panel("Digital & Booking", icon = bs_icon("laptop"),
                                  sliderInput("online_booking", "Booking Ease", 0, 5, DEFAULTS$online_booking),
                                  sliderInput("online_boarding", "Online Boarding", 0, 5, DEFAULTS$online_boarding),
                                  sliderInput("wifi", "Inflight Wi-Fi", 0, 5, DEFAULTS$wifi)
                  ),
                  accordion_panel("Cabin Experience", icon = bs_icon("cup-hot"),
                                  sliderInput("seat", "Seat Comfort", 0, 5, DEFAULTS$seat),
                                  sliderInput("food", "Food & Beverage", 0, 5, DEFAULTS$food),
                                  sliderInput("entertainment", "Entertainment", 0, 5, DEFAULTS$entertainment),
                                  sliderInput("cleanliness", "Cleanliness", 0, 5, DEFAULTS$cleanliness)
                  ),
                  accordion_panel("Crew & Handling", icon = bs_icon("person-badge"),
                                  sliderInput("checkin", "Check-in Service", 0, 5, DEFAULTS$checkin),
                                  sliderInput("baggage", "Baggage Handling", 0, 5, DEFAULTS$baggage),
                                  sliderInput("onboard_service", "On-board Service", 0, 5, DEFAULTS$onboard_service),
                                  sliderInput("inflight_service", "Inflight Service", 0, 5, DEFAULTS$inflight_service)
                  )
                )
              ),
              
              # ---- Command dashboard ----
              layout_columns(
                row_heights = c("auto", "1fr", "1fr"),
                
                # Row 1: KPIs + narrative (xs stacked / sm halves / md+ 3-3-6)
                layout_columns(
                  col_widths = c(12, 12, 12, 6, 6, 6, 3, 3, 6),
                  uiOutput("status_box"),
                  uiOutput("prob_box"),
                  card(class = "narrative-card",
                       card_body(class = "d-flex align-items-center", uiOutput("rich_narrative"))
                  )
                ),
                
                # Row 2: Altimeter + Radar (xs/sm stacked, md+ 5-7)
                layout_columns(
                  col_widths = c(12, 12, 12, 12, 5, 7),
                  card(full_screen = TRUE,
                       card_header("Predictive Altimeter"),
                       card_body(plotlyOutput("prob_gauge", height = "100%"))
                  ),
                  card(full_screen = TRUE,
                       card_header("Experience Footprint (Radar)"),
                       card_body(plotlyOutput("radar_chart", height = "100%"))
                  )
                ),
                
                # Row 3: Service deltas
                card(full_screen = TRUE,
                     card_header("Service Delta Analysis (Deviation from Baseline)"),
                     card_body(plotlyOutput("delta_chart", height = "230px"))
                )
              )
            )
  )
)

# -- 6. Plot builders (rendered once; updated via plotlyProxy) -----------------
build_gauge <- function(pct) {
  plot_ly(type = "indicator", mode = "gauge+number+delta", value = pct,
          delta = list(reference = 50, position = "bottom",
                       increasing = list(color = COL$ok), decreasing = list(color = COL$bad),
                       font = list(size = 13)),
          number = list(suffix = "%", font = list(color = COL$txt, size = 34)),
          gauge = list(
            axis = list(range = c(0, 100), tickvals = seq(0, 100, 25), ticksuffix = "%",
                        tickfont = list(size = 10, color = COL$mut),
                        tickwidth = 1, tickcolor = "#334155"),
            bar = list(color = if (pct > 50) COL$ok else COL$bad),
            bgcolor = "rgba(0,0,0,0)", borderwidth = 1, bordercolor = "#1E293B",
            steps = list(list(range = c(0, 50), color = "#080F1A"),
                         list(range = c(50, 100), color = "#0F172A")),
            threshold = list(line = list(color = "#F5A623", width = 3),
                             thickness = 0.75, value = 50)
          )) %>%
    layout(paper_bgcolor = "transparent", plot_bgcolor = "transparent",
           margin = list(t = 25, b = 20, l = 20, r = 20)) %>%
    config(displayModeBar = FALSE, responsive = TRUE)
}

build_radar <- function(vals) {
  theta <- c("Digital & Booking", "Cabin Comfort", "Crew Service")
  theta <- c(theta, theta[1])
  plot_ly(type = "scatterpolar") %>%
    add_trace(r = c(vals, vals[1]), theta = theta, name = "Passenger",
              fill = "toself", fillcolor = "rgba(56,189,248,.20)",
              line = list(color = COL$pri, width = 2),
              marker = list(color = COL$pri, size = 6)) %>%
    add_trace(r = rep(3, 4), theta = theta, name = "Baseline (3.0)", mode = "lines",
              line = list(color = COL$mut, width = 1.5, dash = "dot"),
              hoverinfo = "name") %>%
    layout(
      showlegend = TRUE,
      legend = list(orientation = "h", y = 1.12, font = list(size = 11, color = COL$sub)),
      polar = list(
        radialaxis = list(visible = TRUE, range = c(0, 5), tickvals = 1:5,
                          color = COL$mut, gridcolor = COL$grid, tickfont = list(size = 9)),
        angularaxis = list(tickfont = list(color = COL$sub, size = 11), gridcolor = COL$grid),
        bgcolor = "transparent"
      ),
      paper_bgcolor = "transparent", plot_bgcolor = "transparent",
      margin = list(t = 40, b = 20, l = 60, r = 60)
    ) %>% config(displayModeBar = FALSE, responsive = TRUE)
}

build_delta <- function(delta, colors, txt) {
  plot_ly(x = c("Wi-Fi", "Boarding", "Seat", "Entertainment", "Inflight Svc", "Baggage"),
          y = delta, type = "bar",
          marker = list(color = colors), bargap = 0.35,
          text = txt, textposition = "outside",
          textfont = list(color = COL$txt, size = 12)) %>%
    layout(
      yaxis = list(title = "Deviation from 3.0", range = c(-3.2, 2.7),
                   gridcolor = COL$grid, zerolinecolor = COL$sub, automargin = TRUE),
      xaxis = list(tickfont = list(color = COL$sub), tickangle = -25, automargin = TRUE),
      paper_bgcolor = "transparent", plot_bgcolor = "transparent",
      margin = list(t = 15, b = 15, l = 45, r = 15)
    ) %>% config(displayModeBar = FALSE, responsive = TRUE)
}

# -- 7. Server -----------------------------------------------------------------
server <- function(input, output, session) {
  
  # Render-once flags: initial plots are drawn with isolated() current values,
  # afterwards every update is a lightweight proxy restyle (no flicker).
  gauge_ready <- reactiveVal(FALSE)
  radar_ready <- reactiveVal(FALSE)
  delta_ready <- reactiveVal(FALSE)
  
  # ---- Core reactive: build row + predict (with fallbacks) ----
  prediction_data <- reactive({
    new_data <- data.frame(
      Gender = factor(input$gender, levels = c("Female", "Male")),
      Customer.Type = factor(input$customer_type, levels = c("Loyal Customer", "disloyal Customer")),
      Age = input$age,
      Type.of.Travel = factor(input$travel_type, levels = c("Business travel", "Personal Travel")),
      Class = factor(input$cabin, levels = c("Business", "Eco", "Eco Plus")),
      Flight.Distance = input$distance,
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
      Departure.Delay.in.Minutes = input$delay,
      Arrival.Delay.in.Minutes = input$delay   # mirrored to departure
    )
    
    p <- tryCatch(
      as.numeric(predict(model, newdata = new_data, type = "response"))[1],
      error = function(e)
        tryCatch(plogis(as.numeric(predict(model, newdata = new_data))[1]),
                 error = function(e2) NA_real_)
    )
    p <- suppressWarnings(pmin(pmax(p, 0), 1))
    validate(need(is.finite(p),
                  "Prediction failed — verify airplane_log_model.rds matches these variable names/levels."))
    list(probability = p, classification = if (p > 0.5) "CLEARED" else "AT RISK")
  })
  
  # ---- Simulate / Reset ----
  observeEvent(input$simulate, {
    sc <- function() sample(2:5, 1, prob = c(.10, .20, .35, .35))
    prof <- list(
      gender = sample(c("Female", "Male"), 1),
      customer_type = sample(c("Loyal Customer", "disloyal Customer"), 1, prob = c(.8, .2)),
      age = sample(18:75, 1),
      travel_type = sample(c("Business travel", "Personal Travel"), 1),
      cabin = sample(c("Business", "Eco", "Eco Plus"), 1, prob = c(.45, .35, .20)),
      distance = sample(c(250, 500, 900, 1400, 2000, 2800, 3600), 1),
      delay = sample(c(0, 0, 0, 5, 15, 45, 90, 150), 1),
      online_booking = sc(), online_boarding = sc(), wifi = sc(),
      seat = sc(), food = sc(), entertainment = sc(), cleanliness = sc(),
      checkin = sc(), baggage = sc(), onboard_service = sc(), inflight_service = sc()
    )
    for (id in names(prof)) {
      if (id %in% c("gender", "customer_type", "travel_type", "cabin")) {
        updateSelectInput(session, id, selected = prof[[id]])
      } else {
        updateSliderInput(session, id, value = prof[[id]])
      }
    }
    showNotification("Random passenger manifest loaded.", type = "message", duration = 3)
  })
  
  observeEvent(input$reset_manifest, {
    for (id in names(DEFAULTS)) {
      if (id %in% c("gender", "customer_type", "travel_type", "cabin")) {
        updateSelectInput(session, id, selected = DEFAULTS[[id]])
      } else {
        updateSliderInput(session, id, value = DEFAULTS[[id]])
      }
    }
    showNotification("Manifest restored to baseline.", type = "default", duration = 3)
  })
  
  # ---- KPI boxes (fully dynamic color / icon / pulse) ----
  output$status_box <- renderUI({
    pd <- prediction_data()
    risk <- pd$probability <= 0.5
    value_box(
      title = "SYSTEM STATUS",
      value = span(style = paste0("color:", if (risk) COL$bad else COL$ok,
                                  "; font-weight:700;"), pd$classification),
      showcase = bs_icon(if (risk) "shield-exclamation" else "shield-check"),
      theme_color = if (risk) "danger" else "success",
      class = if (risk) "status-risk" else "status-ok"
    )
  })
  
  output$prob_box <- renderUI({
    pd <- prediction_data()
    risk <- pd$probability <= 0.5
    value_box(
      title = "PROBABILITY INDEX",
      value = span(style = paste0("color:", if (risk) COL$bad else COL$ok,
                                  "; font-weight:700;"),
                   sprintf("%.1f%%", pd$probability * 100)),
      showcase = bs_icon("graph-up-arrow"),
      theme_color = if (risk) "danger" else "success",
      span(class = "text-secondary",
           sprintf("%+.1f pts vs 50%% clearance threshold", (pd$probability - .5) * 100))
    )
  })
  
  # ---- Narrative ----
  output$rich_narrative <- renderUI({
    pd <- prediction_data()
    scores <- c(WiFi = input$wifi, Boarding = input$online_boarding,
                Seat = input$seat, Food = input$food,
                Service = input$inflight_service, Baggage = input$baggage)
    
    haul <- as.character(cut(input$distance, c(0, 800, 2500, Inf),
                             labels = c("short-haul", "medium-haul", "long-haul")))
    status_html <- if (pd$probability > 0.5)
      "<span style='color:#10B981;font-weight:700;'>maintaining high loyalty indicators</span>" else
        "<span style='color:#EF4444;font-weight:700;'>exhibiting critical churn risk</span>"
    delay_html <- if (input$delay >= 15)
      paste0(", with a ", input$delay, "-minute departure delay compounding the friction") else ""
    
    if (length(unique(scores)) == 1) {
      anchor <- paste0("a uniformly even experience across every touchpoint (all rated ",
                       scores[1], "/5)")
      friction <- "no single dominant pain point"
    } else {
      anchor <- paste0("their experience with <strong>", names(scores)[which.max(scores)], "</strong>")
      friction <- paste0("operational friction is originating from <strong>",
                         names(scores)[which.min(scores)], "</strong>")
    }
    
    HTML(paste0(
      "<div style='font-size:1.05rem;line-height:1.6;'>",
      "<strong>AI Passenger Briefing:</strong> This ", input$age,
      "-year-old ", ifelse(input$customer_type == "Loyal Customer", "loyal ", ""), "passenger in <strong>",
      input$cabin, "</strong> on a ", haul, " trip is currently ", status_html, delay_html, ". ",
      "Satisfaction is anchored by ", anchor, ", while ", friction, ".</div>"
    ))
  })
  
  # ---- Initial chart renders (isolate -> drawn exactly once) ----
  output$prob_gauge <- renderPlotly({
    p <- build_gauge(isolate(prediction_data()$probability) * 100)
    gauge_ready(TRUE); p
  })
  output$radar_chart <- renderPlotly({
    vals <- isolate({
      c(mean(c(input$wifi, input$online_booking, input$online_boarding)),
        mean(c(input$seat, input$food, input$entertainment, input$cleanliness)),
        mean(c(input$checkin, input$baggage, input$onboard_service, input$inflight_service)))
    })
    p <- build_radar(vals)
    radar_ready(TRUE); p
  })
  output$delta_chart <- renderPlotly({
    d <- isolate(c(input$wifi, input$online_boarding, input$seat,
                   input$entertainment, input$inflight_service, input$baggage) - 3)
    p <- build_delta(d,
                     ifelse(d > 0, COL$ok, ifelse(d < 0, COL$bad, COL$mut)),
                     paste0(ifelse(d > 0, "+", ""), d))
    delta_ready(TRUE); p
  })
  
  # ---- Smooth in-place updates via plotlyProxy (no full re-render) ----
  observeEvent(prediction_data(), {
    if (!gauge_ready() || !radar_ready() || !delta_ready()) return(invisible(NULL))
    pd <- prediction_data()
    pct <- pd$probability * 100
    
    # Gauge: value + bar color (nested attr form)
    plotlyProxy("prob_gauge", session) %>%
      plotlyProxyInvoke("restyle",
                        list(value = pct,
                             gauge = list(bar = list(color = if (pct > 50) COL$ok else COL$bad))))
    
    # Radar: trace 0 only (baseline trace untouched)
    r_vals <- c(mean(c(input$wifi, input$online_booking, input$online_boarding)),
                mean(c(input$seat, input$food, input$entertainment, input$cleanliness)),
                mean(c(input$checkin, input$baggage, input$onboard_service, input$inflight_service)))
    plotlyProxy("radar_chart", session) %>%
      plotlyProxyInvoke("restyle", list(r = list(c(r_vals, r_vals[1]))), 0)
    
    # Delta bars
    d <- c(input$wifi, input$online_boarding, input$seat,
           input$entertainment, input$inflight_service, input$baggage) - 3
    plotlyProxy("delta_chart", session) %>%
      plotlyProxyInvoke("restyle",
                        list(y = list(d),
                             marker = list(color = ifelse(d > 0, COL$ok,
                                                          ifelse(d < 0, COL$bad, COL$mut))),
                             text = list(paste0(ifelse(d > 0, "+", ""), d))))
  })
}

# -- 8. Run --------------------------------------------------------------------
shinyApp(ui = ui, server = server)
