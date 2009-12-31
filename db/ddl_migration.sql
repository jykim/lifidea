alter table documents rename to items;

alter table items change column itype itype varchar(255);

insert into items (did,itype,uri,title,source_id,metadata,textindex,basetime,hidden_flag,created_at,updated_at,indexed_at)
select cid,ctype,uri,title,1,metadata,textindex,created_at,hidden_flag,created_at,updated_at,indexed_at
from concepts where ctype != 'noun';

update items set itype='concept' where itype='pnoun';

delete from tags  where ctype != 'noun';

alter table tags rename to tags_old;


alter table concepts rename to tags;

alter table concept_links rename to links;

insert into links (lid, in_id, out_id, ltype, weight, metadata) 
		   select oid, tag_id, item_id, otype, weight, metadata 
		   from occurrences where otype != 's';

delete from occurrences where otype != 's';

alter table tags change column cid tid varchar(255);

alter table occurrences change column tag_id tag_id integer(11);

alter table occurrences change column item_id item_id integer(11);

alter table sources change column itype itype varchar(255);

alter table rules change column itype itype varchar(255);

alter table items add column remark text;

#alter table items remove column type;

alter table items change column textindex textindex mediumtext;

update items set textindex = null;

