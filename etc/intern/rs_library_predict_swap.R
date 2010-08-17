source("c:/dev/lifidea/etc/intern/rs_library.R")
source("c:/dev/lifidea/etc/intern/rs_library_analyze.R")
source("c:/dev/lifidea/etc/intern/rs_library_predict.R")

# Create a table of features for swap prediction
create.swap.table <- function( docs_s, features = 'all', depvar = 'dcgdiff' )
{
	# Create a Wider Table (one row per swap)
	dsw = merge(
			merge( docs_s[seq(1,nrow(docs_s),by=4),], docs_s[seq(2,nrow(docs_s),by=4),], by=c('Date','QID','Type','NDCG1','NDCG3','NDCG5','SwapID')),
			merge( docs_s[seq(3,nrow(docs_s),by=4),], docs_s[seq(4,nrow(docs_s),by=4),], by=c('Date','QID','Type','NDCG1','NDCG3','NDCG5','SwapID')), 
			by=c('QID','Type','SwapID','URL.x','URL.y','Judgment.x','Judgment.y','HRS.x','HRS.y'), suffixes = c("b","a"))

	xb = 14:56 ; yb = 57:99 ; xa = 104:146 ; ya = 147:189
	#xb = 17:244 ; yb = 248:475 ; xa = 483:710 ; ya = 714:941
	if(depvar == 'dcgdiff')
		label = (2 ^ dsw['HRS.x'] - 1) * ( 1 / log( dsw['Rank.xa'] + 1 ) -  1 / log( dsw['Rank.xb'] + 1 ) ) + 
				(2 ^ dsw['HRS.y'] - 1) * ( 1 / log( dsw['Rank.ya'] + 1 ) -  1 / log( dsw['Rank.yb'] + 1 ) )
	else if(depvar == 'hrsdiff')
		label = (dsw['HRS.x'] - dsw['HRS.y'])
	else if(depvar == 'Nhrsdiff')
		label = (dsw['HRS.x'] - dsw['HRS.y'])/8+0.5
	else if(depvar == 'Bhrsdiff')
		label = data.frame(Label = apply(dsw['HRS.x'] - dsw['HRS.y'], 1, generate.range.label))
	else if(depvar == 'swapP')
		label = data.frame(Label = apply( (dsw['Type'] == 'swapP'), 1, generate.binary.label))
	else if(depvar == 'swapN')
		label = data.frame(Label = apply( (dsw['Type'] != 'swapN'), 1, generate.binary.label))
	else
		exit();
	colnames(label) = c('Label')
	swaptbl = dsw[,c(1:10)]
	if( features == 'basic' | features =='all' ){
		swaptbl = cbind( swaptbl,dsw[,c(xa,ya)])
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,xa] - dsw[,xb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','.cX'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,ya] - dsw[,yb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','.cY'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,ya] - dsw[,xa])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','.dA'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,yb] - dsw[,xb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','.dB'))
	}
	if( features == 'adv' | features =='all' ){
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,xa] - dsw[,xb]) - (dsw[,ya] - dsw[,yb])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','.dcAB'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,yb] - dsw[,xb]) + (dsw[,ya] - dsw[,xa])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','.adXY'))
		swaptbl = merge( swaptbl, cbind( dsw$SwapID, (dsw[,yb] + dsw[,xb]) + (dsw[,ya] + dsw[,xa])), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('','.aXY'))
	}
	swaptbl = merge( swaptbl, cbind( dsw$SwapID, label), by.x=c('SwapID'), by.y=c('dsw$SwapID'), suffixes=c('',''))
}

# Run a swap prediction experiment with varying parameters
predict.swap <- function( docs_s, features, depvar, method, feature_cnts = c(10,25,50,75,100), stbl = NULL ) #feature_cnt = NULL, 
{
	if( is.null(stbl) ){
		stbl = create.swap.table( docs_s, features, depvar )# ; cs = colnames(stbl)
		#analyze.table(stbl[,11:length(colnames(stbl))], feature_cnt = 500, run_id = paste(features, depvar, sep='_'))
	}
	result = list()
	label_set = data.frame(id = stbl$SwapID , label = (stbl$Type == 'swapP') )
	print("table generated...")
	
	for(feature_cnt in feature_cnts)
		result = rbind(result, (cross.val.queries(stbl[,c(1,11:length(colnames(stbl)))], 
			feature_cnt = feature_cnt, features = features, depvar=depvar, label_set = label_set , method=method)))
	result
}

# Run a swap re-ranking experiment
rerank.queries <- function(stbl, work_date, topk_p, topk, train_stbl = NULL, method = 'glm', feature_cnt = 100, thresholds = c(0,1, 0.2, 0.3, 0.4, 0.5) , output = FALSE)
{
	stbl_e = stbl[stbl$Date == work_date,] ; cs=colnames(stbl_e)
	if( !is.null(train_stbl) )
		stbl_t = train_stbl
	else
		stbl_t = stbl[stbl$Date != work_date,] 
		
	swaps = train.and.test.queries(stbl_t[,11:length(cs)], stbl_e[,11:length(cs)], feature_cnt = feature_cnt, method = method)
	swaps_m = cbind( stbl_e[,c(1:2, match('Rank.xa',cs), match('Rank.ya',cs), match('HRS.x',cs), match('HRS.y',cs))], y=swaps$y, yhat=swaps$yhat )
	
	LOG("Evaluating results...")

	#result = data.frame()
	topk_ora = undo.swap( topk, swaps_m[swaps_m$y <= 0.5,] )
	result = cbind( get.exp.info(work_date, -999, stbl_t, stbl_e, swaps_m, topk_ora$swaps_skipped), 
					get.ndcg.result(topk_p, topk_ora$topk, topk_ora$qids_chg))
	for(threshold in thresholds ) #
	{
		arg_stbl = swaps_m[order(swaps_m$yhat),][1:round(nrow(swaps_m)*threshold),]#[swaps_m$yhat < threshold,]#
		topk_res = undo.swap( topk, arg_stbl )
		#result_cur = get.ndcg.result(topk_p[topk_p$QID %in% topk_res$qids_chg,], topk_res$topk[topk_res$topk$QID %in% topk_res$qids_chg,], topk_res$qids_chg, output=output)
		result_cur = get.ndcg.result(topk_p, topk_res$topk, topk_res$qids_chg, output=output)
		if( threshold == 0.4 & output == TRUE)
			return( list(stbl=stbl_e, swaps=swaps_m, queries=result_cur) )
		else if( output == FALSE ){
			exp_info = get.exp.info(work_date, threshold, stbl_t, stbl_e, swaps_m, topk_res$swaps_skipped)
			result = rbind(result, cbind(exp_info, result_cur))
		}
	}
	result
}

# Re-rank topk results by applying swas
undo.swap <- function( arg_topk , stbl )
{
	if( nrow(stbl) <= 1 )
		return( list(topk=arg_topk, qids_chg=c(), swaps_skipped=c()) )
	topk = arg_topk
	qids_chg = c()
	swaps_skipped = c()
	rownames(topk) = paste( topk$QID, topk$Rank, sep='_' )
	for( i in 1:nrow(stbl) )
	{
		rowid1 = paste( stbl[i,]$QID, stbl[i,]$Rank.xa, sep='_' )
		rowid2 = paste( stbl[i,]$QID, stbl[i,]$Rank.ya, sep='_' )
		if( topk[rowid1,'HRS'] == stbl[i,]$HRS.x && topk[rowid2,'HRS'] == stbl[i,]$HRS.y ){
			topk[rowid1,'HRS'] = stbl[i,]$HRS.y
			topk[rowid2,'HRS'] = stbl[i,]$HRS.x
		}
		else{
			#LOG("HRS value inconsistent!")
			swaps_skipped = append(swaps_skipped, stbl[i,]$SwapID)
			next
			#return(NULL);
		}
		qids_chg = append(qids_chg, stbl[i,]$QID)
		#LOG("Changing %s -> %d /  %s -> %d", rowid1, stbl[i,]$HRS.y, rowid2, stbl[i,]$HRS.x)
	}
	list(topk=topk, qids_chg=qids_chg, swaps_skipped=swaps_skipped)
}

# Get info. on experiments
get.exp.info <- function(work_date, threshold, stbl_t, stbl_e, swaps_m, swaps_skipped)
{
	if( threshold == -999 )
		effect_swap = swaps_m[swaps_m$y == 0,]
	else
		effect_swap = swaps_m[order(swaps_m$yhat),][1:round(nrow(swaps_m)*threshold),]#[swaps_m$yhat < threshold,]#
	
	data.frame(work_date=work_date, threshold = threshold, 
		train_swap = nrow(stbl_t), test_swap = nrow(stbl_e), effect_swap =  nrow(effect_swap), swaps_skipped = length(swaps_skipped), 
		precision = nrow( effect_swap[effect_swap$y == 0 ,] ) / nrow(effect_swap))
}

# Calculate NDCG / dNDCG gain
get.ndcg.result <- function(topk_p, topk, qids_chg = c(), output = FALSE)
{
	dcg1 = aggregate( topk$HRS, by=list(topk$QID), FUN = get_dcg1) ; colnames(dcg1) = c('QID','DCG1.n')
	dcg3 = aggregate( topk$HRS, by=list(topk$QID), FUN = get_dcg3) ; colnames(dcg3) = c('QID','DCG3.n')
	dcg5 = aggregate( topk$HRS, by=list(topk$QID), FUN = get_dcg5) ; colnames(dcg5) = c('QID','DCG5.n')
	topk_m = merge( topk[topk$Rank == 1,], dcg1, by = 'QID' )
	topk_m = merge( topk_m, dcg3, by = 'QID' )
	topk_m = merge( topk_m, dcg5, by = 'QID' )
	topk_m = merge( topk_m, topk_p[topk_p$Rank == 1,], by='QID', suffixes=c('','.p' ))
	topk_m$NDCG1.n = sapply(topk_m$DCG1.n / topk_m$DCG1 * topk_m$NDCG1, na2zero)
	topk_m$NDCG3.n = sapply(topk_m$DCG3.n / topk_m$DCG3 * topk_m$NDCG3, na2zero)
	topk_m$NDCG5.n = sapply(topk_m$DCG5.n / topk_m$DCG5 * topk_m$NDCG5, na2zero)
	topk_chg_m = topk_m[topk_m$QID %in% qids_chg,]
	
	if( output )
		topk_chg_m
	else
		cbind(calc.ndcg.result( topk_m, 'NDCG1.n', 'NDCG1', 'NDCG1.p' ), calc.ndcg.result( topk_chg_m, 'NDCG1.n', 'NDCG1', 'NDCG1.p' ),
			  calc.ndcg.result( topk_m, 'NDCG3.n', 'NDCG3', 'NDCG3.p' ), calc.ndcg.result( topk_chg_m, 'NDCG3.n', 'NDCG3', 'NDCG3.p' ),
			  calc.ndcg.result( topk_m, 'NDCG5.n', 'NDCG5', 'NDCG5.p' ), calc.ndcg.result( topk_chg_m, 'NDCG5.n', 'NDCG5', 'NDCG5.p' ))
}

calc.ndcg.result <- function( topk_m, ndcg_n, ndcg, ndcg_p )
{
	if( nrow(topk_m) > 10 & sum(topk_m[,ndcg_n] - topk_m[,ndcg]) != 0 )
		p.value = t.test( topk_m[,ndcg_n] , topk_m[,ndcg], paired=T, na.action=na.omit)$p.value
	else
		p.value = -1
	ndcg_gain = topk_m[,ndcg_n] - topk_m[,ndcg]
	dndcg	= abs(topk_m[,ndcg_n] - topk_m[,ndcg_p])
	dndcg_o = abs(topk_m[,ndcg] - topk_m[,ndcg_p])
	data.frame( ndcg=mean(topk_m[,ndcg_n]), ndcg_o=mean(topk_m[,ndcg]), ndcg_gain=mean(ndcg_gain), ndcg_gain_percent=(mean(ndcg_gain) / mean(topk_m[,ndcg])) , 
		p.value=p.value, dndcg=mean(dndcg), dndcg_o=mean(dndcg_o), dndcg_percent=((mean(dndcg) - mean(dndcg_o)) / mean(dndcg_o)))
}

###############
#  UTILITIES

get_dcg5 <- function(rows)
{
	result = 0
	for(i in (1:5))
	{
		result = result + (2^rows[i] - 1) / log2(1 + i)
	}
	return(result);
}

get_dcg3 <- function(rows)
{
	result = 0
	for(i in (1:3))
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

generate.binary.label <- function( bool )
{
	if(bool)
		1
	else
		0
}

generate.range.label <- function( value )
{
	if( value <= -1 )
		0
	else if( value == 0 )
		0.5
	else
		1
}



