source("c:/dev/lifidea/etc/intern/rs_library.R")
source("c:/dev/lifidea/etc/intern/rs_library_analyze.R")
source("c:/dev/lifidea/etc/intern/rs_library_predict.R")
source("c:/dev/lifidea/etc/intern/rs_library_predict_swap.R")

# Create a table of features for insertion/deletion prediction
create.insdel.table <- function( docs_d, hrsb, depvar = 'hrsdiff' )
{
	dsw = merge(docs_d, hrsb, by=c('CDID'))

	if(depvar == 'hrsdiff')
		label = (dsw['HRS'] - dsw['HRSB'])
	else if (depvar == 'binary')
		label = data.frame(Label = apply( (dsw['HRS'] - dsw['HRSB'] > 0), 1, generate.binary.label))
	else
		exit();
	colnames(label) = c('Label')
	
	cbind( dsw[,c(1,8:11, 14:52)], label )
}

# Run a swap prediction experiment with varying parameters
predict.insdel <- function( docs_d, hrsb, method='lm', depvar='hrsdiff', feature_cnts = c(10,25,50,75,100)) #feature_cnt = NULL, 
{
	dtbl = create.insdel.table( docs_d, hrsb, depvar=depvar )
	result = list()
	label_set = data.frame(id = dtbl$CDID , label = (dtbl$Label > 0) )
	print("table generated...")
	
	#for(feature_cnt in feature_cnts)
		result = rbind(result, (cross.val.queries(dtbl, feature_cnt = NULL, label_set = label_set , method=method)))
	result
}

# Run a insertion/deletion re-ranking experiment
rerank.queries	<- function(dtbl, work_date, topk_p, topk, train_dtbl = NULL, method = 'glm', feature_cnt = 100, thresholds = c(0,1, 0.2, 0.3, 0.4, 0.5) , output = FALSE)
{
	dtbl_e = dtbl[dtbl$Date == work_date,] ; cs=colnames(dtbl_e)
	if( !is.null(train_dtbl) )
		dtbl_t = train_dtbl
	else
		dtbl_t = dtbl[dtbl$Date != work_date,] 
		
	dels = train.and.test.queries(dtbl_t[,11:length(cs)], dtbl_e[,11:length(cs)], feature_cnt = feature_cnt, method = method)
	dels_m = cbind( dtbl_e[,c(2,3,4,8,12))], y=dels$y, yhat=dels$yhat )
	
	LOG("Evaluating results...")

	#result = data.frame()
	topk_ora = undo.del( topk, dels_m[dels_m$y <= 0,] )
	result = cbind( get.exp.info(work_date, -999, dtbl_t, dtbl_e, dels_m, topk_ora$dels_skipped), 
					get.ndcg.result(topk_p, topk_ora$topk, topk_ora$qids_chg))
	for(threshold in thresholds ) #
	{
		arg_dtbl = dels_m[order(dels_m$yhat),][1:round(nrow(dels_m)*threshold),]#[dels_m$yhat < threshold,]#
		topk_res = undo.del( topk, arg_dtbl )
		#result_cur = get.ndcg.result(topk_p[topk_p$QID %in% topk_res$qids_chg,], topk_res$topk[topk_res$topk$QID %in% topk_res$qids_chg,], topk_res$qids_chg, output=output)
		result_cur = get.ndcg.result(topk_p, topk_res$topk, topk_res$qids_chg, output=output)
		if( threshold == 0.2 & output == TRUE)
			return( list(dtbl=dtbl_e, dels=dels_m, queries=result_cur) )
		else if( output == FALSE ){
			exp_info = get.exp.info(work_date, threshold, dtbl_t, dtbl_e, dels_m, topk_res$dels_skipped)
			result = rbind(result, cbind(exp_info, result_cur))
		}
	}
	result
}

# Re-rank topk results by applying swas
# - not implemented yet
undo.del <- function( arg_topk , dtbl )
{
	if( nrow(dtbl) <= 1 )
		return( list(topk=arg_topk, qids_chg=c(), dels_skipped=c()) )
	topk = arg_topk
	qids_chg = c()
	dels_skipped = c()
	rownames(topk) = paste( topk$QID, topk$Rank, sep='_' )
	for( i in 1:nrow(dtbl) )
	{
		rowid = paste( dtbl[i,]$QID, dtbl[i,]$Rank, sep='_' )
		if( topk[rowid,'HRS'] == dtbl[i,]$HRS ){
			topk[rowid,'HRS']
		}
		else{
			#LOG("HRS value inconsistent!")
			dels_skipped = append(dels_skipped, dtbl[i,]$CDID)
			next
			#return(NULL);
		}
		qids_chg = append(qids_chg, dtbl[i,]$QID)
		#LOG("Changing %s -> %d /  %s -> %d", rowid1, dtbl[i,]$HRS.y, rowid2, dtbl[i,]$HRS.x)
	}
	list(topk=topk, qids_chg=qids_chg, dels_skipped=dels_skipped)
}

