setwd("c:/data")
source("code/rs_import_data.R")
source("code/rs_library.R")

daily_chg = daily[daily$Tau != 1.0,]   # Queries with change in rank list
daily_imp1 = daily[daily$dNDCG1 > 0,] # Queries with change in perf. (+)
daily_deg1 = daily[daily$dNDCG1 < 0,] # Queries with change in perf. (-)
daily_imp3 = daily[daily$dNDCG3 > 0,] # Queries with change in perf. (+)
daily_deg3 = daily[daily$dNDCG3 < 0,] # Queries with change in perf. (-)
daily_imp5 = daily[daily$dNDCG5 > 0,] # Queries with change in perf. (+)
daily_deg5 = daily[daily$dNDCG5 < 0,] # Queries with change in perf. (-)
daily_cchg = daily[daily$cTau != 1.0,]   # Queries with change in rank list
daily_cimp1 = daily[daily$cNDCG1 > 0,] # Queries with change in perf. (+)
daily_cdeg1 = daily[daily$cNDCG1 < 0,] # Queries with change in perf. (-)
daily_cimp3 = daily[daily$cNDCG3 > 0,] # Queries with change in perf. (+)
daily_cdeg3 = daily[daily$cNDCG3 < 0,] # Queries with change in perf. (-)
daily_cimp5 = daily[daily$cNDCG5 > 0,] # Queries with change in perf. (+)
daily_cdeg5 = daily[daily$cNDCG5 < 0,] # Queries with change in perf. (-)


# Create the table of daily aggregate statistics
cbind( 
aggregate( daily$QID , by=list(daily$Date), FUN = length), 
aggregate( daily_chg$QID , by=list(daily_chg$Date), FUN = length), 
aggregate( daily_imp1$QID , by=list(daily_imp1$Date), FUN = length),
aggregate( daily_deg1$QID , by=list(daily_deg1$Date), FUN = length),
aggregate( daily_imp3$QID , by=list(daily_imp3$Date), FUN = length),
aggregate( daily_deg3$QID , by=list(daily_deg3$Date), FUN = length),
aggregate( daily_imp5$QID , by=list(daily_imp5$Date), FUN = length),
aggregate( daily_deg5$QID , by=list(daily_deg5$Date), FUN = length),
aggregate( daily_cchg$QID , by=list(daily_cchg$Date), FUN = length),
aggregate( daily_cimp1$QID , by=list(daily_cimp1$Date), FUN = length),
aggregate( daily_cdeg1$QID , by=list(daily_cdeg1$Date), FUN = length),
aggregate( daily_cimp3$QID , by=list(daily_cimp3$Date), FUN = length),
aggregate( daily_cdeg3$QID , by=list(daily_cdeg3$Date), FUN = length),
aggregate( daily_cimp5$QID , by=list(daily_cimp5$Date), FUN = length),
aggregate( daily_cdeg5$QID , by=list(daily_cdeg5$Date), FUN = length)
)[,c(1,2,4, 6,8,10,12,14,16, 18,20,22,24,26,28,30)]


# Correlation of Daily NDCG
daily_n1 = daily[,c(1,2,6)]
daily_n3 = daily[,c(1,2,7)]
daily_n5 = daily[,c(1,2,8)]
daily_t  = daily[,c(1,2,18)]
daily_w1 = reshape(daily_n1, v.names='dNDCG1', idvar='QID', timevar='Date',direction='wide')
daily_w3 = reshape(daily_n3, v.names='dNDCG3', idvar='QID', timevar='Date',direction='wide')
daily_w5 = reshape(daily_n5, v.names='dNDCG5', idvar='QID', timevar='Date',direction='wide')
daily_wt = reshape(daily_t,  v.names='Tau', idvar='QID', timevar='Date',direction='wide')
write.table( cor(daily_w1[-1]), file='cor_daily1.txt')
write.table( cor(daily_w3[-1]), file='cor_daily3.txt')
write.table( cor(daily_w5[-1]), file='cor_daily5.txt')
write.table( cor(daily_wt[-1]), file='cor_dailyt.txt')

par ( mfrow=c(1,3) ) 
hist( daily[daily$Date == '6/10/2010',][['cNDCG5']])
hist( daily[daily$Date == '6/17/2010',][['cNDCG5']])
hist( daily[daily$Date == '6/23/2010',][['cNDCG5']])

sd( daily[daily$Date == '6/10/2010',][['cNDCG5']])
sd( daily[daily$Date == '6/17/2010',][['cNDCG5']])
sd( daily[daily$Date == '6/23/2010',][['cNDCG5']])
