select distinct d.dtype, d.title, q.query_text, q.position
from documents d, queries q 
where d.id = q.document_id and q.position > 0 and q.position < 10;

select * from documents where id in (select distinct d.id
from documents d, queries q 
where d.id = q.document_id and q.position > 0 and q.position < 10);

select * from games where score > 0;

select * from documents where dtype='calendar';

update documents set indexed_at=null;

create table queries_1219 as select * from queries;

create table games_1219 as select * from games;

# PageHunt Migration

update users set utype='admin' where admin_flag == '1';

alter table documents rename to items;

alter table sources change column dtype itype varchar(255);

alter table items change column dtype itype varchar(255);

update items set itype='query' where itype='lfda_query';

alter table rules change column dtype itype varchar(255);

alter table queries change column document_id item_id int(11);

alter table occurrences change column document_id item_id int(11);

alter table occurrences change column concept_id tag_id int(11);

select itype, count(*) from items 
group by itype having count(*)>1;

select date(basetime), count(*) from documents group by date(basetime);

select user_id, count(*) from queries group by user_id;
