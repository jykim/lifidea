setwd("c:/data")
source("c:/dev/lifidea/etc/intern/rs_library_analyze.R")
anno = read.table('annotationsB06_July.csv', sep=',',quote='',header=TRUE) # Query annotations
ichk = read.table('docs_ichk_all.txt.result',sep='\t',quote='',header=TRUE) # Index check results

train  = import_data('train', anno)
test  = import_data('test', anno)

#test_f  = filter.queries.by( test,  ichk = ichk )
#test_f2 = filter.queries.by( test )

# Overall Change
daily.change( train$daily)
daily.change( test$daily)

# TopK Unstable Queries
write.table(test$agg[order(test$agg$rNDCG5, decreasing=T),c(1:34,508:509,484:507,483)], file='aggregate_table_test.tsv',sep='\t')

# Changed Docs
daily.cdocs(test$cdocs)
daily.cdocs(test_f$cdocs)
daily.cdocs(test_f2$cdocs)

# Temporary vs. Permanent Analysis
result = lifetime.add( train$cdocs, '6_12_2010' )
result = lifetime.add( test$cdocs, '6_26_2010' )
result = lifetime.del( train$cdocs, '6_12_2010' )
result = lifetime.del( test$cdocs, '6_26_2010' )

train_swaptbl = get.wide.swap.table( train$cdocs[train$cdocs$Type == 'swapP' | train$cdocs$Type == 'swapU' | train$cdocs$Type == 'swapN',] )
result = lifetime.swap( train_swaptbl, train$cdocs, '6_12_2010' )
test_swaptbl = get.wide.swap.table( test$cdocs[test$cdocs$Type == 'swapP' | test$cdocs$Type == 'swapU' | test$cdocs$Type == 'swapN',] )
result = lifetime.swap( test_swaptbl, test$cdocs, '6_26_2010' )

#######################################
#  Comparison of Top3 Search Engines  #

bing = import_data('bing', skip=T)
yaho = import_data('yaho', skip=T)
goog = import_data('goog', skip=T)

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


