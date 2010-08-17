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
write.table(test$agg[order(test$agg$rNDCG5, decreasing=T),c(1:34,483:509)][1:50,], file='top50_instable_queries.tsv',sep='\t')
write.table(test$agg[order(test$agg$rNDCG5),c(1:34,483:509)][1:50,], file='top50_stable_queries.tsv',sep='\t')

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

