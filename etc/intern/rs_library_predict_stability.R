
test.feature_set <- function( method, train_set,test_set, debug_flag = FALSE )
{
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = FALSE, ft_ndcg = FALSE, ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag))
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = FALSE, ft_qry = FALSE, ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = FALSE,  ft_qry = TRUE,  ft_qurl = TRUE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
	print(sapply( select.ftypes(train_set, add_id=TRUE, ft_rank = TRUE, ft_score = TRUE,  ft_ndcg = FALSE,  ft_qry = TRUE,  ft_qurl = FALSE), cross.val.queries, test=test_set, method=method, feature_cnt = 100, debug=debug_flag ))
	#print(sapply( select.ftypes(train_set, add_id=TRUE), cross.val.queries, test=test_set, method=method, debug=debug_flag ))
}

# Select feature types of aggregate table
# - ft_* : specify whether to add different types of features
select.ftypes <- function( agg_m , add_id = FALSE, ft_rank = TRUE, ft_score = TRUE, ft_ndcg = TRUE, ft_qry = TRUE, ft_qurl = FALSE)
{
	if( add_id )
		result = c(1)
	else
		result = c()
	if( ft_rank ) result = append( result, c(3:10, 509 ) )
	if( ft_score) result = append( result, c(11:12,510,19:20,27,28) )
	if( ft_ndcg ) result = append( result, c(16,24,32) )
	if( ft_qry  ) result = append( result, c(485:508 ) )
	if( ft_qurl ) result = append( result, c(35:482) )
	list(k1 = agg_m[,append(result, c(18))], k3 = agg_m[,append(result, c(26))], k5 = agg_m[,append(result, c(34))])
}

select.ftypes.daily <- function( arg_daily, arg_date, ft_2day = TRUE, ft_qry = TRUE, ft_ndcg = FALSE, exclude = FALSE, add_id = TRUE )
{
	if( add_id )
		result = c(1)
	else
		result = c()
	result = append( result, c(1,6:7,11:12,16:17))
	if( ft_qry  ) result = append( result, c(35:58))
	if( ft_2day ) result = append( result, c(18:22,27:29))
	if( ft_ndcg )
	{
		result = append( result, c(3,8,13))
		result = append( result, c(4,9,14))
	}
	
	if( !exclude )
		daily = arg_daily[arg_daily$Date == arg_date,]
	else
		daily = arg_daily[arg_daily$Date != arg_date,]
	
	#list(k1 = daily[,append(result, c(4))], k3 = daily[,append(result, c(9))], k5 = daily[,append(result, c(14))])
	list(k1 = daily[,append(result, c(31))], k3 = daily[,append(result, c(32))], k5 = daily[,append(result, c(33))])
}