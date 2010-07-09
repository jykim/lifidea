setwd("c:/data")
source("code/rs_import_data.R")
source("code/rs_library.R")

# 
aggregate( docs$QID , by=list(docs$Type), FUN = length)
result = aggregate( docs$QID , by=list(docs$Date, docs$Type), FUN = length)
reshape(result, v.names='x', idvar='Group.1', timevar='Group.2',direction='wide')

# Documents dropped from 1
docs_1   = docs[docs$Rank == 1 & docs$Type == 'del',]   # Queries with change in rank list
aggregate( docs_1$QID , by=list(docs_1$Date), FUN = length)

# Export the list of added & deleted documents
#aggregate( docs_a$URL , by=list(docs_a$URL), FUN = length)


# The set of additions vs. swaps 
qry_a = aggregate( docs_a$QID , by=list(docs_a$QID), FUN = length)
qry_s = aggregate( docs_s$QID , by=list(docs_s$QID), FUN = length)
lapply( list( qry_a[[1]], qry_s[[1]], setdiff( qry_a[[1]] , qry_s[[1]]), 
		setdiff( qry_s[[1]] , qry_a[[1]]), intersect( qry_s[[1]] , qry_a[[1]])), 'length')

		
# Dist. of Position for deleted/added/swapped documents
par ( mfrow=c(1,3) ) 
hist( docs[docs$Type == 'del',]$Rank, main='Rank dist. of deleted docs')   # Queries with change in rank list
hist( docs[docs$Type == 'add',]$Rank, main='Rank dist. of added docs')   # Queries with change in rank list
hist( docs[docs$Type == 'swapP' | docs$Type == 'swapU' | docs$Type == 'swapN',]$Rank, main='Rank dist. of swapped docs')   # Queries with change in rank list

# No. of swaps in each deltaScore range
r_score = aggregate( docs_s$dScore, by=list(docs_s$SwapID), FUN = sub_pair )
r_score_a = aggregate( docs_s$dScore, by=list(docs_s$SwapID), FUN = sub_pair_a )
r_rank = aggregate( docs_s$Rank, by=list(docs_s$SwapID), FUN = sub_pair )
result = merge(r_rank, r_score, by='Group.1')
plot(abs(result$x.x), abs(result$x.y))
boxplot(abs(result$x.y) ~ abs(result$x.x))

# Transform Swapped pair data into wide format
docs_sw = merge( 
rbind( docs_s[seq(1,nrow(docs_s),by=4),], docs_s[seq(2,nrow(docs_s),by=4),]),
rbind( docs_s[seq(3,nrow(docs_s),by=4),], docs_s[seq(4,nrow(docs_s),by=4),]), by=c('QID','Type','URL','Judgment','HRS','SwapID'), suffixes = c(".b",".a"))
write.table(docs_sw, file='docs_s_wide.txt', sep='\t')

# Transform Swapped pair data into wider format
docs_swr = merge( 
merge( docs_s[seq(1,nrow(docs_s),by=4),], docs_s[seq(2,nrow(docs_s),by=4),], by=c('Date','QID','Type','NDCG1','NDCG3','NDCG5','NDCG10','SwapID')),
merge( docs_s[seq(3,nrow(docs_s),by=4),], docs_s[seq(4,nrow(docs_s),by=4),], by=c('Date','QID','Type','NDCG1','NDCG3','NDCG5','NDCG10','SwapID')), by=c('QID','Type','SwapID','URL.x','URL.y','Judgment.x','Judgment.y','HRS.x','HRS.y'), suffixes = c(".b",".a"))
write.table(docs_swr, file='docs_s_wider.txt', sep='\t')

# P(swap) against deltaScore1
dscore1 = read.table('dscore1_0610.txt')
swap_12 = docs_swr[(docs_swr$Rank.x.b == 1 & docs_swr$Rank.y.b == 2) | (docs_swr$Rank.x.b == 2 & docs_swr$Rank.y.b == 1),]
par ( mfrow=c(2,1) )
hist(dscore1$V1, breaks = seq(0,10,by=0.05))
hist(abs(swap_12$Score.x.b - swap_12$Score.y.b),breaks = seq(0,10,by=0.05))

