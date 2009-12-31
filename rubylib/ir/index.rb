module IR
  # Index is like a index
  # - used by Searcher, Indexer and InferenceNetwork
  # - contains document list and term statistics
  # - can be initialized from file or 
  class Index
    #include CollectionScoreHelper
    attr_accessor :cid, :docs, :dhno, :dhid
    attr_accessor :lm, :df, :fdf, :flm #collection statistics

    # @param [Array<IR::Document>] docs : documents 
    # @option o [Array] :fields accept the list of fields
    def initialize(docs = nil, o={})
      @cid = o[:cid]
      @docs = docs || []
      @dhno = docs.map_hash{|d|[d.dno, d]}
      @dhid = docs.map_hash{|d|[d.did, d]}
      @docs.each{|d|d.col = self}
      
      #@idf = {} # cache of IDF
      @lm = o[:lm]   || LanguageModel.create_by_merge(docs.map{|d|(d.lm)? d.lm.f : {}})
      @df = LanguageModel.create_by_merge(docs.map{|d|d.lm.f.map{|k,v|[k,1]}}).f if o[:init_df]
      @flm = {} ; @flm[:document] = @lm
      @fdf = {} ; @flm[:document] = @df if o[:init_df]
      if o[:fields]
        o[:fields].each do |field|
          @flm[field] = LanguageModel.create_by_merge(docs.map{|d|(d.flm[field])? d.flm[field].f : {}})
          @fdf[field] = LanguageModel.create_by_merge(docs.map{|d|(d.flm[field])? d.flm[field].f.map{|k,v|[k,1]} : {}}).f if o[:init_df]
          #@flm[field] = LanguageModel.create_by_merge(docs.map{|d|d.flm[field].f})
          #@fdf[field] = LanguageModel.create_by_merge(docs.map{|d|d.flm[field].f.map{|k,v|[k,1]}}).f
        end
      end
      #puts @fdf.inspect
      info "Collection #{@cid} (#{o[:fields].join(" ")}) loaded (#{docs.size} docs)"
    end
    
    # Search based on similarity
    # - Find target document
    # - Evaluate similarity query
    def find_similar(dno, o={})
      query = @dhno[dno]
      return nil unless query

      weights = Vector.elements(o[:weights] || [1]*Searcher::FEATURES.size)
      result = []
      @docs.each do |d|
        next if d.dno == query.dno
        #puts "[find_similar] Scoring #{d.id}"
        #puts "#{d.feature_vector(query).inspect}*#{weights.inspect}"
        begin
          score = d.feature_vector(query).inner_product(weights)#w[:content] * d.cosim(query) + w[:time] * d.tsim(query)          
        rescue Exception => e
          puts "Error in #{d.feature_vector(query).inspect}*#{weights.inspect}"
        end        
        result << [d.dno, score]
      end
      #debugger
      if ENV['rank'] == 'random'
        result.sample(50)
      else
        result.sort_by{|e|e[1]}.reverse[0..50]
      end
    end
    
    # Log pairwise preference training data into file
    # @param[String] query : query_id|clicked_item_id|skipped_item_id|...
    def log_preference(dnos, o={})
      dnos = dnos.split("|").map{|e|e.to_i}
      #puts "[log_preference] dnos=#{dnos.inspect}"
      query = @dhno[dnos[0]]
      return nil unless query

      result = []
      $last_query_no += 1
      dnos[1..-1].each_with_index do |dno,i|
        pref = (i == 0)? 2 : 1
        begin
          raise ArgumentError, "already clicked concept!" if pref == 1 && $clf.read('c', dno, query.dno) > 0
          features = @dhno[dno].feature_vector(query).to_a.map_with_index{|e,j|[j+1,fp(e)].join(":")}
        rescue Exception => e
          error "[log_preference] error in #{$last_query_no}th query : #{dno}"
          if pref == 2 #clicked concept missing!
            return
          else
            next
          end
        end        
        result << [pref,"qid:#{$last_query_no}"].concat(features).concat(["# #{query.dno} -> #{dno} (#{query.did} / #{dh[dno].did})"])
      end
      if !o[:export_mode]
        $clf.increment('c', dnos[0], dnos[1])
        SysConfig.find_by_title("LAST_QUERY_NO").update_attributes(:content=>$last_query_no) 
      end
      $f_li.puts result.map{|e|e.join(" ")}.join("\n") if result.size > 1
      $f_li.flush
    end

    # Used by Indexer
    def to_yaml()
      result = [@cid,@lm.f]
      result << @docs.map{|d|d.to_yaml}
      result.to_yaml
    end

    def self.create_from_yaml(yaml_str)
      yaml_obj = YAML.load(yaml_str)
      docs = yaml_obj[2].map{|e|Document.create_from_yaml(e)}
      lm = LanguageModel.new(yaml_obj[1])
      result = Index.new(docs, :lm=>lm, :cid=>yaml_obj[0])
      puts "[create_from_yaml] Index initialized (#{result.lm.size} / #{result.docs.map{|d|d.lm.size}.sum})"
      #debugger
    end

    def add_document(doc)
      @docs << doc
      @lm.update(doc.lm.f)
    end
  end
end
