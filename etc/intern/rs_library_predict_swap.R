source("c:/dev/lifidea/etc/intern/rs_library.R")
source("c:/dev/lifidea/etc/intern/rs_library_predict.R")

# Create a table of features for prediction
create.swaptbl <- function( docs_s, features = 'all', depvar = 'dcgdiff' )
{
	# Create a Wider Table (one row per swap)
	dsw = merge( 
	merge( docs_s[seq(1,nrow(docs_s),by=4),], docs_s[seq(2,nrow(docs_s),by=4),], by=c('Date','QID','Type','NDCG1','NDCG3','NDCG5','SwapID')),
	merge( docs_s[seq(3,nrow(docs_s),by=4),], docs_s[seq(4,nrow(docs_s),by=4),], by=c('Date','QID','Type','NDCG1','NDCG3','NDCG5','SwapID')), 
						by=c('QID','Type','SwapID','URL.x','URL.y','Judgment.x','Judgment.y','HRS.x','HRS.y'), suffixes = c(".b",".a"))
	#write.table(docs_swr, file='docs_s_wider.txt', sep='\t')

	xb = 17:244 ; yb = 248:475 ; xa = 483:710 ; ya = 714:941
	if(depvar == 'dcgdiff')
		label =(2 ^ dsw['HRS.x'] - 1) * ( 1 / log( dsw['Rank.x.a'] + 1 ) -  1 / log( dsw['Rank.x.b'] + 1 ) ) + 
				(2 ^ dsw['HRS.y'] - 1) * ( 1 / log( dsw['Rank.y.a'] + 1 ) -  1 / log( dsw['Rank.y.b'] + 1 ) )
	else if(depvar == 'hrsdiff')
		label = (dsw['HRS.x'] - dsw['HRS.y'])
	else if(depvar == 'swapP')
		label = data.frame(Label = apply( (dsw['Type'] == 'swapP'), 1, generate.label))
	else if(depvar == 'swapN')
		label = data.frame(Label = apply( (dsw['Type'] != 'swapN'), 1, generate.label))
	else
		exit();
	colnames(label) = c('Label')
	#swaptbl = merge( dsw[,c(1:10,xa,ya)], anno, by.x='QID', by.y='QueryID')
	swaptbl = dsw[,c(1:10)]
	if( features == 'basic' | features =='all' ){
		swaptbl = cbind( swaptbl,dsw[,c(xa,ya)])
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,xa] - dsw[,xb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','chgx'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,ya] - dsw[,yb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','chgy'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,ya] - dsw[,xa])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','diffa'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,yb] - dsw[,xb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','diffb'))
	}
	if( features == 'adv' | features =='all' ){
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,xa] - dsw[,xb]) - (dsw[,ya] - dsw[,yb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','cdiffab'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,yb] - dsw[,xb]) + (dsw[,ya] - dsw[,xa])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','adiffxy'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,yb] + dsw[,xb]) + (dsw[,ya] + dsw[,xa])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','avgxy'))
	}
	swaptbl = merge( swaptbl, cbind( dsw$SwapID, label), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('',''))
}

# Run swap prediction with varying parameters
predict.swap <- function( docs_s, features, depvar, stbl = NULL )
{
	if( is.null(stbl) ){
		stbl = create.swaptbl( docs_s, features, depvar )# ; cs = colnames(stbl)
		analyze.table(stbl[,11:length(colnames(stbl))], feature_cnt = 500, run_id = paste(features, depvar, sep='_'))
	}
	result = list()
	label_set = data.frame(id = stbl$SwapID , label = (stbl$Type == 'swapP') )
	print("table generated...")
	
	for(feature_cnt in c(10,25,50,100,250))
		result = rbind(result, (cross.val.queries(stbl[c(1,11:length(colnames(stbl)))], feature_cnt = feature_cnt, label_set = label_set , method='glm')))
	#for(feature_cnt in c(10,25,50,100,250))
	#	result = rbind(result, (cross.val.queries(stbl[c(1,11:length(colnames(stbl)))], feature_cnt = feature_cnt, label_set = label_set , method='rf')))
	##for(feature_cnt in c(10,25,50,100,250,500))
	#	result = rbind(result, (cross.val.queries(stbl[c(1,11:length(colnames(stbl)))], feature_cnt = feature_cnt, label_set = label_set , method='lm')))
	#for(feature_cnt in c(10,25,50,100,250,500))
	#	result = rbind(result, (cross.val.queries(stbl[c(1,11:length(colnames(stbl)))], feature_cnt = feature_cnt, label_set = label_set , method='rpart')))
	#for(feature_cnt in c(10,25,50,100,250))
	#	result = rbind(result, (cross.val.queries(stbl[c(1,11:length(colnames(stbl)))], feature_cnt = feature_cnt, method='rf')))
	result
}

rerank.queries <- function(stbl, work_date, topk_p, topk, train_set = NULL, feature_cnt = 50, output = FALSE)
{
	stbl_e = stbl[stbl$Date == work_date,] ; stbl_t = stbl[stbl$Date != work_date,] ; cs=colnames(stbl_e)
	#label_set = data.frame(id = stbl_e$SwapID , label = (stbl_e$Type == 'swapP'))
	if( !is.null(train_set) )
		swaps = train.and.test.queries(train_set,stbl_e, method = 'glm')
	else
		swaps = cross.val.queries(stbl_t[c(1,11:length(cs))], stbl_e[c(1,11:length(cs))], feature_cnt = feature_cnt , method='glm', output=T)
	swaps_m = merge( stbl_e[,c(1:2, match('Rank.x.a',cs), match('Rank.y.a',cs), match('HRS.x',cs), match('HRS.y',cs))], swaps, by.x='SwapID',by.y='id' )
	
	LOG("Evaluating results...")

	#result = data.frame()
	topk_ora = undo.swap( topk, swaps_m[swaps_m$y == 0,] )
	result = cbind( get.exp.info(work_date, -999, stbl_t, stbl_e, swaps_m), 
		get.ndcg.result(topk_p, topk_ora$topk, topk_ora$qids_chg))
	for(threshold in c(0.2, 0.4, 0.5, 0.6, 0.8) ) #0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 
	{
		if( nrow( swaps_m[swaps_m$yhat < threshold,] ) == 0 ) 
			next
		topk_res = undo.swap( topk, swaps_m[swaps_m$yhat < threshold,] )
		result_cur = get.ndcg.result(topk_p, topk_res$topk, topk_res$qids_chg)
		exp_info = get.exp.info(work_date, threshold, stbl_t, stbl_e, swaps_m)
		result = rbind(result, cbind(exp_info, result_cur) )
	}
	result
}


undo.swap <- function( arg_topk , arg_stbl )
{
	if( nrow(arg_stbl) == 0 )
		return( list(topk=arg_topk, qids_chg=c()) )
	topk = arg_topk
	stbl = arg_stbl[order(arg_stbl$yhat),]
	qids_chg = c()
	rownames(topk) = paste( topk$QID, topk$Rank, sep='_' )
	for( i in 1:nrow(stbl) )
	{
		rowid1 = paste( stbl[i,]$QID, stbl[i,]$Rank.x.a, sep='_' )
		rowid2 = paste( stbl[i,]$QID, stbl[i,]$Rank.y.a, sep='_' )
		if( topk[rowid1,'HRS'] == stbl[i,]$HRS.x && topk[rowid2,'HRS'] == stbl[i,]$HRS.y )
		{
			topk[rowid1,'HRS'] = stbl[i,]$HRS.y
			topk[rowid2,'HRS'] = stbl[i,]$HRS.x
		}
		else
		{
			#LOG("HRS value inconsistent!")
			next
			#return(NULL);
		}
		qids_chg = append(qids_chg, stbl[i,]$QID)
		#LOG("Changing %s -> %d /  %s -> %d", rowid1, stbl[i,]$HRS.y, rowid2, stbl[i,]$HRS.x)
	}
	list(topk=topk, qids_chg=qids_chg)
}

get.exp.info <- function(work_date, threshold, stbl_t, stbl_e, swaps_m)
{
	if( threshold == -999 )
		effect_swap = swaps_m[swaps_m$y == 0,]
	else
		effect_swap = swaps_m[swaps_m$yhat < threshold,]
	
	data.frame(work_date=work_date, threshold = threshold, 
		train_swap = nrow(stbl_t), test_swap = nrow(stbl_e), effect_swap =  nrow(effect_swap), 
		precision = nrow( swaps_m[swaps_m$yhat < threshold & swaps_m$y == 0 ,] ) / nrow(swaps_m[swaps_m$yhat < threshold,]))
}

get.ndcg.result <- function(topk_p, topk, qids_chg = c(), output = FALSE)
{
	dcg1 = aggregate( topk$HRS, by=list(topk$QID), FUN = get_dcg1) ; colnames(dcg1) = c('QID','DCG1.n')
	dcg5 = aggregate( topk$HRS, by=list(topk$QID), FUN = get_dcg5) ; colnames(dcg5) = c('QID','DCG5.n')
	topk_m = merge( topk[topk$Rank == 1,], dcg1, by = 'QID' )
	topk_m = merge( topk_m, dcg5, by = 'QID' )
	topk_m = merge( topk_m, topk_p[topk_p$Rank == 1,], by='QID', suffixes=c('','.p' ))
	topk_m$NDCG1.n = sapply(topk_m$DCG1.n / topk_m$DCG1 * topk_m$NDCG1, na2zero)
	topk_m$NDCG5.n = sapply(topk_m$DCG5.n / topk_m$DCG5 * topk_m$NDCG5, na2zero)
	topk_chg_m = topk_m[topk_m$QID %in% qids_chg,]
	
	if( output )
		topk_chg_m
	else
		cbind(calc.ndcg.result( topk_m, 'NDCG1.n', 'NDCG1', 'NDCG1.p' ), calc.ndcg.result( topk_chg_m, 'NDCG1.n', 'NDCG1', 'NDCG1.p' ),
			  calc.ndcg.result( topk_m, 'NDCG5.n', 'NDCG5', 'NDCG5.p' ), calc.ndcg.result( topk_chg_m, 'NDCG5.n', 'NDCG5', 'NDCG5.p' ))
}

calc.ndcg.result <- function( topk_m, ndcg_n, ndcg, ndcg_p )
{
	if( nrow(topk_m) > 0)
		p.value = t.test( topk_m[,ndcg_n] , topk_m[,ndcg], paired=T, na.action=na.omit)$p.value
	else
		p.value = -1
	ndcg_gain = topk_m[,ndcg_n] - topk_m[,ndcg]
	dndcg	= abs(topk_m[,ndcg_n] - topk_m[,ndcg_p])
	dndcg_o = abs(topk_m[,ndcg] - topk_m[,ndcg_p])
	data.frame( ndcg=mean(topk_m[,ndcg_n]), ndcg_gain=mean(ndcg_gain), ndcg_gain_percent=(mean(ndcg_gain) / mean(topk_m[,ndcg])) , p.value=p.value, dndcg=mean(dndcg), dndcg_o=mean(dndcg_o))
}

####################
# 

get_dcg5 <- function(rows)
{
	result = 0
	for(i in (1:5))
	{
		result = result + (2^rows[i] - 1) / log2(1 + i)
	}
	return(result);
}

get_dcg1 <- function(rows)
{
	result = 0
	for(i in (1:1))
	{
		result = result + (2^rows[i] - 1) / log2(1 + i)
	}
	return(result);
}



mean4na <- function( arr )
{
	result = 0
	for( value in arr )
	{
		if(!is.na( value ) && !is.nan( value ))
			result = result + value
	}
	result / length(arr)
}

na2zero <- function( value )
{
	if( is.na( value ) || is.nan( value ))
		0
	else
		value
}

generate.label <- function( bool )
{
	if(bool)
		1
	else
		0
}


