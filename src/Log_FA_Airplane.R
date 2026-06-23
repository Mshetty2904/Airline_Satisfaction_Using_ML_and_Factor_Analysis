  library(MASS)
  library(psych)
  library(corrplot)
  library(caret)
  library(pROC)
  library(ggplot2)
  
  # Load datasets
  train <- read.csv("E:/Downloads/airplane_train/airplane_train.csv")
  test  <- read.csv("E:/Downloads/airplane_test/airplane_test.csv")
  
  # Remove unnecessary columns
  train <- train[, !names(train) %in% c("X","id")]
  test  <- test[, !names(test) %in% c("X","id")]
  
  # Convert categorical variables
  cat_cols <- c("Gender", "Customer.Type", "Type.of.Travel",
                "Class", "satisfaction")
  
  for(col in cat_cols){
    train[[col]] <- as.factor(train[[col]])
    test[[col]]  <- as.factor(test[[col]])
  }
  
  # Ensure factor levels match
  for(col in cat_cols){
    test[[col]] <- factor(test[[col]],
                          levels = levels(train[[col]]))
  }
  
  # Remove missing values
  train <- na.omit(train)
  test <- na.omit(test)
  
  ggplot(train,
         aes(x = satisfaction,
             fill = satisfaction)) +
    geom_bar() +
    labs(
      title = "Distribution of Passenger Satisfaction",
      x = "Satisfaction",
      y = "Count"
    ) +
    theme_minimal()
  
  # Logistic Regression Model
  log_model <- glm(satisfaction ~ ., data=train, family=binomial)
  
  summary(log_model)
  
  # Predictions
  prob <- predict(log_model, test, type="response")
  
  pred <- ifelse(prob > 0.5,
                 "satisfied",
                 "neutral or dissatisfied")
  
  log_pred <- factor(pred,
                     levels = levels(test$satisfaction))
  prob_df <- data.frame(
    Probability = prob,
    Actual = test$satisfaction
  )
  
  ggplot(prob_df,
         aes(x = Probability,
             fill = Actual)) +
    geom_histogram(
      bins = 30,
      alpha = 0.7,
      position = "identity"
    ) +
    labs(
      title = "Predicted Probability Distribution",
      x = "Predicted Probability of Satisfaction",
      y = "Frequency"
    ) +
    theme_minimal()
  
  # Confusion Matrix
  cm <- confusionMatrix(log_pred, test$satisfaction)
  
  cm_table <- cm$table
  
  cm_df <- as.data.frame(cm_table)
  
  ggplot(cm_df,
         aes(Prediction,
             Reference,
             fill = Freq)) +
    geom_tile() +
    geom_text(aes(label = Freq),
              size = 5) +
    labs(
      title = "Confusion Matrix",
      x = "Predicted Class",
      y = "Actual Class"
    ) +
    theme_minimal()
  

  # ROC Curve
  roc_obj <- roc(test$satisfaction, prob)
  plot(
    roc_obj,
    col = "blue",
    lwd = 3,
    legacy.axes = TRUE,
    main = "ROC Curve - Logistic Regression",
    xlab = "False Positive Rate",
    ylab = "True Positive Rate"
  )
  
  abline(a = 0, b = 1,
         col = "red",
         lty = 2)
  
  legend(
    "bottomright",
    legend = paste("AUC =", round(auc(roc_obj),4)),
    bty = "n"
  ) 
  auc(roc_obj)
  
  # Select numeric variables from training data
  num_data <- train[, sapply(train, is.numeric)]
  

  fa_vars <- train[, c(
    "Inflight.wifi.service",
    "Departure.Arrival.time.convenient",
    "Ease.of.Online.booking",
    "Gate.location",
    "Food.and.drink",
    "Online.boarding",
    "Seat.comfort",
    "Inflight.entertainment",
    "On.board.service",
    "Baggage.handling",
    "Inflight.service",
    "Cleanliness"
  )]
  
  fa_scaled <- scale(fa_vars)
  
  KMO(fa_scaled)
  
  # Bartlett Test
  cor_fa <- cor(fa_scaled)
  
  cortest.bartlett(
    cor_fa,
    n = nrow(fa_scaled)
  )
  
  fa.parallel(
    fa_scaled,
    fa = "fa",
    main = "Parallel Analysis Scree Plot"
  )  
  fa_model_final <- fa(
    fa_scaled,
    nfactors = 4,
    rotate = "oblimin"
  )
  
  print(fa_model_final$loadings, cutoff = 0.4)
  
  fa.diagram(
    fa_model_final,
    main = "Factor Structure of Airline Service Quality",
    cex = 0.9,
    rsize = 1
  )
  ggplot(train,
         aes(x = satisfaction,
             y = Online.boarding,
             fill = satisfaction)) +
    geom_boxplot() +
    labs(
      title = "Online Boarding vs Satisfaction",
      x = "Satisfaction",
      y = "Online Boarding Rating"
    ) +
    theme_minimal()

  