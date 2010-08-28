# Aggregate Results
anno = read.table('annotationsB06_July.csv', sep=',',quote='',header=TRUE) # Query annotations
ichk = read.table('docs_ichk_all.txt.result',sep='\t',quote='',header=TRUE) # Index check results
source("c:/dev/lifidea/etc/intern/rs_library.R")

# Load Data
train  = import_data('train', anno, ichk)
sfcounts_train = get.sfcounts(train$add, ichk)
test  = import_data('test', anno, sfcounts = sfcounts_train)

### Load Filtering Conditions

# Using docs in Main Index
train_f = filter.queries.by( train, ichk = ichk )
test_f  = filter.queries.by( test,  ichk = ichk )

# Using only Swaps
train_f2 = filter.queries.by( train )
test_f2 = filter.queries.by( test )

################################
#     Check Model Fitness      #
#label_set = data.frame(id = train$agg , label = (stbl$Type == 'swapP') )

sapply( select.ftypes(train$agg), analyze.table) # all records
sapply( select.ftypes(test$agg),  analyze.table) # all records

sapply( select.ftypes(train$agg), train.and.test.queries) # all records
sapply( select.ftypes(test$agg),  train.and.test.queries) # all records

sapply( select.ftypes(train$agg, add_id=TRUE), cross.val.queries, fold=2) # all records
sapply( select.ftypes(test$agg, add_id=TRUE),  cross.val.queries, fold=2) # all records

analyze.table( select.ftypes(test$agg, ft_ndcg = F, ft_qurl = F, add_id=F)$k5, run_id='agg' )

######################################
#     Predicting Aggregate Change    #

# Final - all but ndcg fetures ([is.na(train$agg$sfresh),])
sapply( select.ftypes(train$agg, ft_ndcg = F, ft_qurl = F, add_id=TRUE), cross.val.queries, test=test$agg, fold=2) # all records
#sapply( select.ftypes(train$agg, ft_ndcg = F, ft_qurl = T, add_id=TRUE), cross.val.queries, test=test$agg, feature_cnt=100, fold=2) # all records
sapply( select.ftypes(train$agg, ft_ndcg = F, ft_qurl = F, add_id=TRUE), cross.val.queries, test=test$agg, method='rf', fold=2) # all records


# Changing Feature Set
test.feature_set('lm', train$agg, test$agg)
test.feature_set('rpart', train$agg, test$agg)
test.feature_set('rf', train$agg, test$agg)
test.feature_set('lm', train_f, test_f)
test.feature_set('rpart', train_f, test_f)
test.feature_set('rf', train_f, test_f)
test.feature_set('lm', train_f2, test_f2)
test.feature_set('rpart', train_f2, test_f2)
test.feature_set('rf', train_f2, test_f2)

# Applying Feature Selection
for(feature_cnt in c(10,25,50,100))
	print(sapply( select.ftypes(train_set, add_id = TRUE, ft_qurl = TRUE), cross.val.queries, test=test_set, method=method, debug=debug_flag, feature_cnt=feature_cnt ))


##################################
#     Predicting Daily Change    #


#for(date_test in date_tests)
#	print(sapply( select.ftypes.daily(test$daily, date_test), cross.val.queries))

date_tests = sort(unique(test$daily$Date))[2:length(sort(unique(test$daily$Date)))]
test$daily$dNDCG5 = abs(test$daily$dNDCG5)
train$daily$dNDCG5 = abs(train$daily$dNDCG5)
train_daily = merge(train$daily, train$agg[,c(1,18,26,34,484:508)], by=c('QID'))
test_daily  = merge(test$daily, test$agg[,c(1,18,26,34,484:508)], by=c('QID'))
result = list()
for(date_test in date_tests){
	train_set = select.ftypes.daily(train_daily[is.na(train_daily$sfresh),], date_test, ft_2day = T,  exclude=T)$k5
	test_set  = select.ftypes.daily(test_daily[is.na(test_daily$sfresh),], date_test)$k5
	result_cur = cross.val.queries(train_set, test_set, method='lm' , feature_cnt=NULL )
	result_cur$Date = date_test
	result = rbind(result, result_cur)
}

# Debugging
date_test = '6_26_2010'
output = cross.val.queries(select.ftypes.daily(train_daily, date_test, exclude=T)$k5,  select.ftypes.daily(test_daily, date_test)$k5, feature_cnt=NULL, debug=T, output=T )
analyze.table(select.ftypes.daily(test_daily, date_test, add_id=F)$k5, run_id='daily')

# Within-period Cross-validation
#test_m = merge(test$daily, test$agg, by='QID', suffixes=c('','.a')) # Merge daily data with aggregate data
#for(date_test in sort(unique(test_m$Date))[2:length(sort(unique(test_m$Dat	e)))])
#	print(sapply( list( test_m[test_m$Date == date_test,c(63:86,13,14,16,22,25:27,45)], test_m[test_m$Date == date_test,c(63:86,13,14,16,22,25:27,53)], 
#		test_m[test_m$Date == date_test,c(63:86,13,14,16,22,25:27,61)]), cross.val.queries))
#
#cross.val.queries( test_m[test_m$Date == '6_26_2010',c(63:86,61)] )
#sapply( select.ftypes(train$agg, add_id=TRUE), cross.val.queries, test=test_m[test_m$Date == '6_26_2010',])
#train.and.test.queries( select.ftypes(train$agg, add_id=TRUE)$k5, test=test_m[test_m$Date == '6_26_2010',], debug=TRUE )
#train.and.test.queries( select.ftypes(train$agg, add_id=TRUE)$k5, debug=TRUE )

#for(date_test in sort(unique(test_m$Date))[2:length(sort(unique(test_m$Date)))])
#	print(sapply( select.ftypes(train$agg, add_id=TRUE), cross.val.queries, test=test_m[test_m$Date == date_test,]))

#for(date_test in sort(unique(test_m$Date))[2:length(sort(unique(test_m$Date)))])
#	print(sapply( select.ftypes(train$agg, add_id=TRUE), cross.val.queries, test=test_m[test_m$Date == date_test,], method='rpart'))


############################
#     Using Weekly Data    #

w1 = import_data('w1', anno)
w2 = import_data('w2', anno)
w3 = import_data('w3', anno)
w4 = import_data('w4', anno)

rbind(
sapply( select.ftypes(w1$agg, add_id=TRUE), cross.val.queries, fold=2), # all records
sapply( select.ftypes(w2$agg, add_id=TRUE), cross.val.queries, fold=2), # all records
sapply( select.ftypes(w3$agg, add_id=TRUE), cross.val.queries, fold=2), # all records
sapply( select.ftypes(w4$agg, add_id=TRUE), cross.val.queries, fold=2)) # all records

rbind(
cross.val.queries( select.ftypes(w1$agg, add_id=TRUE)$k1 , select.ftypes(w2$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.ftypes(w1$agg, add_id=TRUE)$k1 , select.ftypes(w3$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.ftypes(w1$agg, add_id=TRUE)$k1 , select.ftypes(w4$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.ftypes(w2$agg, add_id=TRUE)$k1 , select.ftypes(w3$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.ftypes(w2$agg, add_id=TRUE)$k1 , select.ftypes(w4$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.ftypes(w3$agg, add_id=TRUE)$k1 , select.ftypes(w4$agg, add_id=TRUE)$k1 ))

######## DEPRECATED


#cross.val.queries( select.ftypes(train$agg, add_id=TRUE)$k1 , select.ftypes(test$agg, add_id=TRUE)$k1 )
#cross.val.queries( select.ftypes(train$agg, add_id=TRUE)$k3 , select.ftypes(test$agg, add_id=TRUE)$k3 )
#cross.val.queries( select.ftypes(train$agg, add_id=TRUE)$k5 , select.ftypes(test$agg, add_id=TRUE)$k5 )

# Correlation between train vs. test stability
agg_m = merge( train$agg[,c(1,7,18,26,34)], test$agg[,c(1,7,18,26,34)], by='QID' )
cor(agg_m)
calc.rmse(agg_m$rNDCG1.x, agg_m$rNDCG1.y)
calc.rmse(agg_m$rNDCG3.x, agg_m$rNDCG3.y)
calc.rmse(agg_m$rNDCG5.x, agg_m$rNDCG5.y)
calc.rmse(agg_m$Tau5.x, agg_m$Tau5.y)

