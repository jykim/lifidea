setwd("c:/data")
source("c:/dev/lifidea/etc/intern/rs_library_predict_insdel.R")

batch = 'w1'
cdocs_all = read.table(paste('result_cdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
bdocs_all = read.table(paste('result_bdocs_',batch,'.txt.short',sep=''),sep='\t',quote='"',header=TRUE)
hrsb = aggregate(bdocs_all$HRS, by=list(bdocs_all$CDID), FUN=mean)
colnames(hrsb) = c('CDID','HRSB')
cdocs = project.table(cdocs_all, c(1:4, 8:16), read.table('EffectiveFeatureList.txt', header=T) )
docs_d   = cdocs[cdocs$Type == 'del',]   # Documents swapped
docs_i   = cdocs[cdocs$Type == 'add',]   # Documents swapped
#dtbl1 = create.del.table( docs_d, hrsb ) # Non-negative vs. Negative
#analyze.table( dtbl1 )

predict.insdel( docs_d, hrsb, depvar='hrsdiff' , method='lm')
predict.insdel( docs_d, hrsb, depvar='binary' , method='lm')
predict.insdel( docs_d, hrsb, depvar='hrsdiff' , method='rf')
predict.insdel( docs_d, hrsb, depvar='binary' , method='rf')

predict.insdel( docs_i, hrsb, depvar='hrsdiff' , method='lm')
predict.insdel( docs_i, hrsb, depvar='binary' , method='lm')
predict.insdel( docs_i, hrsb, depvar='hrsdiff' , method='rf')
predict.insdel( docs_i, hrsb, depvar='binary' , method='rf')
