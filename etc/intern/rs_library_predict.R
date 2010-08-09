
# Analyze the table of independent (1~n-1 column) and dependent (n column) variables.
# - Remove all row with NA value
# - correlation 
# - regression
# - classification
analyze.table <- function( tbl_a, run_id = 'def', feature_cnt = 100 )
{
	tbl = na.omit( tbl_a )
	tbl = select.features( tbl, feature_cnt )
	l_cols = length(colnames(tbl))
	#print(c(nrow(tbl_a), nrow(tbl)))
	tbl.fit = lm( build.formula(tbl), data=tbl)
	write.table(
		t(rbind(cor(tbl)[1:(l_cols-1),l_cols], 
		tbl.fit$coefficients[2:l_cols])), sep=',', file=paste('analyze_table', run_id, 'csv', sep='.'))
	#summary_regression( tbl.fit )
	smry = summary.lm(tbl.fit)
	#cv = cv.lm( tbl, build.formula(tbl), m=5, printit=F, plotit=F)
	list(tbl.fit$df, smry$r.squared, smry$sigma) #, sqrt(cv[['ss']])
}

cross.val.queries <- function(train, test = NULL, fold = 3, feature_cnt = NULL, label_set = NULL, method = 'lm', plottype = 'png' , debug = FALSE, output = FALSE)
{
	LOG("Running %s with %d features...", method, feature_cnt)
	if( is.null(test) ) test = train
	qids = sample( test[,1], nrow(test) )
	test_size = round( nrow(test) / fold )
	train.err = c()
	test.err = c()
	test.prec = c()
	test.recall = c()
	result_output = data.frame()
	
	for( i in 1:fold )
	{
		idx_s = test_size * (i-1) + 1
		if( i < fold )
			idx_e = test_size * i
		else
			idx_e = nrow(test)
		#print( c(idx_s, idx_e) )
		if( !is.null( feature_cnt ) )
			train = select.features( train, feature_cnt, add_id = TRUE )
		result_cur = train.and.test.queries(train, test, test_queries = qids[idx_s:idx_e], method = method, debug=debug)
		#print(result_cur)
		train.err = append( train.err, result_cur[['train.err']])
		test.err  = append( test.err,  result_cur[['test.err']])
		test.prec = append( test.prec,  result_cur[['test.prec']])
		test.recall = append( test.recall,  result_cur[['test.recall']])
		result_output = rbind( result_output, data.frame(id = result_cur[['ids']], y = result_cur[['y']] , yhat = result_cur[['yhat']]) )
		#result_output =  data.frame(id = result_cur[['ids']], y = result_cur[['y']] , yhat = result_cur[['yhat']])
	}
	if( !(method %in% c('svm','rf')) && !is.null(label_set) ){
		result_m = merge( label_set, result_output, by='id')
		pr.curve( data.frame( actual = result_m$label, predict = result_m$yhat ), plottype = plottype, run_id = paste(feature_cnt, method, sep='_') )
	}
	if( output )
		result_output
	else{
		result = list(train.err=train.err, test.err=test.err, test.prec=test.prec, test.recall=test.recall)
		result_avg = lapply(result, mean)
		result_avg['method'] = method ; result_avg['feature_cnt'] = feature_cnt ; result_avg['train_cnt'] = nrow(train)
		result_avg
	}
}

pr.curve <- function(arg, run_id = "" ,plottype = NULL)
{
	arg = arg[order(arg$predict, decreasing = T),]
	count_total = nrow( arg[arg$actual == TRUE,])
	count_cur = 0
	prec = c()
	recall = c()
	f1 = c()
	for(i in (1:nrow(arg)))
	{
		if( arg$actual[i] == TRUE )
			count_cur = count_cur + 1
		prec_cur = count_cur / i ; recall_cur = count_cur / count_total
		prec   = append( prec,  prec_cur  )
		recall = append( recall, recall_cur )
		f1	   = append( f1, 2 * prec_cur * recall_cur / (prec_cur + recall_cur) )
		#print(sprintf("%f / %f", prec, recall))
	}
	if( plottype == 'png' )
		png(paste('plots/prcurve', run_id, 'png', sep='.'), width = 600, height = 600)
	plot( recall, prec, xlim=c(0,1), ylim=c(0,1) )
	lines( recall, f1, lty=1 )
	if( !is.null(plottype) )
		dev.off()
	arg
}

train.and.test.queries <- function(train, test = NULL, test_queries = NULL, test_ratio = 0.5, method = 'lm', debug = FALSE)
{
	if( is.null(test) )
		test = train
	if( is.null(test_queries) )
		test_queries = sample( train[,1], round(nrow(train) * test_ratio));
	#print( test_queries )
	train_s = train[ !(train[,1] %in% test_queries), -c(1)]
	test_s  =  test[ test[,1] %in% test_queries,     -c(1)]
	if( method == 'lm' )
		mdl = lm( build.formula(train_s), data=train_s)
	else if( method == 'glm' )
		mdl = glm( build.formula(train_s), family=binomial(link="logit"), data=train_s)
	else if( method == 'rpart' )
		mdl = rpart( build.formula(train_s), data=train_s, method='anova')
	else if( method == 'rf' )
	{
		train_s2 = train_s
		train_s2$Label = as.factor(train_s[,'Label'])
		mdl = randomForest( build.formula(train_s), data=train_s2)
	}
	else if( method == 'gam' )
		mdl = gam( build.formula(train_s), data=train_s)
	predict.and.calc.rmse(method, mdl, train_s, test_s, last.col(train_s), ids=test[ test[,1] %in% test_queries,1], debug=debug)
}

predict.and.calc.rmse <- function(method, mdl, train, test, yval, topk = NULL, ids = NULL , debug=FALSE) 
{
	if( method %in% c('rf', 'svm') )
		ptype = 'class'
	else
		ptype = 'response'
	train.yhat <- predict(object=mdl, newdata=train, type=ptype)
	test.yhat  <- predict(object=mdl, newdata=test, type=ptype)
	train.y    <- with(train,get(yval))
	test.y     <- with(test,get(yval))
	train.err  <- calc.rmse(train.yhat, train.y)
	test.err   <- calc.rmse(test.yhat, test.y)
	if( is.null( topk ) )
		topk = length( test.yhat ) * 0.1
	if( method == 'lm' & ptype == 'response'){
		ti1 = topk.indices(test.yhat, topk) ; ti2 = topk.indices(test.y, topk)
		test_prec = (sqrt(length(intersect(ti1, ti2))^2 / (length(ti1) * length(ti2)) ))
	}
	else if( method == 'glm'){
		test_prec = length(which( test.y == 0 & test.yhat < 0.5)) / length(which(test.yhat < 0.5))
		test_recall   = length(which( test.y == 0 & test.yhat < 0.5)) / length(which(test.y == 0))
	}
	else {
		print( table( actual=test.y, predicted=test.yhat ) )
		test_prec = length(which( test.y == 0 & test.yhat == 0)) / length(which(test.yhat == 0))
		test_recall  = length(which( test.y == 0 & test.yhat == 0)) / length(which(test.y == 0))
	}
	if(debug == TRUE){
		plot(test.y, test.yhat)
		write.table(list(test.y, test.yhat), file = 'output_predicted_actual.txt')
		print(colnames(train))
		print(sprintf("features : %d / train_set : %d / test_set : %d",length(colnames(train)), nrow(train), nrow(test)))
		print(sprintf("yhat : %d / y : %d / overlap : %d ",length(ti1), length(ti2), length(intersect(ti1, ti2))))
	}
	if( length(ids) != length(test.yhat) ) {print('ERROR!!! length(ids) != length(yhat)') ; exit()}
	list(features=length(colnames(train)), rows=nrow(test) , y=test.y, yhat=test.yhat, ids=ids, 
	  train.err=train.err, test.err=test.err, test.prec=test_prec, test.recall=test_recall)
}


# Select TopK features based on the correlation w/ the dependent variable
select.features <- function( tbl, feature_cnt = 100, add_id = FALSE )
{
	l_cols = length(colnames(tbl))
	if( add_id ){
		result = topk.indices( abs(cor(tbl[,c(2,2:l_cols)])[,l_cols]), feature_cnt)
		tbl[, union(c(1),result) ]
	}
	else{
		result = topk.indices( abs(cor(tbl)[,l_cols]), feature_cnt)
		tbl[, result ]
	}
}

# Select a subset of aggregate table
select.cols <- function( agg_m , add_id = FALSE, ft_rank = TRUE, ft_score = TRUE, ft_ndcg = TRUE, ft_qry = TRUE, ft_qurl = TRUE)
{
	if( add_id )
		result = c(1)
	else
		result = c()
	if( ft_rank ) result = append( result, c(3:10, 508 ) )
	if( ft_score) result = append( result, c(11:12,509,19:20,27,28) )
	if( ft_ndcg ) result = append( result, c(16,24,32) )
	if( ft_qry  ) result = append( result, c(484:507 ) )
	if( ft_qurl ) result = append( result, c(35:482) )
	list(k1 = agg_m[,append(result, c(18))], k3 = agg_m[,append(result, c(26))], k5 = agg_m[,append(result, c(34))])
}

last.col <- function(tbl)
{
	cols = colnames(tbl)
	cols[length(cols)]
}

# Get the indices of TopK elements
topk.indices <- function( arg, k )
{
	if( length(arg) <= k )
		return( 1:length(arg) )
	threshold = sort(arg, dec=T)[k]
	#print(threshold)
	result = c()
	j = 1
	for(i in (1:length(arg)))
	{
		#print(arg[i])
		if(!is.na(arg[i]) && arg[i] >= threshold){
			result[j] = i;
			j =  j + 1;
		}
	}
	result
}

build.formula <- function(tbl)
{
	cols = colnames(tbl)
	as.formula( paste( cols[length(cols)], '~', paste( cols[-length(cols)], collapse='+ ')))
}

calc.rmse <- function(x, xhat)
{
	sqrt(mean((x - xhat)^2))
}