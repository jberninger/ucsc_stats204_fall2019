library(readr)
library(dplyr)
library(ggplot2)
library(janitor)
library(useful)
library(magrittr)
library(dygraphs)
library(xgboost)
library(tidyverse)
library(lubridate)
library(ggplot2)
library(inspectdf)
library(caret)
library(ranger)
library(useful)
library(magrittr)
library(dygraphs)
library(xgboost)
library(DiagrammeR)


setwd("~/Desktop/Stat 204/nyc_project")
dat <- read_csv("manhattan_project.csv")

data <- dat %>% mutate(Class2 = ifelse(grepl("apartment|loft|condo|family", tolower(Class)), "apartment/home", 
                                       ifelse(grepl("office|retail|hotel|theatre", tolower(Class)), "business",
                                              ifelse(grepl("utility|government|transport|health|asylum|education", tolower(Class)),   "utility","misc")))) %>%
  mutate(Built2 = ifelse(grepl("18th", Built), "18th Century",
                         ifelse(grepl("Unknown", Built), "Unknown", "20th Century"))) %>%
  mutate(LandUse2 = ifelse(grepl("family", tolower(LandUse)), "residential", 
                           ifelse(grepl("office|industrial|mixed", tolower(LandUse)), "mixed",
                                  ifelse(grepl("public", tolower(LandUse)), "public", "industrial")))) %>%
  mutate(Council = as.character(Council),
         PolicePrct = as.character(PolicePrct),
         logTotalValue = log(TotalValue)) %>%
  dplyr::select(-c("ID", "Borough", "ZoneDist2", "ZoneDist3", "ZoneDist4", "Easements",
                   "GarageArea", "StrgeArea", "FactryArea", "OtherArea", "LotFront", "LotDepth", "BldgFront", "BldgDepth",
                   "Extension", "Proximity", "BasementType",
                   "BuiltFAR", "ResidFAR", "CommFAR", "FacilFAR", "High",
                   "Built", "Class", "TotalValue", "LandUse"))

library(ggcorrplot)
man_sub = subset(data, select = c(LotArea, BldgArea, ComArea, ResArea, OfficeArea, RetailArea, NumFloors, UnitsRes, NumBldgs, UnitsTotal))

man_sub2 = dplyr::select(data, c(LotArea, BldgArea, ComArea, ResArea, OfficeArea, RetailArea, NumFloors, UnitsRes,
                                 NumBldgs, UnitsTotal))
ggcorrplot(round(cor(man_sub2),1), lab = TRUE, type = "lower", hc.order = TRUE)
manhat_pc2 = prcomp(man_sub)
manhat_pc2
summary(manhat_pc2)
manhat2.pc = predict(manhat_pc2)

data2 <- data %>% dplyr::select(-c(ResArea, RetailArea, NumFloors, UnitsRes, NumBldgs, UnitsTotal)) #%>%

library(glmnet)
library(glmnetUtils)

data2 <- data2 %>% na.omit() %>%
  mutate_if(sapply(data2, is.character), as.factor)

set.seed(112358)
smp_size <- floor(0.75 * nrow(data2))
train_ind <- sample(seq_len(nrow(data2)), size = smp_size)
train <- data2[train_ind, ] # 30K rows
test <- data2[-train_ind, ] 


traintest=rbind(train,test)
X = sparse.model.matrix(as.formula(paste("logTotalValue ~", 
                                         paste(colnames(train[,-ncol(train)]), sep = "", collapse=" +"))), 
                        data = traintest)
X = data.matrix(traintest)
lambda_seq <- 10^seq(2, -2, by = -.1)
ncol(train)-1
ridge1 <- glmnet(X[1:nrow(train),1:(ncol(train)-1)], X[1:nrow(train),ncol(train)], alpha = 0, lambda = lambda_seq)
plot(ridge1, label = TRUE, xvar = "dev")

lasso1 <- glmnet(X[1:nrow(train),1:(ncol(train)-1)], X[1:nrow(train),ncol(train)], alpha = 1, lambda = lambda_seq)
plot(lasso1, label = TRUE, main = "Lasso Regression Coefs")

ridge.cv <- cv.glmnet(X[1:nrow(train),1:(ncol(train)-1)], X[1:nrow(train),ncol(train)], alpha = 0)
ridge.cv$lambda.min
lasso.cv = cv.glmnet(X[1:nrow(train),1:(ncol(train)-1)], X[1:nrow(train),ncol(train)], alpha = 1)
lasso.cv$lambda.min

lasso.cv.lambda.1se <- glmnet(X[1:nrow(train),1:(ncol(train)-1)], X[1:nrow(train),ncol(train)], alpha = 1, lambda = lasso.cv$lambda.1se)
#plot(lasso2, label = TRUE, main = "Lasso Regression Coefs")
lasso.cv.lambda.1se.pred = predict(lasso.cv.lambda.1se, newx=X[nrow(train):nrow(X),1:(ncol(train)-1)], type="response")
lasso.cv.lambda.1se.rss <- sum((lasso.cv.lambda.1se.pred - X[nrow(train):nrow(X),ncol(train)]) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
lasso.cv.lambda.1se.r.squared <- 1 - lasso.cv.lambda.1se.rss/tss
lasso.cv.lambda.1se.r.squared


lasso.cv.lambda.min <- glmnet(X[1:nrow(train),1:(ncol(train)-1)], X[1:nrow(train),ncol(train)], alpha = 0, lambda = lasso.cv$lambda.min)
lasso.cv.lambda.min.pred = predict(lasso.cv.lambda.min, newx=X[nrow(train):nrow(X),1:(ncol(train)-1)], type="response")
lasso.cv.lambda.min.rss <- sum((lasso.cv.lambda.min.pred - X[nrow(train):nrow(X),ncol(train)]) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
lasso.cv.lambda.min.r.squared <- 1 - lasso.cv.lambda.min.rss/tss
lasso.cv.lambda.min.r.squared


lasso.lambda.mean = 0.5*(lasso.cv$lambda.min + lasso.cv$lambda.1se)

lasso.cv.lambda.mean <- glmnet(X[1:nrow(train),1:(ncol(train)-1)], X[1:nrow(train),ncol(train)], alpha = 0, lambda = lasso.lambda.mean)
#plot(lasso2, label = TRUE, main = "Lasso Regression Coefs")
lasso.cv.lambda.mean.pred = predict(lasso.cv.lambda.mean, newx=X[nrow(train):nrow(X),1:(ncol(train)-1)], type="response")
lasso.cv.lambda.mean.rss <- sum((lasso.cv.lambda.mean.pred - X[nrow(train):nrow(X),ncol(train)]) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
lasso.cv.lambda.mean.r.squared <- 1 - lasso.cv.lambda.mean.rss/tss
lasso.cv.lambda.mean.r.squared

lasso1 <- glmnet(X[1:nrow(train),1:ncol(train)-1], X[1:nrow(train),ncol(train)], alpha = 1, lambda = lambda_seq)
plot(lasso1, label = TRUE)

ridge.cv.lambda.1se <- glmnet(X[1:nrow(train),1:ncol(train)-1], X[1:nrow(train),ncol(train)], alpha = 0, lambda = ridge.cv$lambda.1se)
#plot(lasso2, label = TRUE, main = "Lasso Regression Coefs")
ridge.cv.lambda.1se.pred = predict(ridge.cv.lambda.1se, newx=X[nrow(train):nrow(X),1:ncol(train)-1], type="response")
ridge.cv.lambda.1se.rss <- sum((ridge.cv.lambda.1se.pred - X[nrow(train):nrow(X),ncol(train)]) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
ridge.cv.lambda.1se.r.squared <- 1 - ridge.cv.lambda.1se.rss/tss
ridge.cv.lambda.1se.r.squared



ridge.cv.lambda.min <- glmnet(X[1:nrow(train),1:ncol(train)-1], X[1:nrow(train),ncol(train)], alpha = 0, lambda = ridge.cv$lambda.min)
#plot(lasso2, label = TRUE, main = "Lasso Regression Coefs")
ridge.cv.lambda.min.pred = predict(ridge.cv.lambda.min, newx=X[nrow(train):nrow(X),1:ncol(train)-1], type="response")
ridge.cv.lambda.min.rss <- sum((ridge.cv.lambda.min.pred - X[nrow(train):nrow(X),ncol(train)]) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
ridge.cv.lambda.min.r.squared <- 1 - ridge.cv.lambda.min.rss/tss
ridge.cv.lambda.min.r.squared

ridge.lambda.mean = 0.5*(ridge.cv$lambda.min + ridge.cv$lambda.1se)

ridge.cv.lambda.mean <- glmnet(X[1:nrow(train),1:ncol(train)-1], X[1:nrow(train),ncol(train)], alpha = 0, lambda = ridge.lambda.mean)
#plot(lasso2, label = TRUE, main = "Lasso Regression Coefs")
ridge.cv.lambda.mean.pred = predict(ridge.cv.lambda.mean, newx=X[nrow(train):nrow(X),1:ncol(train)-1], type="response")
ridge.cv.lambda.mean.rss <- sum((ridge.cv.lambda.mean.pred - X[nrow(train):nrow(X),ncol(train)]) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
ridge.cv.lambda.mean.r.squared <- 1 - ridge.cv.lambda.mean.rss/tss
ridge.cv.lambda.mean.r.squared

plot(lasso.cv)
lasso.cv.pred = predict(lasso.cv, s='lambda.min', newx=X[nrow(train):nrow(X),1:ncol(train)-1], type="response")

coef(lasso.cv.lambda.1se)
lm.lasso <- lm(data = train, 
               logTotalValue ~ SchoolDistrict + Council + FireService + PolicePrct + ZoneDist1 + LotArea + BldgArea +  LotType + Built2 + LandUse2)

lm.lasso.pred <- predict(lm.lasso, newdata = test)
lm.lasso.rss <- sum((lm.lasso.pred - test$logTotalValue) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
lm.lasso.r.squared <- 1 - lm.lasso.rss/tss
lm.lasso.r.squared
extractAIC(lm.lasso)

lm.full <- lm(data = train, logTotalValue ~ .)

summary(lm.full) %>% broom::tidy() %>%
  mutate(p.fdr = p.adjust(p.value, method="fdr"),
         p.bh = p.adjust(p.value, method="hochberg"),
         p.sig = ifelse(p.value < .05, "*", ""),
         p.fdr.sig = ifelse(p.fdr < .05, "*", ""),
         p.bh.sig = ifelse(p.bh < .05, "*", "")) %>%
  dplyr::select(-c("estimate", "std.error", "statistic"))

lm.full.pred <- predict(lm.full, newdata = test)

lm.full.rss <- sum((lm.full.pred - test$logTotalValue) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
lm.full.r.squared <- 1 - lm.full.rss/tss
lm.full.r.squared
extractAIC(lm.full)


lm.bh <- lm(data = train, logTotalValue ~ . -HealthArea -OfficeArea -Landmark)

lm.bh.pred <- predict(lm.bh, newdata = test)

lm.bh.rss <- sum((lm.bh.pred - test$logTotalValue) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
lm.bh.r.squared <- 1 - lm.bh.rss/tss
lm.bh.r.squared
extractAIC(lm.full)

lm.null <- lm(data = train, logTotalValue ~ 1)

lm.null.pred <- predict(lm.null, newdata = test)

lm.null.rss <- sum((lm.null.pred - test$logTotalValue) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
lm.null.r.squared <- 1 - lm.null.rss/tss
lm.null.r.squared
extractAIC(lm.null)

histFormula <- logTotalValue ~ SchoolDistrict + Council + FireService + PolicePrct + HealthArea + ZoneDist1 + LandUse2 + OwnerType + LotArea + BldgArea + ComArea + OfficeArea + IrregularLot + LotType + Landmark + HistoricDistrict + Class2 + Built2 + LandUse2  - 1

landx_train <- build.x(histFormula, data=train, 
                       contrasts=FALSE, sparse=TRUE)
landy_train <- build.y(histFormula, data=train) #%>% 
# as.factor() %>% as.integer() - 1


landx_test <- build.x(histFormula, data=test, 
                      contrasts=FALSE, sparse=TRUE)
landy_test <- build.y(histFormula, data=test) #%>% 
#as.factor() %>% as.integer() - 1

xgTrain <- xgb.DMatrix(data=landx_train, label=landy_train)
xgTest <- xgb.DMatrix(data=landx_test, label=landy_test)
#xgVal <- xgb.DMatrix(data=landx_val, label=landy_val)

hist1 <- xgb.train(
  data=xgTrain,
  objective="reg:linear",
  nrounds=500
)

xgb.plot.multi.trees(hist1, feature_names=colnames(landx_train), fill = TRUE)

hist1 %>% 
  xgb.importance(feature_names=colnames(landx_train)) %>% 
  head(20) %>% 
  xgb.plot.importance()

xg1.pred <- predict(hist1, newdata=xgTest)

xg1.rss <- sum((xg1.pred - test$logTotalValue) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
xg1.r.squared <- 1 - xg1.rss/tss
xg1.rss
xg1.r.squared


train2 <- train %>% mutate(hood = paste(SchoolDistrict, Council, PolicePrct, sep = ":"))
test2 <- test %>% mutate(hood = paste(SchoolDistrict, Council, PolicePrct, sep = ":"))

hood.lm <- lm(data = train2, logTotalValue ~ hood)
hood.lm.pred <- predict(hood.lm, newdata = test2)
hood.lm.rss <- sum((hood.lm.pred - test$logTotalValue) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
hood.lm.r.squared <- 1 - hood.lm.rss/tss
hood.lm.r.squared

models <- c("LM - NULL", "LM - FULL", "LM - B.H.", "LM - LASSO", "LM - Hood",
            "LASSO.cv.lambda.1se", "LASSO.cv.lambda.min", "LASSO.cv.lambda.mean",
            "RIDGE.cv.lambda.1se", "RIDGE.cv.lambda.min", "RIDGE.cv.lambda.mean",
            "XGBOOST")

metric <- c(rep("AIC", 5), rep("Dev Ratio", 6), "?")

train_metric <- c(extractAIC(lm.null)[2], extractAIC(lm.full)[2], extractAIC(lm.bh)[2], 
                  extractAIC(lm.lasso)[2], extractAIC(hood.lm)[2],
                  lasso.cv.lambda.1se$dev.ratio, lasso.cv.lambda.min$dev.ratio, lasso.cv.lambda.mean$dev.ratio,
                  ridge.cv.lambda.1se$dev.ratio, ridge.cv.lambda.min$dev.ratio, ridge.cv.lambda.mean$dev.ratio,
                  0)

test_r_squared <- c(lm.null.r.squared, lm.full.r.squared, lm.bh.r.squared, lm.lasso.r.squared, hood.lm.r.squared,
                    lasso.cv.lambda.1se.r.squared, lasso.cv.lambda.min.r.squared, lasso.cv.lambda.mean.r.squared,
                    ridge.cv.lambda.1se.r.squared, ridge.cv.lambda.min.r.squared, ridge.cv.lambda.mean.r.squared,
                    xg1.r.squared)


df <- data.frame(models, metric, train_metric, test_r_squared) %>% 
  mutate(train_metric = round(train_metric, 3),
         test_r_squared = round(test_r_squared, 4))
df[12,3] = "?"
xtable(df) # for the LaTeX code
kable(df, caption = "Model Comparison", colnames = c("Model", "Training Metric", "Train Metric Value", "Test R^2")) %>%
  kable_styling(bootstrap_options = c("striped", "hover"),
                latex_options = "HOLD_position")

coef(ridge.cv) %>% broom::tidy() %>% left_join(broom::tidy(coef(lasso.cv)), by = "row") %>%
  mutate(value.x = round(value.x, 4),
         value.y = round(value.y, 4)) %>%
  dplyr::select(1, "C.V. Ridge Coefficient" = 3, "C.V. Lasso Coefficient" = 5) %>%
  kable(caption = "Comparing Coefficeints from C.V. Ridge and Lasso models")  %>%
  kable_styling(bootstrap_options = c("striped", "hover"),
                latex_options = "HOLD_position")


anova(lm.bh) %>% broom::tidy() %>% dplyr::select(1,5,6) %>%
  full_join(broom::tidy(anova(lm.lasso)), by = "term") %>%
  dplyr::select(1:3,7,8) %>%
  mutate(statistic.x = round(statistic.x, 3),
         p.value.x = round(p.value.x, 5),
         statistic.y = round(statistic.y, 3),
         p.value.y = round(p.value.y, 5)) %>%
  arrange(desc(statistic.x)) %>%
  dplyr::select("Predictor" = 1, "LM-BH F-Stat" = 2, "LM-BH p-value" = 3,
                "LM-Lasso F Stat" = 4, "LM-Lasso p-value" = 5) #%>% xtable()

broom::tidy(summary(lm.bh)) %>% 
  full_join(broom::tidy(summary(lm.lasso)), by = "term") %>%
  filter(abs(estimate.x) > 1 | abs(estimate.y) > 1) %>%
  dplyr::select("Variable" = 1, "LM-BH Coef" = 2, "LM-BH p-value" = 5, "LM-Lasso Coef" = 6,
                "LM-Lasso p-value" = 9) %>%
  xtable()

lm.xg <- lm(data = train, logTotalValue ~ BldgArea)

lm.xg.pred <- predict(lm.xg, newdata=test)

rss <- sum((lm.xg.pred - test$logTotalValue) ^ 2)
tss <- sum((X[nrow(train):nrow(X),ncol(train)] - mean(X[nrow(train):nrow(X),ncol(train)])) ^ 2)
r.squared <- 1 - rss/tss
rss
r.squared


# LM-Lasso Residual Plots
par(mfrow = c(2,2))
plot(lm.lasso)


