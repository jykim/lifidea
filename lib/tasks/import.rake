require 'ddl_include'
require 'active_record/fixtures'

namespace :import do
  desc "Import Rules from File"
  task(:rules => :environment) do
    read_csv(ENV['path'] || "#{RAILS_ROOT}/data/rules_jykim.csv").each do |r|
      #debugger
      next unless r[:rid]
      rule = Rule.find_or_initialize_by_rid(r[:rid])
      rule.update_attributes(r)
    end
  end
  
  desc "Import Items from File"
  task(:items => :environment) do
    read_csv(ENV['path'] || "#{RAILS_ROOT}/data/items_#$renv.csv").each_with_index do |e,i|
      #debugger
      next unless e[:id]
      begin
        item = Item.find(e[:id])
        case e[:itype]
        when 'concept'
          did = e[:title].to_id
        else
          did = e[:did]
        end
        item.replace_tags([e[:tags],e[:more_tags]].join(","))
        e.delete(:tags) ; e.delete(:more_tags)
        item.update_attributes! e.merge(:did=>did, :modified_flag=>true)
        puts "#{i}th item processed..." if i % 50 == 0 && i > 0
      rescue Exception => e
        error "Error occured in #{e.inspect}"
      end
    end
  end
  
  desc "Import Links from File"
  task(:links => :environment) do
    read_csv(ENV['path'] || read_recent_file_in("#{RAILS_ROOT}/data/links", :filter=>/#{ENV['RAILS_ENV']}/)).each do |c|
      #debugger
      puts c.inspect
      next unless c[:in_id]
      Link.find_or_create(c[:in_id].to_i, c[:out_id].to_i, c[:ltype], :weight=>c[:weight])
    end
  end
  
  desc "Import Documents from File"
  task(:docs => :environment) do
    read_csv(ENV['path'] || "#{RAILS_ROOT}/data/docs_#$renv.csv").each_with_index do |e,i|
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
      fixture_path = ENV['path'] || "#{RAILS_ROOT}/test/fixtures"
      begin
        Fixtures.create_fixtures(fixture_path, ENV['name'])        
      rescue Exception => e
        debug e
      end
    else
    end
  end
  
end