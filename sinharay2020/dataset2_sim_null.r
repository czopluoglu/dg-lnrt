require(MASS)
require(lavaan)
require(psych)

####################################################################
####################################################################
####################################################################

# A generic function to simulate DG-LNRT data with no item preknowledge

sim_dglnrt <- function() {
  
  # MODEL PARAMETERS
  
  beta  <- rnorm(253,3.98,0.32)
  alpha <- rnorm(253,2.06,0.28)
  
  # Tau for unflagged examinees
  
  cor0 <- matrix(c(1,.95,.95,1),2,2)
  tau0 <- mvrnorm(3186,c(0,0),cor2cov(cor0,c(0.17,0.16)))
  
  # Tau for flagged examinees 
  
  cor1 <- matrix(c(1,.92,.92,1),2,2)
  tau1 <- mvrnorm(94,c(0.19,0.28),cor2cov(cor1,c(0.35,0.30)))
  
  # A vector for item status (0: not disclosed, 1:disclosed)
  
  C    <- rep(0,253)
  
  # null condition, all zeros
  
  # RESPONSE TIME GENERATION
  
  # Note that the response time data generated is
  # already on the log scale
  
  # Unflagged Examinees
  
  rt0 <- matrix(nrow = 3186, ncol = 253)
  
  for (i in 1:3186) {
    for (j in 1:253) {
      p_t = beta[j] - tau0[i, 1]
      p_c = beta[j] - tau0[i, 2]
      p   = p_t * (1 - C[j]) + p_c * C[j]
      rt0[i, j] = rnorm(1, p, 1 / alpha[j])
    }
  }
  
  # Flagged Examinees
  
  rt1 <- matrix(nrow = 94, ncol = 253)
  
  for (i in 1:94) {
    for (j in 1:253) {
      p_t = beta[j] - tau1[i, 1]
      p_c = beta[j] - tau1[i, 2]
      p   = p_t * (1 - C[j]) + p_c * C[j]
      rt1[i, j] = rnorm(1, p, 1 / alpha[j])
    }
  }
  
  # Combine the groups
  
  rt <- rbind(cbind(data.frame(exp(rt0)), gr = 1),
              cbind(data.frame(exp(rt1)), gr = 2))
  
  
  # Random shuffle of examinees
  
  rt <- rt[sample(1:nrow(rt),nrow(rt),replace = FALSE),]
  
  # Introduce missingness as in the dataset 
  # Each half of the examinees respond only to 170 items
  # 87 items are in common.
  
  rt[1:1640,171:253] = NA
  rt[1641:3280,88:170] = NA
  
  
  return(list(
    rt = rt,
    b = beta,
    a = alpha,
    tau_t = c(tau0[, 1], tau1[, 1]),
    tau_c = c(tau0[, 2], tau1[, 2])
  ))
}



PPest <- function(alpha, beta,ltimes){
  
  tau <- c()
  
  for(i in 1:nrow(ltimes)){
    
    missing <- which(is.na(ltimes[i,])==TRUE)
    
    if(length(missing)!=0){
      tau[i] = sum(alpha[-missing]^2*(beta[-missing] - ltimes[i,-missing]))/sum(alpha[-missing]^2)
    } else{
      tau[i] = sum(alpha^2*(beta - ltimes[i,]))/sum(alpha^2)
    }
    
  }
  
  return(tau)
}


Lambdas <- function(ltimes, comp,alpha,beta){
  ncomp=setdiff(1: ncol(ltimes), comp)
  tcomp=PPest(alpha[comp], beta[comp], ltimes[, comp])
  tncomp=PPest(alpha[ncomp], beta[ncomp], ltimes[, ncomp])
  return((tcomp-tncomp)/sqrt(1/sum((alpha[comp])^2) + 1/sum((alpha[ncomp])^2)))
}

##############################################################################

set.seed(4102021)

TypeI <- matrix(nrow=100,ncol=4)

datas <- vector('list',100)
params <- vector('list',100)

for(R in 1:100){
  
  data <- sim_dglnrt()
  
  datas[[R]] <- data
  
  ly        <- data.frame(log(data$rt[,1:253]))
  
  n <- ncol(ly)
  
  
  model     <- paste("f1=~", 
                     paste0("a*X",1:(n-1)," + ", collapse=""), 
                     paste("a*X", n,sep=""))
  
  fit       <- cfa(model = model, 
                   data = ly,
                   missing = 'fiml')
  
  pars      <- coef(fit)
  
  params[[R]] <- pars
  
  alpha.est <- 1/sqrt(pars[1:ncol(ly)])
  beta.est  <- pars[(ncol(ly)+2):(2*ncol(ly)+1)]
  
  L <- Lambdas(ltimes = as.matrix(ly),
               comp   = sample(1:253,91),
               alpha  = alpha.est,
               beta   = beta.est)
  
  TypeI[R,] = c(length(which(L>qnorm(0.9))),
                length(which(L>qnorm(0.95))),
                length(which(L>qnorm(0.99))),
                length(which(L>qnorm(0.999))))
  
  print(R)               
}

round(colMeans(TypeI)/3280,4)

round(apply(TypeI,2,min)/3280,4)

round(apply(TypeI,2,max)/3280,4)

################################################################################

# Parameter recovery

tr <- matrix(NA,100,253)
est <- matrix(NA,100,253)

for(R in 1:100){
  
  tr[R,]  <- datas[[R]]$a
  est[R,] <- 1/sqrt(params[[R]][1:253])
  
}

round(mean(colMeans(tr-est)),3)



tr <- matrix(NA,100,253)
est <- matrix(NA,100,253)

for(R in 1:100){
  
  tr[R,]  <- datas[[R]]$b
  est[R,] <- params[[R]][255:507]
  
}

round(mean(colMeans(tr-est)),3)



