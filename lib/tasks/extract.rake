require 'task_include'
require 'extractor/extractor_runner'

namespace :extract do
  desc "Run stat extractor"
  task(:stats => :environment) do
    create_stat_for($start_at, $end_at)
  end
  
  desc "Run document link extractor"
  task(:doc_links => :environment) do
    dle = DocumentLinkExtractor.new
    docs1 = Item.between($start_at, $end_at).find_all_by_itype("calendar")
    docs2 = Item.between($start_at, $end_at).find_all_by_itype("email")
    info "docs1 : #{docs1.size} / docs2 : #{docs2.size}"
    result_count = (docs1.size+docs2.size)
    doc_links = dle.get_links_btw(docs1, docs2)
    #debugger
    DL_TYPES.each{|type| dle.insert_links(doc_links, type, :topk=>result_count, :batch=>ENV['batch'])}
  end
  
  desc "Run concept extractor"
  task(:concepts => :environment) do
    ce = ConceptExtractor.new
    docs1 = Item.between($start_at, $end_at).find_all_by_itype("calendar")
    docs2 = Item.between($start_at, $end_at).find_all_by_itype("email")
    ce.extract_people_from_email(docs2)
    #ce.extract_from(docs2)
    #ce.extract_from(docs1)
  end
end