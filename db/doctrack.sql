# Export Queries
select u.uid, q.game_id, q.item_id, q.created_at, q.query_text, q.position, i.did 
INTO OUTFILE '/tmp/dtenron_result.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
from queries q, items i, users u
where i.id = q.item_id and q.user_id = u.id;

