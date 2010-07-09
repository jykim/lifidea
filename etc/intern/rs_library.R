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

# Analyze the table of independent (1~n-1 column) and dependent (n column) variables.
# - Remove all row with NA value
# - correlation 
# - regression
# - classification
analyze.table <- function( tbl_a, run_id = 'analyze_table' )
{
	tbl = filter_na_rows( tbl_a )
	#print(c(nrow(tbl_a), nrow(tbl)))
	cols = colnames(tbl)
	fmla = as.formula( paste( cols[length(cols)], '~', paste( cols[-length(cols)], collapse='+ ')))
	#print(fmla)
	tbl.fit = lm( fmla, data=tbl)
	write.table(
	t(rbind(cor(tbl)[1:(length(cols)-1),length(cols)], 
	tbl.fit$coefficients[2:length(cols)])), sep=',', file=paste(run_id, 'csv', sep='.'))
	#summary_regression( tbl.fit )
	smry = summary.lm(tbl.fit)
	cv = cv.lm( tbl, fmla, m=5, printit=F, plotit=F)
	list(tbl.fit$df, smry$r.squared, smry$sigma, sqrt(cv[['ss']])) 
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

