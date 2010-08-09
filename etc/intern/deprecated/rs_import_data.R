# Aggregate Results
setwd("c:/data")
batch = 'goog'

agg = read.table(paste('result_all_',batch,'.txt',sep=''),sep='\t',quote='',header=TRUE)

# Daily Results
daily = read.table(paste('result_daily_',batch,'.txt',sep=''),sep='\t',quote='',header=TRUE)

# Document-level Results
docs = read.table(paste('result_cdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)
docs_a   = docs[docs$Type == 'add' | docs$Type == 'del',]   # Documents added / deleted
docs_s   = docs[docs$Type == 'swapP' | docs$Type == 'swapU' | docs$Type == 'swapN',]   # Documents swapped

docst = read.table(paste('result_sdocs_',batch,'.txt',sep=''),sep='\t',quote='"',header=TRUE)


anno = read.table('annotationsB06_July.csv', sep=',',quote='',header=TRUE) # Query annotations
ichk_o = read.table('docs_ichk_all.txt.result',sep='\t',quote='',header=TRUE) # Index check results

# Export the list of docs for Index check
#write.table( setdiff(unique(docs_a$URL), ichk_o$URL), file = 'docs_ichk_0712.txt', quote=FALSE, row.names=FALSE, col.names=FALSE)
#write.table( sample(agg[["Query"]],1000), file = 'queries_chk.txt', quote=FALSE, row.names=FALSE, col.names=FALSE)
