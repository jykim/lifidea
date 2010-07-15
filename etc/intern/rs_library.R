library(DAAG)

# Analyze the table of independent (1~n-1 column) and dependent (n column) variables.
# - Remove all row with NA value
# - correlation 
# - regression
# - classification
analyze.table <- function( tbl_a, run_id = 'analyze_table' )
{
	l_cols = length(colnames(tbl_a))
	tbl = na.omit( tbl_a )
	#print(c(nrow(tbl_a), nrow(tbl)))
	tbl.fit = lm( build.formula(tbl), data=tbl)
	write.table(
	t(rbind(cor(tbl)[1:(l_cols-1),l_cols], 
	tbl.fit$coefficients[2:l_cols])), sep=',', file=paste(run_id, 'csv', sep='.'))
	#summary_regression( tbl.fit )
	smry = summary.lm(tbl.fit)
	cv = cv.lm( tbl, build.formula(tbl), m=5, printit=F, plotit=F)
	list(tbl.fit$df, smry$r.squared, smry$sigma, sqrt(cv[['ss']])) 
}

analyze.table.rpart <- function( tbl_a, run_id = 'analyze_table' )
{
	#tbl = na.omit( tbl_a )
	#print(c(nrow(tbl_a), nrow(tbl)))
	#print(fmla)
	tbl.fit = rpart( build.formula(tbl_a), data=tbl_a, method='anova')
	calc.rmse( tbl.fit, tbl_a, tbl_a, last.col(tbl) )
}

cross.val.queries <- function(train, test = NULL, fold = 3)
{
	qids = sample( train[,1], nrow(train) )
	train_size = round( nrow(train) / fold )
	result = list()
	for( i in 1:fold )
	{
		idx_s = train_size * (i-1) + 1
		if( i < fold )
			idx_e = train_size * i
		else
			idx_e = nrow(train)
		#print( c(idx_s, idx_e) )
		result = rbind(result, train.and.test.queries(train, test, train_queries = qids[idx_s:idx_e]))
	}
	result #apply(result, 2, mean)
}

train.and.test.queries <- function(train, test = NULL, train_queries = NULL, train_ratio = 0.5)
{
	#if( colnames(train) != colnames(test) )
	#{
	#	print('[Error] Columns mismatch!!!')
	#	return()
	#}
	if( is.null(test) )
		test = train
	if( is.null(train_queries) )
		train_queries = sample( train[,1], round(nrow(train) * train_ratio));
	train_s = train[  train[,1] %in% train_queries, -c(1)]
	test_s  =  test[-(test[,1]  %in% train_queries),-c(1)]
	mdl = lm( build.formula(train_s), data=train_s)
	calc.rmse(mdl, train_s, test_s, last.col(train_s))
}

last.col <- function(tbl)
{
	cols = colnames(tbl)
	cols[length(cols)]
}

# Select a subset of aggregate table
sel.cols <- function( agg_m , add_id = FALSE)
{
	if( add_id )
		result = c(1)
	else
		result = c()
	result = append( result, c(3:10, 36:59) )
	list(k1 = agg_m[,append(result, c(11:12,16,18))], k3 = agg_m[,append(result, c(19:20,24,26))], k5 = agg_m[,append(result, c(27,28,32,34))])
}


build.formula <- function(tbl)
{
	cols = colnames(tbl)
	as.formula( paste( cols[length(cols)], '~', paste( cols[-length(cols)], collapse='+ ')))
}

calc.rmse <- function(mdl, train, test, yval) {
	train.yhat <- predict(object=mdl,newdata=train)
	test.yhat  <- predict(object=mdl,newdata=test)
	train.y    <- with(train,get(yval))
	test.y     <- with(test,get(yval))
	train.err  <- sqrt(mean((train.yhat - train.y)^2))
	test.err   <- sqrt(mean((test.yhat - test.y)^2))
	#plot(test.y, test.yhat)
	c(train.err=train.err, test.err=test.err)
}

# Check whether given row represents ranking-related change
non_rank_chg <- function(arg)
{
	if( arg['Rank'] == 1 & arg['Type'] == 'add' )
	{
		return(0);
	}
	else if( arg['Main'] == 1 & arg['SFresh'] == 0 & arg['QFresh'] == 0 )
	{
		return(0);
	}
	else
	{	
		return(1);
	}
}# Calculate the difference between items in a array

sub_all <- function(rows)
{
	result = c()
	for(i in (1:length(rows)))
	{
		if(i > 1)
		{
			result[i-1] = rows[i-1] -rows[i]
		}
	}
	return(result);
}

### DEPRECATED ONES

split.table <- function(tbl, train_ratio)
{
	tbl.training.indices <- sample(1:nrow(tbl), round(nrow(tbl) * train_ratio))
	tbl.testing.indices <-  setdiff(rownames(tbl),  tbl.training.indices)
	tbl.training <- tbl[tbl.training.indices,]
	tbl.testing <- tbl[tbl.testing.indices,]
	#save(tbl.training.indices, tbl.testing.indices, tbl, file="~/Documents/book/current/data/tbl.RData")
	c(train.set=tbl.training, test.set=tbl.testing)
}

sub_pair <- function(rows)
{
	#print(rows);
	return( rows[1] - rows[2]);
}

sub_pair_a <- function(rows)
{
	#print(rows);
	return( rows[3] - rows[4]);
}

format_date <- function(arg)
{
	format( as.Date(arg, format="%m/%d/%Y"), "%Y_%m_%d")
}

conv_to_date <- function(arg)
{
	format_date(unlist(strsplit(as.character(arg['Date']), " "))[1])
}

summary_regression <- function(model)
{
	smry = summary.lm(model)
	list(model$df, smry$r.squared, smry$sigma) 
}

# Return if any element of the row is false
any_na <- function(row)
{
	any(sapply(row, is.na))
}

filter_na_rows <- function(tbl_a)
{
	tbl_a[which(!apply(tbl_a, 1, any_na)),]
}
