source("c:/dev/lifidea/etc/intern/rs_library.R")
anno = read.table('annotationsB06_July.csv', sep=',',quote='',header=TRUE) # Query annotations
ichk = read.table('docs_ichk_all.txt.result',sep='\t',quote='',header=TRUE) # Index check results

train  = import_data('train', anno, ichk)
sfcounts_train = get.sfcounts(train$add, ichk)
test  = import_data('test', anno, sfcounts = sfcounts_train)

#test_f  = filter.queries.by( test,  ichk = ichk )
#test_f2 = filter.queries.by( test )

# Overall Change
daily.change( train$daily)
daily.change( test$daily)

# TopK Unstable Queries
write.table(train$agg[order(train$agg$rNDCG5, decreasing=T),c(1:34,509:510,484:508,483)], file='aggregate_table_train.tsv',sep='\t')
write.table(test$agg[order(test$agg$rNDCG5, decreasing=T),c(1:34,509:510,484:508,483)], file='aggregate_table_test.tsv',sep='\t')

# Changed Docs
daily.cdocs(test$cdocs)
daily.cdocs(test_f$cdocs)
daily.cdocs(test_f2$cdocs)

# Temporary vs. Permanent Analysis
cdocs_tr = train$cdocs[!(train$cdocs$QID %in% sfcounts_train$QID),]
cdocs_te = test$cdocs[!(test$cdocs$QID %in% sfcounts_train$QID),]

result = lifetime.add( cdocs_tr, '6_12_2010' )
result = lifetime.add( cdocs_te, '6_26_2010' )
result = lifetime.del( cdocs_tr, '6_12_2010' )
result = lifetime.del( cdocs_te, '6_26_2010' )

train_swaptbl = get.wide.swap.table( cdocs_tr[cdocs_tr$Type == 'swapP' | cdocs_tr$Type == 'swapU' | cdocs_tr$Type == 'swapN',] )
result = lifetime.swap( train_swaptbl, cdocs_tr, '6_12_2010' )
test_swaptbl = get.wide.swap.table( cdocs_te[cdocs_te$Type == 'swapP' | cdocs_te$Type == 'swapU' | cdocs_te$Type == 'swapN',] )
result = lifetime.swap( test_swaptbl, cdocs_te, '6_26_2010' )

#######################################
#  Comparison of Top3 Search Engines  #

bing = import_data('bing', skip=T)
yaho = import_data('yaho', skip=T)
goog = import_data('goog', skip=T)

daily.change( bing$daily)
daily.change( yaho$daily)
daily.change( goog$daily)


rbind(
mean(bing$agg$rNDCG5),
mean(yaho$agg$rNDCG5),
mean(goog$agg$rNDCG5),
mean(bing$agg$Tau5)  ,
mean(yaho$agg$Tau5)  ,
mean(goog$agg$Tau5)  ,
mean(bing$agg$NDCG5) ,
mean(yaho$agg$NDCG5) ,
mean(goog$agg$NDCG5))

daily.cdocs(bing$cdocs)
daily.cdocs(yaho$cdocs)
daily.cdocs(goog$cdocs)

agg_m = merge(yaho$agg,  goog$agg, by='QID', suffixes=c('.y','.g'))
agg_m = merge(agg_m, bing$agg, by='QID', suffixes=c('','.b'))
write.table(cor(agg_m[,c(2:34,36:68,70:102)]), file='compare_analysis_0716.txt',sep='\t')

#################################
# Factors that Affect Stability #


agg = test$agg[test$agg$rNDCG > 0,]
boxplot( agg$rNDCG5 ~ cut(agg$log_freq, 5), varwidth=T, outline=F, xlab='log(Freq)', ylab='Instability' )
boxplot( agg$rNDCG5 ~ cut(agg$NDCG5, 5), varwidth=T, outline=F, xlab='NDCG5', ylab='Instability' )
boxplot( agg$rNDCG5 ~ cut(agg$dScore5, 5), varwidth=T, outline=F, xlab='dScore5', ylab='rNDCG5' )

boxplot( agg[agg$Length < 12,]$rNDCG5 ~ agg[agg$Length < 12,]$Length,varwidth=T, outline=F, xlab='Length', ylab='Instability' )


boxplot( agg$rNDCG5 ~ agg$Navi == 1, varwidth=T, outline=F , xlab='Navigational', ylab='Instability')
boxplot( agg$rNDCG5 ~ agg$sfresh > 5, varwidth=T, outline=F, xlab='SuperFresh', ylab='Instability' )
boxplot( agg$rNDCG5 ~ agg$Length > 8, varwidth=T, outline=F, xlab='Length > 8', ylab='Instability' )


