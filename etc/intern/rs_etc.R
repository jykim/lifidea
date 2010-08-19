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


