


# OCCURRENCES


delete from occurrences where tag_id not in 
  (select id from concepts where hidden_flag != '1' and modified_flag = '1');

delete from occurrences where item_id not in 
  (select id from documents where hidden_flag != '1');

update occurrences set oid=concat(item_id,'_',tag_id,'_',otype);



# SOURCES

insert into sources select * from ddl_production.sources;

update concepts set ctype='pnoun' , modified_flag=1;
