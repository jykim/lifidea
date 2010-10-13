library(DAAG)
library(randomForest)
#library('e1071')
#library('earth')
#library('gam')
#library('ipred')
#library('nnet')
source("code/rs_library_analyze.R")
source("code/rs_library_predict.R")
source("code/rs_library_predict_swap.R")
source("code/rs_library_predict_stability.R")
setwd(".")

# Import data from Ruby output
# batch : ID of processing batch
import_data <- function(batch, anno = NULL, ichk = NULL, sfcounts = NULL, skip_sdoc = FALSE)
{
	print('Aggregate results')
	agg = read.table(paste('result_all_',batch,'.txt',sep=''),sep='\t',quote='',header=TRUE)

	print('Daily Results')
	daily = read.table(paste('result_daily_',batch,'.txt',sep=''),sep='\t',quote='',header=TRUE)

	print('Document-level Results')
	cdocs = read.table(paste('result_cdocs_',batch,'.txt.short',sep=''),sep='\t',quote='"',header=TRUE)
	docs_a   = cdocs[cdocs$Type == 'add' | cdocs$Type == 'del',]   # Documents added / deleted
	docs_s   = cdocs[cdocs$Type == 'swapP' | cdocs$Type == 'swapU' | cdocs$Type == 'swapN',]   # Documents swapped
	
	if( !is.null(ichk) | !is.null(sfcounts) ){
		if( is.null(sfcounts) )
			sfcounts = get.sfcounts(docs_a, ichk)
		agg = merge(agg, sfcounts, by="QID", all.x=TRUE)
	}
	
	if( !skip_sdoc ){
		sdocs = read.table(paste('result_sdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
		# Aggregate Stable Docs Result by Query
		a_sdocs = cbind( aggregate( sdocs$rRank , by=list(sdocs$QID), FUN = mean), aggregate( sdocs$rScore , by=list(sdocs$QID), FUN = mean))[,c(1,2,4)]
		colnames(a_sdocs) = c('QID', 'rRank','rScore')
	}
	else{
		a_sdocs = NULL
	}
	if( !is.null(anno) ){
		agg = merge(agg, anno, by.x='QID', by.y='QueryID')
		agg = merge(agg, a_sdocs, by='QID')
	}
	list(agg=agg, daily=daily, cdocs=cdocs, add=docs_a, swap=docs_s, sdocs=a_sdocs, sdocs_all=sdocs )#
}

get.sfcounts <- function(docs_a, ichk)
{
	m_docs = merge(docs_a, ichk[ichk$Main == 0 & ichk$SFresh == 1,], by="URL")
	sfcounts = aggregate( m_docs$SFresh, by=list(m_docs$QID), FUN = sum )
	colnames(sfcounts) = c('QID', 'sfresh')
	sfcounts
}


# Filter the query set by filter_table
# filter_table : data.table( Group.1 / Group.2 / x )
filter.queries.by <- function(batch, ichk = NULL)
{
	if( !is.null(ichk) ){
		m_docs  = merge(batch$add, ichk, by="URL")
		ichk_n = cbind(m_docs, nrc=apply( m_docs, 1, non_rank_chg))
		filter_table = aggregate(ichk_n$nrc , by=list(ichk_n$Date, ichk_n$QID), FUN = sum) 
	}
	else
		filter_table = aggregate( batch$add$QID , by=list(batch$add$Date, batch$add$QID), FUN = length) 
	daily_n	= batch$daily[,c('QID','Date','dNDCG1','dNDCG3','dNDCG5')] # filter only qid/date/ndcg_k
	daily_rn  = merge(daily_n, filter_table,  by.x=c('Date', 'QID'), by.y=c('Group.1', 'Group.2'), all.x=TRUE)
	daily_rn = daily_rn[-which(daily_rn$x > 0),]
	daily_rw1   = reshape(daily_rn, v.names='dNDCG1', idvar='QID', timevar='Date', direction='wide')
	daily_rw1$x = NULL
	agg_r = merge(batch$agg, filter_na_rows(daily_rw1), by.x='QID', by.y='QID')
}

# Create a projection of given table 
# - indices : indices to add
# 0 titles : column titles to add
project.table <- function(tbl, indices, titles)
{
	cbind( tbl[,indices], tbl[,sapply(titles, match, colnames(tbl))] )
}

# Check whether given row represents ranking-related change
non_rank_chg <- function(arg)
{
	if( arg['Rank'] == 1 & arg['Type'] == 'add' ){
		return(0);
	}
	if( arg['Main'] == 1 & arg['SFresh'] == 0 & arg['QFresh'] == 0 ){
		return(0);
	}
	else
	{	
		return(1);
	}
}

# Calculate the difference between items in a array
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

LOG <- function(fmt, ...)
{
	print(sprintf(fmt, ...))
}

setgbl <- function(varname, varvalue)
{
	if( exists( varname, envir = .GlobalEnv ) )
		assign(varname, varvalue, envir = .GlobalEnv)
	else
		eval(varname <- varvalue, envir = .GlobalEnv)
}

sample.tbl <- function(tbl, size)
{
	rows = sample( nrow(tbl), size);
	tbl[rows, ]
}


#######################
#   DEPRECATED        #


analyze.table.rpart <- function( tbl_a, run_id = 'analyze_table' )
{
	#tbl = na.omit( tbl_a )
	#print(c(nrow(tbl_a), nrow(tbl)))
	#print(fmla)
	tbl.fit = rpart( build.formula(tbl_a), data=tbl_a, method='anova')
	predict.and.calc.rmse( tbl.fit, tbl_a, tbl_a, last.col(tbl) )
}

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

#format_date <- function(arg)
#{
#	format( as.Date(arg, format="%m/%d/%Y"), "%Y_%m_%d")
#}

format_date <- function(arg)
{
	as.Date(as.character(arg), format="%m_%d_%Y")
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
