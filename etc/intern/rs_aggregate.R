# Reading
setwd("c:/data")
source("code/rs_import_data.R")
source("code/rs_library.R")

#hist(agg$NDCG5, breaks=20)

# Subset of Data
d_hPerf = subset(agg, agg$NDCG5 > 0.5)
d_lPerf = subset(agg, agg$NDCG5 < 0.5)
d_hvar = subset(agg, agg$vNDCG5 > 0.005)
d_var = subset(agg, agg$vNDCG5 > 0)
d_nvar = subset(agg, agg$vNDCG5 == 0)


# Query-level Feature Selection 
agganno = merge(anno, agg, by.y='qID', by.x='QueryID')
write.table(cor(agganno[,2:45]), file='query_features.csv', sep=',')

# rNDCG ~ Freq
par ( mfrow=c(2,1) ) 
boxplot( agg$rNDCG5 ~ cut(agg$log_freq, 10), varwidth=T, outline=F )
boxplot( agg_r$rNDCG5 ~ cut(agg_r$log_freq, 10), varwidth=T, outline=F )

###--------------- DEPRECATED 
### CoPlot
data = agg
coplot(data$vNDCG5 ~ data$dScore5 | data$NDCG5)
data = d_var
coplot(data$vNDCG5 ~ data$dScore5 | data$NDCG5)

### Boxplot
par ( mfrow=c(2,3) ) 

factorize <- function(vector, number)
{
	 return(sapply(sapply(sapply( vector, '*',number), round), '/',number));
}

data = d_var
par ( mfrow=c(2,3) ) 
boxplot(data$vNDCG5 ~ factorize(data$dScore5,2),xlab='dScore',ylab='vNDCG')
boxplot(data$vNDCG5 ~ factorize(data$NDCG5, 10),xlab='nNDCG')
boxplot(data$vNDCG5 ~ factorize(data$Length, 0.5),xlab='length')

data = agg
boxplot(data$vNDCG5 ~ factorize(data$dScore5,2),xlab='dScore',ylab='vNDCG')
boxplot(data$vNDCG5 ~ factorize(data$NDCG5, 10),xlab='nNDCG')
boxplot(data$vNDCG5 ~ factorize(data$Length, 0.5),xlab='length')

### Count # of NAs
# DATE / URL
hrs_na = read.table('hrs_na.txt', sep='\t')
hrs_na = transform( hrs_na, V1 = as.Date(V1, "%m/%d/%Y"))
aggregate( hrs_na$V2, by=list(hrs_na$V1), FUN = length )
daily_url = aggregate( hrs_na$V2, by=list(hrs_na$V1), FUN = unique )

# Count no. of Unique URLs added each day
count_unique <- function(tbl)
{
	all_urls = c()
	 for(i in (1:nrow(tbl)))
	 {
		cur_urls = as.vector(tbl[i,]$x[1][[1]])
		print(paste(tbl[i,1], length(setdiff(cur_urls, all_urls)), length(all_urls), collapse="\t"))
		all_urls = union(all_urls, cur_urls)
		#print( class(cur_urls))
	 }
}

count_unique( daily_url )
