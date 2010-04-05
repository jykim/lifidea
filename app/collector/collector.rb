#require 'ddl_include' CHANGED : avoid including reference to the file which includes this file
# Abstract collector framework
require 'timeout.rb'
require 'hpricot'

class Collector #< ApplicationController
  #include CollectorHelper
  attr_accessor :src
  TIMEOUT = 5
  
  def initialize(source)
    @src = source
    @docs_read = {} # List of documents already collected
  end
  
  def collect(o = {})
    return 0 if !@src.sync_now? && !o[:force]
    error "[run_collector] Working on #{@src.title}"
    open_source()
    count = save_docs(read_from_source(o), o)
    close_source()
    @src.last_sync_at = Time.now
    count
  end
  
  # - filter docs with same content
  # - update @docs_read hash
  def filter_existing_docs(docs)
    result = []
    docs.each do |d|
      next if !d
      doc_hash = d.inspect.to_md5
      if @docs_read[d[:did]] != doc_hash
        result << d
        @docs_read[d[:did]] = doc_hash
      #else
        #debug "[filter_existing_docs] document #{d[:did]} already read!"
      end
    end
    result
  end
  
  # Save given documents to database
  # = Minimizing documents to be saved
  # 
  def save_docs(docs, o = {})
    return 0 if !docs || docs.size == 0
    saved_count = 0
    docs = filter_existing_docs(docs) if @src.itype != 'file' && !o[:force]
    return 0 if !docs || docs.size == 0
    docs_db = Item.find_by_dids(docs.map{|d|d[:did]}).map_hash{|d|[d[:did],d]}
    debug "[save_docs] #{docs_db.size}/#{docs.size} docs found from db"
    docs.each do |doc|
      #debug "[save_docs] Processing #{doc[:did]}"
      next if @src.o[:insert_only] && docs_db[doc[:did]]
      doc_db = docs_db[doc[:did]] || Item.new
      next if doc_db.modified_flag || !doc_db.changed_content?(doc)
      begin
        #type = (doc[:itype] =~ /query/)? 'Query' : 'Document'
        doc_db.update_attributes(doc.merge(:source_id=>@src.id))
        #debug "[save_docs] filter : #{@src.filter.inspect}"
        if @src.filter && @src.filter.size > 0 && doc_db.validate_by_condition(@src.filter)
          warn "[collect] Document #{doc_db.did} filtered out!"
          doc_db.destroy
        else
          doc_db.add_tags(doc[:metadata][:tag_list], "s") unless doc[:metadata][:tag_list].blank?
          doc_db.process_all
          saved_count += 1
          doc_db.save
        end
      rescue Exception => e
        error "[save_docs] "+[e.inspect,e.backtrace].join("\n")
      end
    end
    #puts "[save_docs] saved_count = #{saved_count}"
    saved_count
  end
  
  # (stub) Read new(modified) documents from the source
  #  - return only as many documents as can be processed at once
  # @return [Array<Hash>] list of document attributes
  def read_from_source(o = {})
    []
  end
  
  def open_source()
    
  end
  
  def close_source()
    nil
  end
    
  def read_uri(src)
    uri = case src.uri
    when /^webcal/
      src.uri.gsub("webcal://","http://")
    else
      src.uri
    end
    
    if src.o[:id]
      open_opt = {:ssl_verify => false,  :http_basic_authentication=>[src.o[:id], src.o[:password]]}
    else
      open_opt = {}
    end
    open(uri, open_opt){|f|return f.read}
  end
end
