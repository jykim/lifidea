dt = read.table('time_by_itype',header=T,sep=',')
hist(dt[which(dt$itype=='query_doctrack'),2])
boxplot(dt$time ~ dt$itype, varwidth=T, ylim=c(0,30))