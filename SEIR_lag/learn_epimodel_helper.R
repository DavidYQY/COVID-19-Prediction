library(deSolve)
library(RColorBrewer)
library(data.table)
library(ggplot2)
library(EpiModel)

# SEIR model ------
SEIR <- function(t, t0, parms) {
  with(as.list(c(t0, parms)), {
    
    # Population size, which is changing because people dies
    num <- s.num + e.num + i.num + r.num
    
    # Effective contact rate and FOI from a rearrangement of Beta * c * D
    ce <- R0 / i.dur # the people amount one could spread to before he recovers, the speed is that divide by i.dur
    lambda <- ce * i.num/num # when people dies more the infection rate is higher
    
    dS <- -lambda*s.num
    dE <- lambda*s.num - (1/e.dur)*e.num
    dI <- (1/e.dur)*e.num - (1 - cfr)*(1/i.dur)*i.num - cfr*(1/i.dur)*i.num
    dR <- (1 - cfr)*(1/i.dur)*i.num 
    
    # Compartments and flows are part of the derivative vector
    # Other calculations to be output are outside the vector, but within the containing list
    list(c(dS, dE, dI, dR, 
           se.flow = lambda * s.num,
           ei.flow = (1/e.dur) * e.num,
           ir.flow = (1 - cfr)*(1/i.dur) * i.num,
           d.flow = cfr*(1/i.dur)*i.num),
         num = num,
         i.prev = i.num / num,
         ei.prev = (e.num + i.num)/num)
  })
}

get_Infected_table <- function(origin_df){
  "origin_df: the data from us_covid19_daily.csv after adding Infected col"
  "N: the total number of people in US"
  
  Infected_table <- data.table(origin_df)
  Infected_table[is.na(recovered), recovered := 0]
  Infected_table[, Infected := positive - recovered]
  
  Infected_table <- Infected_table[Infected > 10, .(date, Infected)] # start at 10 patients
  Infected_table <- Infected_table[order(date)]
  Infected_table[, date := as.character(date)]
  Infected_table$date <- sapply(Infected_table$date, function(x){
    paste(substring(x, 1, 4), substring(x, 5, 6), substring(x, 7, 8), sep="-")
  })
  Infected_table[, date := as.Date(date)]
  
  Infected_table$Infected # the infected count
  Infected_table <- data.table(Infected_table)
  Infected_table[,days := 1:nrow(Infected_table)]
  
  Infected_table
}


SEIR_general_fitting <- function(fitting_df, N, e.dur = 5.2, i.dur = 2.3, cfr = 0.05){
  "Remind we've divided the covid spread into 3 periods"
  "fitting_df: should only contain one period information, with two cols"
  "1. date"
  "2. Infected: the cumulative infected patient count at particular date"
  "three parameters value copied from xihong's paper and general sense of death rate"
  "e.dur: Latent period (e \to i)"
  "i.dur: Infectious period (i \to quarantine)"
  "cfr: death rate"
  
  
  Infected <- fitting_df$Infected
  day <- 0:(length(Infected)-1)
  
  init <- c(s.num = N-3*Infected[1], e.num = 2*e.dur/i.dur*Infected[1], i.num = Infected[1], r.num = 0,
            se.flow = 0, ei.flow = 0, ir.flow = 0, d.flow = 0)
  
  RSS.SEIR <- function(parameters) {
    " the loss function of SEIR, log MSE "
    names(parameters) <- c("R0")
    out <- ode(y = init, times = day, func = SEIR, parms = parameters)
    # print(out)
    fit <- out[ , "i.num"]
    # RSS <- sum((Infected - fit)^2)
    # I think a more appropriate criteria would be log difference,
    # the original RSS give too much weight to the later terms
    # actually the fitted value does not change much
    RSS <- sum((log(Infected) - log(fit))^2)
    return(RSS)
  }
  
  
  set.seed(12)
  # start from \beta = 2 * \gamma
  Opt <- optim(2, RSS.SEIR, method = "L-BFGS-B", lower = 0.1, upper = 100)
  Opt
  
}


SEIR_US_fitting_three_period <- function(Infected_table, N){
  
  
  starting_date <- Infected_table[1, ]$date # "2020-02-29"
  
  total_days <- nrow(Infected_table)
  
  # separate the whole covid spread into three periods
  # the first two periods have exponential growth with different rate
  # the final period has linear growth
  # there are two knots serves as cutoff, initialize as zero
  # assume each period has at least length 5
  knot1 <- 0
  knot2 <- 0
  
  # one period loss
  Opt <- SEIR_general_fitting(Infected_table, N)
  one_period_loss <- Opt$value
  print(paste0("one_period_loss: ", one_period_loss))
  bestFlag <- "one period"
  
  
  # two period loss
  knot2_loss <- c()
  for (knot2 in 10:(total_days-5)){
    linear_period <- Infected_table[(knot2):total_days, ]
    linear_period[, days:= 1:nrow(linear_period)]
    # rm(list = "Infected")
    linear_model_3rd_period <- lm(Infected ~ days, data = linear_period)
    prediction_3rd <- predict(linear_model_3rd_period)
    if (any(prediction_3rd < 0)){
      knot2_loss <- c(knot2_loss, NA)
      next
    }
    loss_3rd <- sum((log(prediction_3rd) - log(linear_period$Infected))^2)
    # print(loss_3rd)
    Opt <- SEIR_general_fitting(Infected_table[1:knot2,], N)
    loss_12 <- Opt$value
    knot2_loss <- c(knot2_loss, loss_12 + loss_3rd)
  }
  
  # US 25
  knot2_best <- which.min(knot2_loss) + 10 -1
  two_period_loss <- min(knot2_loss, na.rm = T)
  print(paste0("two_period_loss: ", two_period_loss))
  
  if (two_period_loss > 0.5*one_period_loss | one_period_loss < 1){
    knot2_best <- total_days
    print("no need to add linear period")
  }else{
    bestFlag <- "two period"
  }
  
  # three period loss
  knot12_loss <- c()
  for (knot1 in 5:(knot2_best-5)){
    period1 <- Infected_table[1:knot1, ]
    period2 <- Infected_table[knot1:knot2_best, ]
    Opt1 <- SEIR_general_fitting(period1, N)
    loss_1 <- Opt1$value
    Opt2 <- SEIR_general_fitting(period2, N)
    loss_2 <- Opt2$value
    
    if (knot2_best == total_days){
      loss_3rd <- 0 # no linear period
    }else{
      linear_period <- Infected_table[(knot2_best+1):total_days, ]
      linear_period$days <- 1:nrow(linear_period)
      # rm(list = "Infected")
      linear_model_3rd_period <- lm(Infected ~ days, data = linear_period)
      prediction_3rd <- predict(linear_model_3rd_period)
      loss_3rd <- sum((log(prediction_3rd) - log(linear_period$Infected))^2)
    }
    
    knot12_loss <- c(knot12_loss, loss_1 + loss_2 + loss_3rd)
  }
  
  knot1_best <- which.min(knot12_loss) + 5 -1
  three_period_loss <- min(knot12_loss, na.rm = T)
  
  print(paste0("three_period_loss: ", three_period_loss))
  
  if(bestFlag == "one period"){
    if (three_period_loss > 0.5*one_period_loss | one_period_loss < 1){
      knot1_best <- 1
      print("no need to use two expo period")
    }else{
      bestFlag <- "two expo period"
    }
  }else if(bestFlag == "two period"){
    if (three_period_loss > 0.5*two_period_loss | two_period_loss < 1){
      knot1_best <- 1
      print("no need to use three period")
    }else{
      bestFlag <- "three period"
    }
  }else{
    stop("bestFlag not in one period and two period")
  }

  
  print(paste0("The best method is ", bestFlag, " method."))
  
  if(bestFlag == "one period"){
    return(list(
      knot1Flag = 0,
      knot2Flag = 0,
      knot1 = NA,
      knot2 = NA,
      loss = one_period_loss
    ))
  }else if(bestFlag == "two period"){
    return(list(
      knot1Flag = 0,
      knot2Flag = 1,
      knot1 = NA,
      knot2 = knot2_best,
      loss = two_period_loss
    ))
  }else if(bestFlag == "two expo period"){
    return(list(
      knot1Flag = 1,
      knot2Flag = 0,
      knot1 = knot1_best,
      knot2 = NA,
      loss = three_period_loss
    ))
  }else if (bestFlag == "three period"){
    return(list(
      knot1Flag = 1,
      knot2Flag = 1,
      knot1 = knot1_best,
      knot2 = knot2_best,
      loss = three_period_loss
    ))
  }else{
    stop("bestFlag not in one two three!")
  }
  
  
}


SEIR_fitted_infected <- function(fitting_df, R0, e.dur = 5.2, i.dur = 2.3, cfr = 0.05, nsteps = NULL){
  "return the estimated infection number given the fitted R0"
  "nsteps: the steps you want to fit, when NULL use nrow of fitting_df"
  
  if(is.null(nsteps)){
    nsteps <- nrow(fitting_df)
    # print(nsteps)
  }
  
  # the fitted initial condition
  Infected <- fitting_df$Infected
  param <- param.dcm(R0 = R0, e.dur = e.dur, i.dur = i.dur, cfr = cfr)
  init <- init.dcm(s.num = N-3*Infected[1], e.num = 2*e.dur/i.dur*Infected[1], i.num = Infected[1], r.num = 0,
                   se.flow = 0, ei.flow = 0, ir.flow = 0, d.flow = 0)
  control <- control.dcm(nsteps = nsteps, dt = 1, new.mod = SEIR)
  mod <- dcm(param, init, control)
  
  # reformalize the model output into a datatable
  mod_epi <- data.table()
  for (colname in names(mod$epi)){
    mod_epi[, (colname) := mod$epi[[colname]]]
  }
  
  mod_epi$date <- 1:nsteps
  
  mod_epi$i.num
}


report_fitted_result <- function(best_knots, Infected_table, plot.show.flag=T, plot_title="US"){
  knot1Flag <- best_knots$knot1Flag
  knot2Flag <- best_knots$knot2Flag
  
  starting_date <- Infected_table[1, ]$date
  total_days <- nrow(Infected_table)
  
  if(knot1Flag == 0){
    knot1 = 0
  }else{
    knot1 = best_knots$knot1
  }
  
  if(knot2Flag == 0){
    knot2 = total_days
  }else{
    knot2 = best_knots$knot2
  }
  
  
  # 1st period
  if (knot1Flag != 0){
    period1 <- Infected_table[1:knot1,]
    Opt1 <- SEIR_general_fitting(period1, N)
    y1 <- SEIR_fitted_infected(period1, Opt1$par)
  }else{
    y1 <- NULL
    Opt1 <- NULL
  }
  
  # 2rd period
  period2 <- Infected_table[(1+knot1):knot2,]
  Opt2 <- SEIR_general_fitting(period2, N)
  y2 <- SEIR_fitted_infected(period2, Opt2$par)
  period2_end <- y2[length(y2)]
  
  # linear period
  if (knot2Flag != 0){
    linear_period <- Infected_table[(1+knot2):total_days,]
    linear_period$days <- 1:nrow(linear_period)
    linear_model_3rd_period <- lm(Infected-period2_end ~ 0 + days, data = linear_period)
    y3 <- predict(linear_model_3rd_period) + period2_end
    linear_daily_increase <- linear_model_3rd_period$coefficients
  }else{
    y3 <- NULL
    linear_daily_increase <- NULL
  }
  
  y_prediction <- c(y1, y2, y3)
  
  first_period_end <- starting_date + knot1-1
  second_period_end <- starting_date + knot2-1
  end_date <- starting_date + total_days - 1 
  
  if(knot1Flag == 0){
    print("No first period")
  }else{
    print(paste0("The first period is from ", starting_date, " to ", first_period_end))
    print(paste0("The R0 value in the first period is: ", Opt1$par))
  }
  
  print(paste0("The second period is from ", first_period_end + 1, " to ", second_period_end))
  print(paste0("The R0 value in the second period is: ", Opt2$par))
  
  if(knot2Flag == 0){
    print("No linear period")
  }else{
    print(paste0("The linear period is from ", second_period_end + 1, " to ", end_date))
    print(paste0("The daily increase in the final period is: ", linear_model_3rd_period$coefficients))
  }
  
  p <- ggplot(Infected_table) + 
      geom_line(aes(x = date, y = y_prediction)) +
      geom_point(aes(x=date, y=Infected)) +
      scale_y_continuous(trans = 'log10') +
      ggtitle(plot_title) +
      ylab("Current Infected Count")
  if(plot.show.flag == T){
    print(p)
  }
  
  if(knot2Flag == 0){
    knot2 = NA
  }
  
  if(knot1Flag == 0){
    knot1 = NA
  }
  
  return(list(
    y_prediction = y_prediction,
    linear_daily_increase = linear_daily_increase,
    Opt1 = Opt1,
    Opt2 = Opt2,
    knot1 = knot1,
    knot2 = knot2,
    p = p,
    loss = best_knots$loss
    )
  )
  
}
