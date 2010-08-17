source("c:/dev/lifidea/etc/intern/rs_library.R")
source("c:/dev/lifidea/etc/intern/rs_library_predict.R")


test.feature_set <- function( method, train_set,test_set, debug_flag = FALSE )
{
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = FALSE, ft_ndcg = FALSE, ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag))
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = FALSE, ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = TRUE,  ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = TRUE,  ft_qry = TRUE,  ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.ftypes(train_set, add_id=TRUE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
}

# Select feature types of aggregate table
# - ft_* : specify whether to add different types of features
select.ftypes <- function( agg_m , add_id = FALSE, ft_rank = TRUE, ft_score = TRUE, ft_ndcg = TRUE, ft_qry = TRUE, ft_qurl = FALSE)
{
	if( add_id )
		result = c(1)
	else
		result = c()
	if( ft_rank ) result = append( result, c(3:10, 508 ) )
	if( ft_score) result = append( result, c(11:12,509,19:20,27,28) )
	if( ft_ndcg ) result = append( result, c(16,24,32) )
	if( ft_qry  ) result = append( result, c(484:507 ) )
	if( ft_qurl ) result = append( result, c(35:482) )
	list(k1 = agg_m[,append(result, c(18))], k3 = agg_m[,append(result, c(26))], k5 = agg_m[,append(result, c(34))])
}

select.ftypes.daily <- function( daily, arg_date, exclude = FALSE, add_id = TRUE )
{
	if( add_id )
		result = c(1)
	else
		result = c()
	result = append( result, c(1,3,6:8,11:13,16:27))
	if( !exclude )
		list(k1 = daily[daily$Date == arg_date,append(result, c(4))], k3 = daily[daily$Date == arg_date,append(result, c(9))], k5 = daily[daily$Date == arg_date,append(result, c(14))])
	else
		list(k1 = daily[daily$Date != arg_date,append(result, c(4))], k3 = daily[daily$Date != arg_date,append(result, c(9))], k5 = daily[daily$Date != arg_date,append(result, c(14))])
}