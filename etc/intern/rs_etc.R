source("c:/dev/lifidea/etc/intern/rs_library.R")

#########################
#   Feature Selection   #

# Query-level Feature Selection 
anno = read.table('annotationsB06_July.csv', sep=',',quote='',header=TRUE) # Query annotations
agganno = merge(anno, agg, by.y='qID', by.x='QueryID')
write.table(cor(agganno[,2:45]), file='query_features.csv', sep=',')

# Query-URL Feature Selection
f1 = read.table('feature_elliot.tsv', sep='\t',quote='',header=TRUE)
f2 = read.table('feature_log.tsv', sep='\t',quote='',header=TRUE)
f3 = read.table('feature_vitor.tsv', sep='\t',quote='',header=TRUE)
write.table(union(union(intersect(f2$FeatureName, f1[ f1$QueryCoverage / 13560 > 0.5 & f1$ChgNDCG < -0.001, ]$FeatureName), 
			f2[ f2$UrlCoverage < 0.5,]$FeatureName ), intersect(f2$FeatureName, unique(f3$FeatureName)) ), file='d:/B06/B06_FeatureList.txt', quote=FALSE, row.names=FALSE)


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


