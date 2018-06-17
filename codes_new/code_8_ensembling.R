###################################
#                                 #
#             SETTINGS            #
#                                 #
###################################

# clearing the memory
rm(list = ls())

# installing pacman
if (require(pacman) == F) install.packages("pacman")
library(pacman)

# libraries
p_load(beepr, AUC, compiler)


###################################
#                                 #
#            FUNCTIONS            #
#                                 #
###################################

# There are two functions: 
# 1) ES performs simple Ensemble Selection.
# 2) BES performs Bagged Ensemble Selection.

# function for perfroming ES
ES <- cmpfun(function(X, Y, iter = 100L, display = T){
  
  # setting initial values
  N           <- ncol(X)
  weights     <- rep(0L, N)
  pred        <- 0 * X
  sum.weights <- 0L
  
  # performing hill-climbing
  while(sum.weights < iter) {
    
    # displyaing iteration number  
    if (display == TRUE) {
      print(paste0("ES - iteration ", (sum.weights+1), "/", iter))
    }
    
    # optimizing
    sum.weights   <- sum.weights + 1L
    pred          <- (pred + X) * (1L / sum.weights)
    auc           <- apply(pred, 2, function(x) auc(roc(x, Y)))
    best          <- which.max(auc)
    weights[best] <- weights[best] + 1L
    pred          <- pred[, best] * sum.weights
  }
  
  # returning model weights
  return(weights / sum.weights)
})

# function for performing bagged ES
BES <- cmpfun(function(X, Y, bags = 10L, p = 0.5, iter = 100L, display = T){
  
  # setting initial values
  i <- 0L
  N <- nrow(X)
  M <- ncol(X)
  W <- matrix(rbinom(bags * M, 1, p), ncol = M)
  
  # performing bagging
  while(i < bags)  {
    
    # displyaing iteration number  
    if (display == TRUE) {
      print(paste0("BES - bag ", i+1, "/", bags))
    }
    
    # doing ES on a bagged sample
    i         <- i + 1L
    ind       <- which(W[i, ] == 1)
    W[i, ind] <- W[i, ind] * ES(X[, ind], Y, iter)
  }
  
  # returning model weights
  return(colSums(W) / bags)
})



###################################
#                                 #
#          PREPARATIONS           #
#                                 #
###################################

# load valid data
valid <- read.csv2(file.path("../pred_valid", file.list[1]), sep = ",", dec = ".", header = T)
valid <- valid[order(c(valid$CustomerIdx, valid$IsinIdx, valid$BuySell, valid$Week)), ]
valid <- valid[, c("CustomerIdx", "IsinIdx", "BuySell", "Week", "CustomerInterest")]

# load all predictions
file.list <- list.files("../pred_valid")
preds <- list()
for (i in 1:length(file.list)) {
  print(file.path("Loading ", file.list[i]))
  data       <- read.csv2(file.path("../pred_valid", file.list[i]), sep = ",", dec = ".", header = T)
  preds[[i]] <- data[order(c(data$CustomerIdx, data$IsinIdx, data$BuySell, data$Week)), ]
}

# create prediction matrix
pred.matrix <- data.frame(CustomerIdx = valid$CustomerIdx)
for (i in 1:length(file.list)) {
  pred.matrix <- cbind(pred.matrix, preds[[i]]$TARGET)
}

# assign colnames
pred.matrix <- pred.matrix[, 2:ncol(pred.matrix)]
colnames(pred.matrix) <- file.list

# extract real values
real <- as.factor(valid$CustomerInterest)



#################################
#                               #
#       REMOVE SOME MODELS      #
#                               #
#################################

######## REMOVE CORRELATED PREDICTIONS

# set correlation threshold
threshold <- 0.99

# computing correlations
cors <- cor(pred.matrix)

# setting matrix to triangle form
for (i in 1:nrow(cors)) {
  for (j in 1:nrow(cors)) {
    if (i >= j) {cors[i,j] <- 0}
  }
}

# creating objects
t <- 1
m1 <- list()
m2 <- list()

# finding corelations > threshold
for (i in 1:nrow(cors)) {
  for (j in 1:nrow(cors)) {
    if (cors[i,j] > threshold) {
      m1[[t]] <- rownames(cors)[i]
      m2[[t]] <- colnames(cors)[j]
      t <- t + 1
    }
  }
}

# computing AUC on validation
aucs <- apply(pred.matrix, 2, function(x) auc(roc(x, real)))

# selecting correlated models with lower AUC
bad <- list()
for (t in 1:length(m1)) {
  au <- c(aucs[m1[[t]]], aucs[m2[[t]]])
  bad[[t]] <- names(which.min(au))
}

# removing correlated models with lower AUC
pred.matrix <- pred.matrix[, !(colnames(pred.matrix) %in% unique(bad))]

# save the list of models
good.models <- colnames(pred.matrix)


######## REMOVE WEAK PREDICTIONS

# set AUC threshold
threshold <- 0.8

# drop weak classifiers
aucs <- apply(pred.matrix, 2, function(x) auc(roc(x, real)))
good <- names(aucs)[aucs > threshold]
pred.matrix <- pred.matrix[, colnames(pred.matrix) %in% good]

# savethe list of models
good.models <- colnames(pred.matrix)



###################################
#                                 #
#            ENSEMBLING           #
#                                 #
###################################

# extract number of models
k <- ncol(pred.matrix)

# mean and median predictions
pred.matrix$mean   <- apply(pred.matrix[,1:k], 1, mean)
pred.matrix$median <- apply(pred.matrix[,1:k], 1, median)

# TOP-N mean ensembles
aucs  <- apply(pred.matrix, 2, function(x) auc(roc(x, real)))
top3  <- names(aucs)[order(aucs, decreasing = T)[1:3]]
top5  <- names(aucs)[order(aucs, decreasing = T)[1:5]]
top10 <- names(aucs)[order(aucs, decreasing = T)[1:10]]
pred.matrix$top3  <- apply(pred.matrix[, top3],  1, mean)
pred.matrix$top5  <- apply(pred.matrix[, top5],  1, mean)
pred.matrix$top10 <- apply(pred.matrix[, top10], 1, mean)

# ensemble selection
es.weights <- ES(X = pred.matrix[,1:k], Y = real, iter = 100)
names(es.weights) <- colnames(pred.matrix)[1:length(es.weights)]
pred.matrix$es <- apply(pred.matrix[,1:k], 1, function(x) sum(x*es.weights))

# bagged ensemble selection
bes.weights <- BES(X = pred.matrix[,1:k], Y = real, iter = 100, bags = 10, p = 0.5)
pred.matrix$bag_es <- apply(pred.matrix[,1:k], 1, function(x) sum(x*bes.weights))

# computing AUC
aucs <- apply(pred.matrix, 2, function(x) auc(roc(x, real)))
aucs



###################################
#                                 #
#       PREDICTING TEST DATA      #
#                                 #
###################################

######## PREPARATIONS

# load test data
test <- read.csv2("../submissions/naive.csv", sep = ",", dec = ".", header = T)
test <- test[order(test$PredictionIdx), ]

# load all predictions
for (i in 1:length(good.models)) {
  print(file.path("Loading ", good.models[i]))
  data <- read.csv2(file.path("../submissions", good.models[i]), sep = ",", dec = ".", header = T)
  preds[[i]] <- data[order(data$PredictionIdx), ]
}

# create prediction matrix
pred.matrix <- data.frame(PredictionIdx = test$PredictionIdx)
for (i in 1:length(good.models)) {
  pred.matrix <- cbind(pred.matrix, preds[[i]]$CustomerInterest)
}

# assign colnames
pred.matrix <- pred.matrix[, 2:ncol(pred.matrix)]
colnames(pred.matrix) <- good.models


######## ENSEMBLING

# extracting number of models
k <- ncol(pred.matrix)

# mean and median predictions
pred.matrix$mean   <- apply(pred.matrix[, 1:k], 1, mean)
pred.matrix$median <- apply(pred.matrix[, 1:k], 1, median)

# TOP-N mean ensembles
pred.matrix$top3  <- apply(pred.matrix[, top3],  1, mean)
pred.matrix$top5  <- apply(pred.matrix[, top5],  1, mean)
pred.matrix$top10 <- apply(pred.matrix[, top10], 1, mean)

# ensemble selection
pred.matrix$es <- apply(pred.matrix[, 1:k], 1, function(x) sum(x*es.weights))

# bagged ensemble selection
pred.matrix$bes <- apply(pred.matrix[, 1:k], 1, function(x) sum(x*bes.weights))


######## EXPORT

# best method
method <- "es"

# computing correlation with the best submission
best.sub <- read.csv(paste0("./submissions/rankmean_4_submits.csv"))$CustomerInterest
cor(pred.matrix[[method]], best.sub)

# exporting submissions
submit(pred.matrix[[method]], data = data.unknown, folder = subm.folder, 
       file = paste0("auc", aucs[method], "_ensemble_", method, ".csv"))