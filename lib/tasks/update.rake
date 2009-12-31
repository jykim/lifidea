require 'task_include'
#require 'collector/rss_collector_helper'
namespace :update do
  desc "Run tag/metadata extractor"
  task(:metadata => :environment) do
    Item.between($start_at, $end_at).each do |doc|
      next if ENV['itype'] && ENV['itype'] != doc.itype
      next if ENV['did'] && ENV['did'] != doc.did
      info "Processing #{doc}"
      doc.process_all()
      doc.save!
    end
  end
  
  desc "Update Concept ctype"
  task(:ctype => :environment) do
    Concept.all.each do |c|
      c.ctype ||= (c.title =~ /[A-Z]/ || c.title.utf8?)? "pnoun" : "noun"
      c.update_attributes(:ctype=>c.ctype)
    end
  end
end