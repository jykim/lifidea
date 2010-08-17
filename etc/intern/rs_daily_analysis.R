setwd("c:/data")
source("c:/dev/lifidea/etc/intern/rs_import_data.R")
source("c:/dev/lifidea/etc/intern/rs_library.R")




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
