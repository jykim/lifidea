require 'ddl_include'
require 'active_record/fixtures'

namespace :import do
  desc "Import Rules from File"
  task(:rules => :environment) do
    read_csv(ENV['path'] || "#{Rails.root}/data/rules_jykim.csv").each do |r|
      #debugger
      next unless r[:rid]
      rule = Rule.find_or_initialize_by_rid(r[:rid])
      rule.update_attributes(r)
    end
  end
  
  desc "Import Items from File"
  task(:items => :environment) do
    read_csv(ENV['path'] || "#{Rails.root}/data/items_#$renv.csv").each_with_index do |e,i|
      #debugger
      next unless e[:id]
      begin
        did = case e[:itype]
        when 'concept'
          e[:title].to_id
        else
          e[:did]
        end
        item = Item.find_or_create(did, e[:itype])
        item.replace_tags([e[:tags],e[:more_tags]].join(","))
        e.delete(:tags) ; e.delete(:more_tags)
        case e[:itype]
        when 'concept' 
          item.update_attributes! e.merge(:did=>did, :modified_flag=>true)
        else
          e.delete(:did)
          item.update_attributes! e.merge(:modified_flag=>true)
        end
        puts "#{i}th item processed..." if i % 50 == 0 && i > 0
      rescue Interrupt => e
        puts 'Break by user'
        exit
      rescue Exception => e
        error "Error occured in #{e.inspect}"
      end
    end
  end
  
  desc "Import Links from File"
  task(:links => :environment) do
    read_csv(ENV['path'] || read_recent_file_in("#{Rails.root}/data/links", :filter=>/#{ENV['RAILS_ENV']}/)).each do |c|
      #debugger
      puts c.inspect
      next unless c[:in_id]
      Link.find_or_create(c[:in_id].to_i, c[:out_id].to_i, c[:ltype], :weight=>c[:weight])
    end
  end
  
  #IO.read('data/doc_topics3.txt').split("\n").map_hash{|l|e=l.split(",");[e[0],e[1..-1]]}
  desc "Import Topics from File"
  task(:topics => :environment) do
    IO.read(ENV['path']).split("\n").each do |l|
      e = l.split(",")
      item = Item.find(e[0].scan(/doc_(\d+)_/)[0][0])
      next if !item
      item.update_attributes!(:remark=>e[1..-1].join(","))
      puts "updated!"
    end
  end
  
  desc "Import Documents from File"
  task(:docs => :environment) do
    read_csv(ENV['path'] || "#{Rails.root}/data/docs_#$renv.csv").each_with_index do |e,i|
      #debugger
      next unless e[:id]
      begin
        doc = Item.find(e[:id])
        doc.update_attributes! e.merge(:modified_flag=>true)
        puts "#{i}th doc processed..." if i % 50 == 0 && i > 0
      rescue Exception => e
        error "Error occured in #{e.inspect}"
      end
    end
  end
  
  task(:tables => :environment) do
    if ENV['name']
      fixture_path = ENV['path'] || "#{Rails.root}/test/fixtures"
      begin
        Fixtures.create_fixtures(fixture_path, ENV['name'])        
      rescue Exception => e
        debug e
      end
    else
    end
  end
  
end
