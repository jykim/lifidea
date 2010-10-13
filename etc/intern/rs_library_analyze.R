
# Daily Distribution of Addition vs. Swap
daily.cdocs <- function( docs )
{
	aggregate( docs$QID , by=list(docs$Type), FUN = length)
	result = aggregate( docs$QID , by=list(docs$Date, docs$Type), FUN = length)
	reshape(result, v.names='x', idvar='Group.1', timevar='Group.2',direction='wide')
}

# Analyze the instability of feature values
analyze.feature <- function( fname, sdocs )
  {
    values = with(sdocs,get(fname))
    list( mean = mean(values), max = max(values), pzero = length(values[values == 0])/length(values) )
  }


# Aggregate statistics of daily change
daily.change <- function( arg_daily )
{
	daily = arg_daily[arg_daily$Date != sort(unique(arg_daily$Date))[1],]   # Queries with change in rank list
	daily_chg = daily[daily$Tau5 != 1.0,]   # Queries with change in Top5 rank list
	#daily_imp1 = daily[daily$dNDCG1 > 0,] # Queries with change in perf. (+)
	#daily_deg1 = daily[daily$dNDCG1 < 0,] # Queries with change in perf. (-)
	daily_imp3 = daily[daily$dNDCG3 > 0,] # Queries with change in perf. (+)
	daily_deg3 = daily[daily$dNDCG3 < 0,] # Queries with change in perf. (-)
	daily_imp5 = daily[daily$dNDCG5 > 0,] # Queries with change in perf. (+)
	daily_deg5 = daily[daily$dNDCG5 < 0,] # Queries with change in perf. (-)
	daily_cchg = daily[daily$cTau != 1.0,]   # Queries with change in Top5 rank list
	#daily_cimp1 = daily[daily$cNDCG1 > 0,] # Queries with change in perf. (+)
	#daily_cdeg1 = daily[daily$cNDCG1 < 0,] # Queries with change in perf. (-)
	daily_cimp3 = daily[daily$cNDCG3 > 0,] # Queries with change in perf. (+)
	daily_cdeg3 = daily[daily$cNDCG3 < 0,] # Queries with change in perf. (-)
	daily_cimp5 = daily[daily$cNDCG5 > 0,] # Queries with change in perf. (+)
	daily_cdeg5 = daily[daily$cNDCG5 < 0,] # Queries with change in perf. (-)

	# Create the table of daily aggregate statistics
	result = cbind( 
	aggregate( daily$QID , by=list(daily$Date), FUN = length), 
	aggregate( daily_chg$QID , by=list(daily_chg$Date), FUN = length),
	#aggregate( daily_imp1$QID , by=list(daily_imp1$Date), FUN = length),
	#aggregate( daily_deg1$QID , by=list(daily_deg1$Date), FUN = length),
	aggregate( daily_imp3$QID , by=list(daily_imp3$Date), FUN = length),
	aggregate( daily_deg3$QID , by=list(daily_deg3$Date), FUN = length),
	aggregate( daily_imp5$QID , by=list(daily_imp5$Date), FUN = length),
	aggregate( daily_deg5$QID , by=list(daily_deg5$Date), FUN = length),
	aggregate( daily_cchg$QID , by=list(daily_cchg$Date), FUN = length),
	#aggregate( daily_cimp1$QID , by=list(daily_cimp1$Date), FUN = length),
	#aggregate( daily_cdeg1$QID , by=list(daily_cdeg1$Date), FUN = length),
	aggregate( daily_cimp3$QID , by=list(daily_cimp3$Date), FUN = length),
	aggregate( daily_cdeg3$QID , by=list(daily_cdeg3$Date), FUN = length),
	aggregate( daily_cimp5$QID , by=list(daily_cimp5$Date), FUN = length),
	aggregate( daily_cdeg5$QID , by=list(daily_cdeg5$Date), FUN = length)
	)[,c(1,2,4, 6,8,10,12,14,16, 18,20,22)]
	
	colnames(result) = c('Date','QID','imp3','deg3','imp5','deg5','chg5','cchg','cimp3','cdeg3','cimp5','cdeg5')
	result
}

# Analyze the table of independent (1~n-1 column) and dependent (n column) variables.
# - Remove all row with NA value
# - correlation 
# - regression
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
	list(tbl.fit$df, smry$r.squared, smry$sigma) 
}

# Get wide version of swap table
get.wide.swap.table <- function( docs_s )
{
	merge(
		merge( docs_s[seq(1,nrow(docs_s),by=4),], docs_s[seq(2,nrow(docs_s),by=4),], by=c('Date','QID','Type','CDID')),
		merge( docs_s[seq(3,nrow(docs_s),by=4),], docs_s[seq(4,nrow(docs_s),by=4),], by=c('Date','QID','Type','CDID')), 
		by=c('QID','Type','CDID','URL.x','URL.y','HRS.x','HRS.y'), suffixes = c("b","a"))
}


# Lifetime analysis for addition
lifetime.add <- function( cdocs, argdate )
{
	result = c()
	dates = sort(unique(cdocs$Date))
	del_pairs = c()
	LOG("%s %d", argdate, nrow(cdocs[(cdocs$Date == argdate & cdocs$Type == 'add'),]))
	for(curdate in dates)
	{
		if( curdate <= argdate )
			next
		curdocs = cdocs[(cdocs$Date == argdate & cdocs$Type == 'add') | (cdocs$Date == curdate & cdocs$Type == 'del'),]
		curpairs = aggregate( curdocs$QID , by=list(curdocs$QID, curdocs$URL), FUN = length)
		curpairs = curpairs[ curpairs$x > 1 & !(paste(curpairs$Group.1, curpairs$Group.2) %in% del_pairs), ]
		del_pairs = union( del_pairs, paste(curpairs$Group.1, curpairs$Group.2)  )
		LOG("%s %d", curdate, nrow(curpairs))
	}
}

# Lifetime analysis for deletion
lifetime.del <- function( cdocs, argdate )
{
	result = c()
	dates = sort(unique(cdocs$Date))
	del_pairs = c()
	LOG("%s %d", argdate, nrow(cdocs[(cdocs$Date == argdate & cdocs$Type == 'del'),]))
	for(curdate in dates)
	{
		if( curdate <= argdate )
			next
		curdocs = cdocs[(cdocs$Date == argdate & cdocs$Type == 'del') | (cdocs$Date == curdate & cdocs$Type == 'add'),]
		curpairs = aggregate( curdocs$QID , by=list(curdocs$QID, curdocs$URL), FUN = length)
		curpairs = curpairs[ curpairs$x > 1 & !(paste(curpairs$Group.1, curpairs$Group.2) %in% del_pairs), ]
		del_pairs = union( del_pairs, paste(curpairs$Group.1, curpairs$Group.2)  )
		LOG("%s %d", curdate, nrow(curpairs))
	}
}

# Lifetime analysis for swaps
lifetime.swap <- function( stbl, cdocs, argdate )
{
	result = c()
	dates = sort(unique(stbl$Datea))
	del_pairs = c()
	stbl$URLs = apply( stbl, 1, concat.URLs )
	LOG("%s %d", argdate, nrow(stbl[(stbl$Datea == argdate),]))
	for(curdate in dates)
	{
		if( curdate <= argdate )
			next
		curswaps = stbl[(stbl$Datea == argdate) | (stbl$Datea == curdate ),]
		curpairs = aggregate( curswaps$QID , by=list(curswaps$QID, curswaps$URLs), FUN = length)
		curpairs = curpairs[ curpairs$x > 1 & !(paste(curpairs$Group.1, curpairs$Group.2) %in% del_pairs), ]

		curdeldocs = paste( cdocs[(cdocs$Date == curdate & cdocs$Type == 'del'),]$QID, cdocs[(cdocs$Date == curdate & cdocs$Type == 'del'),]$URL )
		curdelswaps = stbl[stbl$Datea == argdate & ((paste(stbl$QID,stbl$URL.x) %in% curdeldocs) | (paste(stbl$QID,stbl$URL.y) %in% curdeldocs)) & !(paste(stbl$QID, stbl$URLs) %in% del_pairs),]

		del_pairs = union( del_pairs, paste(curpairs$Group.1, curpairs$Group.2)  )
		del_pairs = union( del_pairs, paste(curdelswaps$QID, curdelswaps$URLs)  )
		LOG("%s %d %d", curdate, nrow(curpairs), nrow(curdelswaps))
	}
}

concat.URLs <- function( swap )
{
	if( swap['URL.x'] > swap['URL.y'] )
		paste( swap['URL.x'] , swap['URL.y'] )
	else
		paste( swap['URL.y'] , swap['URL.x'] )
}
