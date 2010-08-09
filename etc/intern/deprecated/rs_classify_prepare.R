# Reading
setwd("c:/data")
source("code/rs_import_data.R")
source("code/rs_library.R")
#d_b06 = read.table('result_all_0622.csv',sep=',',quote='',header=TRUE)

# Import the Existence of Document in Each Index
# Group.1 Group.2  x
#list( nrow(ichk), sum(ichk$Main), sum(ichk$SFresh), sum(ichk$QFresh))
m_docs  = merge(docs_a, ichk_o, by="URL")
ichk = cbind(m_docs, nrc=apply( m_docs, 1, non_rank_chg))

### Merge Daily Result with Change Type
daily_n	= daily[,c('QID','Date','dNDCG1','dNDCG3','dNDCG5','Overlap1','Tau3','Tau5')] # filter only qid/date/ndcg_k

# using index check result
a_ichk = aggregate( ichk$nrc , by=list(ichk$Date, ichk$QID), FUN = sum) 
daily_rn  = merge(daily_n, a_ichk,  by.x=c('Date', 'QID'), by.y=c('Group.1', 'Group.2'), all.x=TRUE)
daily_rn = daily_rn[-which(daily_rn$x > 0),]
#aggregate( daily_rn$QID , by=list(daily_rn$Date), FUN = length)

# using addtion/deletion change type
a_ichk2 = aggregate( docs_a$QID , by=list(docs_a$Date, docs_a$QID), FUN = length) 
daily_sn = merge(daily_n, a_ichk2, by.x=c('Date', 'QID'), by.y=c('Group.1', 'Group.2'), all.x=TRUE)
daily_sn = daily_sn[-which(daily_sn$x > 0),]
#aggregate( daily_sn5$QID , by=list(daily_sn5$Date), FUN = length)

# Group Target Var (dNDCG5) by Date
daily_aw1 	= reshape(daily_n,  v.names='dNDCG1', idvar='QID', timevar='Date',direction='wide')
daily_rw1   = reshape(daily_rn, v.names='dNDCG1', idvar='QID', timevar='Date',direction='wide')
daily_sw1   = reshape(daily_sn, v.names='dNDCG1', idvar='QID', timevar='Date',direction='wide')
daily_aw3 	= reshape(daily_n,  v.names='dNDCG3', idvar='QID', timevar='Date',direction='wide')
daily_rw3   = reshape(daily_rn, v.names='dNDCG3', idvar='QID', timevar='Date',direction='wide')
daily_sw3   = reshape(daily_sn, v.names='dNDCG3', idvar='QID', timevar='Date',direction='wide')
daily_aw5 	= reshape(daily_n,  v.names='dNDCG5', idvar='QID', timevar='Date',direction='wide')
daily_rw5   = reshape(daily_rn, v.names='dNDCG5', idvar='QID', timevar='Date',direction='wide')
daily_sw5   = reshape(daily_sn, v.names='dNDCG5', idvar='QID', timevar='Date',direction='wide')
daily_rwt 	= reshape(daily_rn, v.names='Tau', idvar='QID', timevar='Date',direction='wide')

# Build Training Data by Merging
d0613 = daily[daily$Date == '6_13_2010',]
m0613_aw1 = merge(d0613, daily_aw1, by = 'QID', suffixes = c(".d",".a"))
m0613_rw1 = merge(d0613, daily_rw1, by = 'QID', suffixes = c(".d",".a"))
m0613_sw1 = merge(d0613, daily_sw1, by = 'QID', suffixes = c(".d",".a"))
m0613_aw3 = merge(d0613, daily_aw3, by = 'QID', suffixes = c(".d",".a"))
m0613_rw3 = merge(d0613, daily_rw3, by = 'QID', suffixes = c(".d",".a"))
m0613_sw3 = merge(d0613, daily_sw3, by = 'QID', suffixes = c(".d",".a"))
m0613_aw5 = merge(d0613, daily_aw5, by = 'QID', suffixes = c(".d",".a"))
m0613_rw5 = merge(d0613, daily_rw5, by = 'QID', suffixes = c(".d",".a"))
m0613_sw5 = merge(d0613, daily_sw5, by = 'QID', suffixes = c(".d",".a"))

# Daily Regression Result
col_list = c('Overlap1.d','Tau3.d','Tau5.d','dScore1','NDCG1','dNDCG1.6_11_2010','dNDCG1.6_12_2010','dNDCG1.6_13_2010')
sapply( list( m0613_aw1[, col_list], m0613_rw1[, col_list], m0613_sw1[, col_list]), analyze.table)

col_list = c('Overlap1.d','Tau3.d','Tau5.d','dScore3','NDCG3','dNDCG3.6_11_2010','dNDCG3.6_12_2010','dNDCG3.6_13_2010')
sapply( list( m0613_aw3[, col_list], m0613_rw3[, col_list], m0613_sw3[, col_list]), analyze.table)

col_list = c('Overlap1.d','Tau3.d','Tau5.d','dScore5','NDCG5','dNDCG5.6_11_2010','dNDCG5.6_12_2010','dNDCG5.6_13_2010')
sapply( list( m0613_aw5[, col_list], m0613_rw5[, col_list], m0613_sw5[, col_list]), analyze.table)

# Aggregate Regression Result (rNDCG)

sapply( list( agg[,c(2,3,8:10,12)], agg[,c(2,4,6,13:15,17)], agg[,c(2,5,7,18:20,22)]), analyze.table) # all records
sapply( list( agg[,c(2,3,8:11)], agg[,c(2,4,6,13:16)], agg[,c(2,5,7,18:21)]), analyze.table) # all records

daily_rw1$x = NULL ; daily_sw1$x = NULL
agg_r = merge(agg, filter_na_rows(daily_rw1), by.x='qID', by.y='QID')
agg_s = merge(agg, filter_na_rows(daily_sw1), by.x='qID', by.y='QID')

sapply( list( agg_r[,c(2,3,8:10,12)], agg_r[,c(2,4,6,13:15,17)], agg_r[,c(2,5,7,18:20,22)]), analyze.table) # all records
sapply( list( agg_r[,c(2,3,8:11)], agg_r[,c(2,4,6,13:16)], agg_r[,c(2,5,7,18:21)]), analyze.table) # all records

sapply( list( agg_s[,c(2,3,8:10,12)], agg_s[,c(2,4,6,13:15,17)], agg_s[,c(2,5,7,18:20,22)]), analyze.table) # all records
sapply( list( agg_s[,c(2,3,8:11)], agg_s[,c(2,4,6,13:16)], agg_s[,c(2,5,7,18:21)]), analyze.table) # all records

