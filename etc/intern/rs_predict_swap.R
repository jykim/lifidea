setwd("c:/data")
source("c:/dev/lifidea/etc/intern/rs_library_predict_swap.R")

batch = 'w1'
cdocs_all = read.table(paste('result_cdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
cdocs = project.table(cdocs_all, c(1:4, 8:16), read.table('EffectiveFeatureList.txt', header=T) )
docs_s   = cdocs[cdocs$Type == 'swapP' | cdocs$Type == 'swapU' | cdocs$Type == 'swapN',]   # Documents swapped
#docs_s   = cdocs[cdocs$Type == 'swapP'| cdocs$Type == 'swapN',]   # Only positive or negative swaps
#stbl1 = create.swap.table( docs_s, 'all', 'swapP' ) # Positive vs. Non-positive
stbl1 = create.swap.table( docs_s, 'all', 'swapN' ) # Non-negative vs. Negative

batch = 'w2'
cdocs_all = read.table(paste('result_cdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
cdocs = project.table(cdocs_all, c(1:4, 8:16), read.table('EffectiveFeatureList.txt', header=T) )
docs_s   = cdocs[cdocs$Type == 'swapP' | cdocs$Type == 'swapU' | cdocs$Type == 'swapN',]   # Documents swapped
stbl2 = create.swap.table( docs_s, 'all', 'swapP' )

batch = 'w3'
cdocs_all = read.table(paste('result_cdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
cdocs = project.table(cdocs_all, c(1:4, 8:16), read.table('EffectiveFeatureList.txt', header=T) )
docs_s   = cdocs[cdocs$Type == 'swapP' | cdocs$Type == 'swapU' | cdocs$Type == 'swapN',]   # Documents swapped
stbl3 = create.swap.table( docs_s, 'all', 'swapP' )

batch = 'w4'
cdocs_all = read.table(paste('result_cdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
cdocs = project.table(cdocs_all, c(1:4, 8:16), read.table('EffectiveFeatureList.txt', header=T) )
docs_s   = cdocs[cdocs$Type == 'swapP' | cdocs$Type == 'swapU' | cdocs$Type == 'swapN',]   # Documents swapped
stbl4 = create.swap.table( docs_s, 'all', 'swapP' )

####################
#     DEBUGGING    #


#analyze.table(stbl1[,11:length(colnames(stbl1))], feature_cnt = 500)
stbl1_t = sample.tbl( stbl1, 1000 )
result = rerank.queries(stbl1_t, '6_11_2010', topk611, topk612, output=T)

stbl1_t = sample.tbl( stbl1, 1000 )
result = rerank.queries( stbl2_t, '6_21_2010', topk621, topk622, train_stbl=stbl1_t )
stbl2_t = sample.tbl( stbl2, 10000 )
stbl3_t = sample.tbl( stbl3, 10000 )
result = rerank.queries( stbl3_t, '6_30_2010', topk630, topk701, train_stbl=stbl2_t )
result = rerank.queries( stbl3_t, '7_1_2010', topk701, topk702, train_stbl=stbl2_t )

result = predict.swap( docs_s, 'all', 'swapP', stbl=stbl1 )

###########################
#     FEATURE ANALYSIS    #

stbl1 = create.swap.table( docs_s, 'all', 'hrsdiff' ) # Positive vs. Non-positive
analyze.table( stbl1[,11:length(colnames(stbl1))], 'all', feature_cnt = 100 )
stbl1 = create.swap.table( docs_s, 'basic', 'swapP' ) # Positive vs. Non-positive
analyze.table( stbl1[,11:length(colnames(stbl1))], 'basic', feature_cnt = 100 )
stbl1_s = project.table(stbl1, c(1:10), colnames(select.features( stbl1[,11:length(colnames(stbl1))], 50)))

################################
#     PREDICTION EXPERIMENT    #

predict.swap( docs_s, 'basic', 	'Bhrsdiff' )
predict.swap( docs_s, 'all', 	'swapP', method='lm')
predict.swap( docs_s, 'all', 	'swapP', method='rf', feature_cnts=c(50) )
predict.swap( docs_s, 'all', 	'Bhrsdiff', method='rf', feature_cnts=c(10) )

predict.swap( docs_s, 'all', 	'swapP', stbl=stbl1, method='mars', feature_cnts=c(10) )
predict.swap( docs_s, 'all', 	'swapP', stbl=stbl1, method='nnet', feature_cnts=c(10) )
predict.swap( docs_s, 'all', 	'swapP', stbl=stbl1, method='ppr', feature_cnts=c(10) )
predict.swap( docs_s, 'all', 	'swapP', stbl=stbl1, method='gam', feature_cnts=c(10) )
predict.swap( docs_s, 'all', 	'swapP', stbl=stbl1, method='svm', feature_cnts=c(10) )

################################
#     QUERY-LEVEL ANALYSIS     #

#query_text = queries[,c(1,length(colnames(queries)))]
result = rerank.queries(stbl1, '6_11_2010', topk611, topk612, output=T)
qrys = read.table('result_all_all.txt', sep="\t", quote='', header=T)
qrys_m = merge( result$queries, qrys, by='QID', suffixes=c('','.ag'))
qrys_m = merge( qrys_m, result$swaps, by='QID')
qrys_m$NDCG5.gain = qrys_m$NDCG5.n - qrys_m$NDCG5

write.table( qrys_m[order(qrys_m$NDCG5.gain,decreasing=T),][1:100,], file='swap_query_example.tsv', sep='\t' )
write.table( qrys_m[order(qrys_m$NDCG5.gain),][1:100,], file='swap_query_example.tsv', append=T, sep='\t' )
write.table( qrys_m[order(qrys_m$yhat, decreasing=T),][1:100,], file='swap_query_example.tsv', append=T, sep='\t' )
write.table( qrys_m[order(qrys_m$yhat),][1:100,], file='swap_query_example.tsv', append=T, sep='\t' )

#################################
#     RE-RANKING EXPERIMENT     #

### WEEK1
topk611 = read.table("top10_20100611.tsv", sep="\t", quote='', header=T)
topk612 = read.table("top10_20100612.tsv", sep="\t", quote='', header=T)
topk613 = read.table("top10_20100613.tsv", sep="\t", quote='', header=T)
topk614 = read.table("top10_20100614.tsv", sep="\t", quote='', header=T)
topk615 = read.table("top10_20100615.tsv", sep="\t", quote='', header=T)
topk616 = read.table("top10_20100616.tsv", sep="\t", quote='', header=T)
topk617 = read.table("top10_20100617.tsv", sep="\t", quote='', header=T)
topk618 = read.table("top10_20100618.tsv", sep="\t", quote='', header=T)

result = data.frame()
thresholds = c(0.1,0.2,0.3,0.4,0.5) ; method = 'rf' ; feature_cnt = 50
result = rbind(result, rerank.queries(stbl1, '6_11_2010', topk611, topk612, thresholds=thresholds, method=method, feature_cnt=feature_cnt))
result = rbind(result, rerank.queries(stbl1, '6_12_2010', topk612, topk613, thresholds=thresholds, method=method, feature_cnt=feature_cnt))
result = rbind(result, rerank.queries(stbl1, '6_13_2010', topk613, topk614, thresholds=thresholds, method=method, feature_cnt=feature_cnt))
result = rbind(result, rerank.queries(stbl1, '6_14_2010', topk614, topk615, thresholds=thresholds, method=method, feature_cnt=feature_cnt))
result = rbind(result, rerank.queries(stbl1, '6_15_2010', topk615, topk616, thresholds=thresholds, method=method, feature_cnt=feature_cnt))
result = rbind(result, rerank.queries(stbl1, '6_16_2010', topk616, topk617, thresholds=thresholds, method=method, feature_cnt=feature_cnt))
result = rbind(result, rerank.queries(stbl1, '6_17_2010', topk617, topk618, thresholds=thresholds, method=method, feature_cnt=feature_cnt))
write.table(result, file='ndcg_result_w1_0813.tsv',sep='\t')

### WEEK2
topk618 = read.table("top10_20100618.tsv", sep="\t", quote='', header=T)
topk619 = read.table("top10_20100619.tsv", sep="\t", quote='', header=T)
topk620 = read.table("top10_20100620.tsv", sep="\t", quote='', header=T)
topk621 = read.table("top10_20100621.tsv", sep="\t", quote='', header=T)
topk622 = read.table("top10_20100622.tsv", sep="\t", quote='', header=T)
topk623 = read.table("top10_20100623.tsv", sep="\t", quote='', header=T)
topk624 = read.table("top10_20100624.tsv", sep="\t", quote='', header=T)
topk625 = read.table("top10_20100625.tsv", sep="\t", quote='', header=T)

result = data.frame()
thresholds = c(0.1,0.2,0.3,0.4,0.5) ; method = 'rf' ; feature_cnt = 50
result = rbind(result, rerank.queries(stbl2, '6_18_2010', topk618, topk619, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl1)) #
result = rbind(result, rerank.queries(stbl2, '6_19_2010', topk619, topk620, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl1)) #
result = rbind(result, rerank.queries(stbl2, '6_20_2010', topk620, topk621, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl1)) #
result = rbind(result, rerank.queries(stbl2, '6_21_2010', topk621, topk622, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl1)) #
result = rbind(result, rerank.queries(stbl2, '6_22_2010', topk622, topk623, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl1)) #
result = rbind(result, rerank.queries(stbl2, '6_23_2010', topk623, topk624, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl1)) #
result = rbind(result, rerank.queries(stbl2, '6_24_2010', topk624, topk625, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl1)) #
write.table(result, file='ndcg_result_w2_0813.tsv',sep='\t')


### WEEK3
topk625 = read.table("top10_20100625.tsv", sep="\t", quote='', header=T)
topk626 = read.table("top10_20100626.tsv", sep="\t", quote='', header=T)
topk627 = read.table("top10_20100627.tsv", sep="\t", quote='', header=T)
topk628 = read.table("top10_20100628.tsv", sep="\t", quote='', header=T)
topk629 = read.table("top10_20100629.tsv", sep="\t", quote='', header=T)
topk630 = read.table("top10_20100630.tsv", sep="\t", quote='', header=T)
topk701 = read.table("top10_20100701.tsv", sep="\t", quote='', header=T)
topk702 = read.table("top10_20100702.tsv", sep="\t", quote='', header=T)

result = data.frame()
thresholds = c(0.1,0.2,0.3,0.4,0.5) ; method = 'rf' ; feature_cnt = 50
result = rbind(result, rerank.queries(stbl3, '6_25_2010', topk625, topk626, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl2)) #
result = rbind(result, rerank.queries(stbl3, '6_26_2010', topk626, topk627, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl2)) #
result = rbind(result, rerank.queries(stbl3, '6_27_2010', topk627, topk628, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl2)) #
result = rbind(result, rerank.queries(stbl3, '6_28_2010', topk628, topk629, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl2)) #
result = rbind(result, rerank.queries(stbl3, '6_29_2010', topk629, topk630, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl2)) #
result = rbind(result, rerank.queries(stbl3, '6_30_2010', topk630, topk701, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl2)) #
result = rbind(result, rerank.queries(stbl3, '7_1_2010',  topk701, topk702, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl2)) #
write.table(result, file='ndcg_result_w3_0813.tsv',sep='\t')

### WEEK4
topk703 = read.table("top10_20100703.tsv", sep="\t", quote='', header=T)
topk704 = read.table("top10_20100704.tsv", sep="\t", quote='', header=T)
topk705 = read.table("top10_20100705.tsv", sep="\t", quote='', header=T)
topk706 = read.table("top10_20100706.tsv", sep="\t", quote='', header=T)
topk707 = read.table("top10_20100707.tsv", sep="\t", quote='', header=T)
topk708 = read.table("top10_20100708.tsv", sep="\t", quote='', header=T)
topk709 = read.table("top10_20100709.tsv", sep="\t", quote='', header=T)

result = data.frame()
thresholds = c(0.1,0.2,0.3,0.4,0.5) ; method = 'rf' ; feature_cnt = 50
result = rbind(result, rerank.queries(stbl4, '7_2_2010', topk702, topk703, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl3)) #
result = rbind(result, rerank.queries(stbl4, '7_3_2010', topk703, topk704, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl3)) #
result = rbind(result, rerank.queries(stbl4, '7_4_2010', topk704, topk705, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl3)) #
result = rbind(result, rerank.queries(stbl4, '7_5_2010', topk705, topk706, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl3)) #
result = rbind(result, rerank.queries(stbl4, '7_6_2010', topk706, topk707, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl3)) #
result = rbind(result, rerank.queries(stbl4, '7_7_2010', topk707, topk708, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl3)) #
result = rbind(result, rerank.queries(stbl4, '7_8_2010', topk708, topk709, thresholds=thresholds, method=method, feature_cnt=feature_cnt, train_stbl=stbl3)) #
write.table(result, file='ndcg_result_w4_0813.tsv',sep='\t')



####################
#    DEPRECATED    #

### 2-Day Interval
batch = 'train2'
cdocs = read.table(paste('result_cdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
docs_s   = cdocs[cdocs$Type == 'swapP' | cdocs$Type == 'swapU' | cdocs$Type == 'swapN',]   # Documents swapped
stblt2 = create.swap.table( docs_s, 'all', 'swapP' )


### TRAIN2 (2 day interval)
topk611 = read.table("top10_20100611.tsv", sep="\t", quote='', header=T)
topk613 = read.table("top10_20100613.tsv", sep="\t", quote='', header=T)
topk615 = read.table("top10_20100615.tsv", sep="\t", quote='', header=T)
topk617 = read.table("top10_20100617.tsv", sep="\t", quote='', header=T)

result = data.frame()
thresholds = c(0.1,0.2,0.3,0.4,0.5) ; method = 'rf' ; feature_cnt = 50
result = rbind(result, rerank.queries(stblt2, '6_11_2010', topk611, topk613)) #, train_set=stbl1
result = rbind(result, rerank.queries(stblt2, '6_13_2010', topk613, topk615)) #, train_set=stbl1
result = rbind(result, rerank.queries(stblt2, '6_15_2010', topk615, topk617)) #, train_set=stbl1
write.table(result, file='ndcg_result_t2_0805.tsv',sep='\t')

###################

analyze.table(stbl[stbl$Type=='swapP'|stbl$Type=='swapN',11:length(colnames(stbl))], feature_cnt = 500)
stbl1 = stbl[stbl$Date == '6_11_2010',]
#stbl[stbl$Type=='swapP',c(1:3,8:10, match('label',cs))][1:10,]

#debug(cross.val.queries)
#debug(train.and.test.queries)
result = cross.val.queries(stbl[c(1,11:length(colnames(stbl)))], feature_cnt = 250, output=T , method='rpart')
result_m = merge( stbl[,c(1:3)], result, by.x='SwapID', by.y='id')
pr.curve( data.frame( actual = (result_m$Type == 'swapP'), predict = result_m$yhat ))
#result_m[result_m$Type=='swapP',]

table(result_m$Type, cut(result_m$y,c(-0.4,-0.2,0,0.2,0.4)))
table(result_m$Type, cut(result_m$yhat,c(-0.4,-0.2,0,0.2,0.4)))

# Distribution of Dependent Variable
table(stbl$Type, cut(stbl$Label,c(-0.4,-0.2,0,0.2,0.4)))
