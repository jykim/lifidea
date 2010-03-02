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
      @lm = o[:lm] || LanguageModel.create_by_merge(docs.map{|d|(d.lm)? d.lm.f : {}})
      @df = LanguageModel.create_by_merge(docs.map{|d|d.lm.f.map{|k,v|[k,1]}}).f if o[:init_df]
      @flm = {} ; @flm[:document] = @lm
      @fdf = {} ; @fdf[:document] = @df if o[:init_df]
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
