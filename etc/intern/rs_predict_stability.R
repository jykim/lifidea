# Aggregate Results
setwd("c:/data")
anno = read.table('annotationsB06_July.csv', sep=',',quote='',header=TRUE) # Query annotations
ichk = read.table('docs_ichk_all.txt.result',sep='\t',quote='',header=TRUE) # Index check results
source("c:/dev/lifidea/etc/intern/rs_library.R")

# Load Data
train = import_data('train', anno)
test  = import_data('test', anno)

### Load Filtering Conditions

# Using docs in Main Index
train_f = filter.queries.by( train, ichk = ichk )
test_f  = filter.queries.by( test,  ichk = ichk )

# Using only Swaps
train_f2 = filter.queries.by( train )
test_f2 = filter.queries.by( test )

################################
#     Check Model Fitness      #

sapply( select.cols(train$agg), analyze.table) # all records
sapply( select.cols(test$agg),  analyze.table) # all records

sapply( select.cols(train$agg), train.and.test.queries) # all records
sapply( select.cols(test$agg),  train.and.test.queries) # all records

sapply( select.cols(train$agg, add_id=TRUE), cross.val.queries, fold=2) # all records
sapply( select.cols(test$agg, add_id=TRUE),  cross.val.queries, fold=2) # all records

######################################
#     Predicting Aggregate Change    #

sapply( select.cols(train$agg, add_id=TRUE), cross.val.queries, test=test$agg, fold=2) # all records
sapply( select.cols(train$agg, add_id=TRUE), cross.val.queries, test=test$agg, fold=2, method='rpart') # all records

# Changing Feature Set
test.feature_set('lm', train$agg, test$agg)
test.feature_set('rpart', train$agg, test$agg)
test.feature_set('lm', train_f, test_f)
test.feature_set('rpart', train_f, test_f)
test.feature_set('lm', train_f2, test_f2)
test.feature_set('rpart', train_f2, test_f2)

test.feature_set <- function( method, train_set,test_set, debug_flag = FALSE )
{
	print(sapply( select.cols(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = FALSE, ft_ndcg = FALSE, ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag))
	print(sapply( select.cols(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = FALSE, ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.cols(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = TRUE,  ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.cols(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = TRUE,  ft_qry = TRUE,  ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.cols(train_set, add_id=TRUE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
}

# Applying Feature Selection
for(feature_cnt in c(10,25,50,100))
	print(sapply( select.cols(train_set, add_id=TRUE), cross.val.queries, test=test_set, method=method, debug=debug_flag, feature_cnt=feature_cnt ))


##################################
#     Predicting Daily Change    #

test_m = merge(test$daily, test$agg, by='QID', suffixes=c('','.a')) # Merge daily data with aggregate data

# Within-period Cross-validation
for(date_test in sort(unique(test_m$Date))[2:length(sort(unique(test_m$Date)))])
	print(sapply( list( test_m[test_m$Date == date_test,c(63:86,13,14,16,22,25:27,45)], test_m[test_m$Date == date_test,c(63:86,13,14,16,22,25:27,53)], 
		test_m[test_m$Date == date_test,c(63:86,13,14,16,22,25:27,61)]), cross.val.queries))

#cross.val.queries( test_m[test_m$Date == '6_26_2010',c(63:86,61)] )
#sapply( select.cols(train$agg, add_id=TRUE), cross.val.queries, test=test_m[test_m$Date == '6_26_2010',])
#train.and.test.queries( select.cols(train$agg, add_id=TRUE)$k5, test=test_m[test_m$Date == '6_26_2010',], debug=TRUE )
#train.and.test.queries( select.cols(train$agg, add_id=TRUE)$k5, debug=TRUE )

for(date_test in sort(unique(test_m$Date))[2:length(sort(unique(test_m$Date)))])
	print(sapply( select.cols(train$agg, add_id=TRUE), cross.val.queries, test=test_m[test_m$Date == date_test,]))

#for(date_test in sort(unique(test_m$Date))[2:length(sort(unique(test_m$Date)))])
#	print(sapply( select.cols(train$agg, add_id=TRUE), cross.val.queries, test=test_m[test_m$Date == date_test,], method='rpart'))


############################
#     Using Weekly Data    #

w1 = import_data('w1', anno)
w2 = import_data('w2', anno)
w3 = import_data('w3', anno)
w4 = import_data('w4', anno)

rbind(
sapply( select.cols(w1$agg, add_id=TRUE), cross.val.queries, fold=2), # all records
sapply( select.cols(w2$agg, add_id=TRUE), cross.val.queries, fold=2), # all records
sapply( select.cols(w3$agg, add_id=TRUE), cross.val.queries, fold=2), # all records
sapply( select.cols(w4$agg, add_id=TRUE), cross.val.queries, fold=2)) # all records

rbind(
cross.val.queries( select.cols(w1$agg, add_id=TRUE)$k1 , select.cols(w2$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.cols(w1$agg, add_id=TRUE)$k1 , select.cols(w3$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.cols(w1$agg, add_id=TRUE)$k1 , select.cols(w4$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.cols(w2$agg, add_id=TRUE)$k1 , select.cols(w3$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.cols(w2$agg, add_id=TRUE)$k1 , select.cols(w4$agg, add_id=TRUE)$k1 ),
cross.val.queries( select.cols(w3$agg, add_id=TRUE)$k1 , select.cols(w4$agg, add_id=TRUE)$k1 ))

######## DEPRECATED


#cross.val.queries( select.cols(train$agg, add_id=TRUE)$k1 , select.cols(test$agg, add_id=TRUE)$k1 )
#cross.val.queries( select.cols(train$agg, add_id=TRUE)$k3 , select.cols(test$agg, add_id=TRUE)$k3 )
#cross.val.queries( select.cols(train$agg, add_id=TRUE)$k5 , select.cols(test$agg, add_id=TRUE)$k5 )

# Correlation between train vs. test stability
agg_m = merge( train$agg[,c(1,7,18,26,34)], test$agg[,c(1,7,18,26,34)], by='QID' )
cor(agg_m)
calc.rmse(agg_m$rNDCG1.x, agg_m$rNDCG1.y)
calc.rmse(agg_m$rNDCG3.x, agg_m$rNDCG3.y)
calc.rmse(agg_m$rNDCG5.x, agg_m$rNDCG5.y)
calc.rmse(agg_m$Tau5.x, agg_m$Tau5.y)

