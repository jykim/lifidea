require 'ddl_include'
#require 'hpricot'

# 
# = Indexer
# 
class Indexer
  INDEX_FIELD_LIMIT = 20000
  TIMEOUT = 5
  attr_accessor :ch
  TIKA_PATH = File.join(RAILS_ROOT, "vendor", "tika-0.3-standalone.jar")
  
  # Load concept lists in ConceptHash
  def initialize()
    #@ch = Concept.init_concept_hash()
    #Indexer.initialize_dict()
    @ch = Indexer.init_concept_hash
  end
  
  def self.init_concept_hash
    ch = ConceptHash.new
    Item.valid.concepts.each{|c| ch.put_concepts(c.id , c.title) }    
    ch
  end
  
  # Check for target item
  # - condition : new(updated) items not indexed yet
  def find_target_items
    last_job_at = Time.parse(get_config("TIME_LAST_INDEX_JOB") || Time.now.yesterday.to_s)
    debug "last_job_at = #{last_job_at}"
    Item.valid.all(:conditions=>["indexed_at is null or (updated_at > ? and updated_at > indexed_at)",last_job_at])
  end
  
  
  # Index a set of items
  # @param [Bool] o[:download] : decide whether to read & parse files or not
  def index_item_set(all_items, o={})
    puts "Indexing #{all_items.size} items..." ; cur_docs = 0
    #Searcher.load_features() if !$clf
    all_items.in_groups_of(FileCollector::FILES_IN_BATCH) do |batch|
      items = batch.find_all{|d|d}

      #read contents
      if o[:download]
        $idx.read_files(items.find_all{|d|d.itype =~ /file/ && !d.content})
        items.each{|d| $idx.read_webpage(d) if d.itype =~ /webpage|concept/ && d.uri =~ /^http/}
      end
      #run indexing
      items.each{|d|$idx.index_item(d)}
      cur_docs += batch.size
      puts "#{cur_docs} / #{all_items.size} finished"
    end
  end
    
  # Index target item
  # - build term vector
  # - extract concepts
  # - extract concept links (occurrences)
  def index_item(item)
    #debug "[index_item] Indexing #{item.title}(#{item.id})"

    if item.content.blank?
      item.update_attributes! :content=>item.link_items[0..25].find_all{|e|e.document?}.map{|e|e.to_s(true)}.join("\n")
    end
    # Extract concept occurrences
    concepts = @ch.find_concepts(item.index_fields.values.join(" ")).map{|c|c[0]}
    #debug "[index_item] concepts in  #{item.title} = #{concepts.uniq.inspect}" if concepts.size > 0
    concepts.group_by{|c|c}.each{|k,v| Link.find_or_create(item.id, k, "e", :weight=>1) }
    
    # Extract concept co-occurrence
    # - count increases whenever the item is re-indexed!
    concepts.uniq.to_comb.each do |pair|
      Link.find_or_create(pair[0],pair[1],"o", :add=>1)
    end
  end
  
  # Parse target docs with Apache Tika and fill title & contents
  # @param [Array<Document>] docs : array of items
  def read_files(docs)
    return if docs.size == 0
    tika_cmd = "java -jar #{TIKA_PATH} #{docs.map{|e|"\""+e.uri+"\""}.join(" ")}"
    debug "#{docs.size} / #{tika_cmd}"
    contents = `#{tika_cmd}`
    warn "[read_files] Command #{tika_cmd} failed!" if contents.blank? || contents =~ /^Exception/
    #debugger
    begin
      Hpricot(contents).search("/html").each_with_index do |content,i|
        title = content.search("title")[0].inner_text
        #title = content.search("p")[0].inner_text if title.blank?
        body  = content.search("body").inner_text
        docs[i].write_attribute(:title,  (title.blank?)? docs[i].uri : title )
        docs[i].write_attribute(:content, body[0..FileCollector::MAX_FILE_LENGTH] )
      end
    rescue Exception => e
      #print(e)
      error "[read_files] Error #{e.inspect}"
    end
  end
  
  # Read webpage content from URI
  # 
  def read_webpage(doc)
    return if doc.uri =~ /\.(pdf|ps|eps|doc|ppt|xls|mov|avi|jpg|png|jpeg|gif|tif)$/i
    begin
      timeout(TIMEOUT) do
        info "[read_webpage] Downloading #{doc.uri}"
        open(doc.uri) do |f|
          #puts "Content : #{f.read}"
          doc.write_attribute(:content,clear_webpage(f.read))
        end
        #debugger
      end
    rescue TimeoutError => e
      warn "Timeout w/ #{doc.uri}"
    rescue Exception => e
      #print(e)
      error "[read_webpage] Other Error! #{e.inspect}"
    end
  end
  
  
  # Index target concept
  # - build term vector
  #def index_concept(con)
  #  #debugger
  #  index_doc = IR::Document.new(con.id, con.cid, {
  #    :title => LanguageModel.new(con.title), 
  #    :content => LanguageModel.new(con.document_lists('e').map{|d|(d.index.lm)? d.index.lm.f : {}}.merge_by_sum)})
  #  con.write_attribute(:textindex, index_doc.to_yaml)
  #  con.write_attribute(:indexed_at, Time.now.in_time_zone(TIMEZONE))
  #  con.save!
  #end
  
  # IR::Index all files from path
  #def index_path(path, o={}) # yield IR::Document
  #  Dir.entries(path).each do |fn|
  #    fp = File.join(path, fn)
  #    next if ['.','..'].include?(fn) || File.directory?(fp)
  #    doc_file = IO.read(fp)
  #    did = doc_file.find_tag('DOCNO')[0].strip
  #    #debugger
  #    yield IR::Document.new(did, doc_file, o)
  #  end
  #end
end
