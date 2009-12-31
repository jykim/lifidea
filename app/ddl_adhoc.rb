require 'ddl_include'
require 'rexml/document'



=begin
  AD-HOC Data Processing 
=end
Item.find_all_by_source("https://www.google.com/history/?output=rss").each do |d|
  d.update_attributes(:tag=>nil, :itype=>d[:tag].gsub(" ","_")) if d[:tag]
end

nil

# Tag clean-up for web history
Item.find_all_by_source("webhistory").each do |d|
  d.update_attributes(:itype=>d[:itype].gsub(" ","_"), :tag=>nil, :source=>"https://www.google.com/history/?output=rss")
end


# 
Fact.find_all_by_ftype("app_log").find_all{|e|!e.c[:start_time]}.each{|e|e.delete}

docs = Item.find_all_by_itype('app_log').find_all{|e|!e.m[:start_time]}

Item.valid.all.each do |d|
  if !d.index || !d.index.lm
    puts "lm is null for #{d.id}"
    d.write_attribute(:textindex, nil)
    d.save!    
  end
end

Item.all.each{|d|d.update_attributes(:metadata=>d.metadata.merge(:type=>d.itype))}
