# QUERY 11/16

# DOCUMENTS

# Group documents by basedate
select date(basetime), count(*) from documents group by date(basetime);


select * from items where content is null;

# Group documents by itype
select itype, count(*) from items 
where content is null
group by itype having count(*)>1;

select itype, count(*) from items 
where textindex is null
group by itype having count(*)>1;

select source,id,uri,title,tag,published_at,created_at from documents order by id desc;

select * from documents where basedate is null;

# Documents with more than 10 occurrences
select d.id, d.title, count(*) from documents d, occurrences o 
  where d.id = o.item_id 
  group by d.id having count(*) > 10;


# CONCEPTS



# STATS
SELECT * FROM `stats` WHERE (title like '%day%' and basedate > '2009-06-05' and basedate < '2009-06-14');

select title, count(*) from stats group by title;

SELECT * FROM `stats` WHERE (title like '%day%' and basedate > '2009-06-05' and basedate < '2009-06-14');
