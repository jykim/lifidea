module IR
  # Document in IR::Indexed Form
  class Document
    TEXT_SIZE = 4096
    MAX_FEATURE_VALUE = Math.log(10+1)
    MAX_FEATURE_VALUE2 = Math.log(100+1)
    
    attr_accessor :dno, :did, :col
    attr_accessor :text, :lm, :flm, :fts
    # 
    def initialize(dno, did, input, o = {})
      @dno, @did = dno, did
      @fields = :document
      @col = o[:col]
      @fts = o[:features]
      @flm = {}
      
      @cosim = {} ; @tsim = {}
      @tfidf = {} ; @tfidf_size = {}
      raise ArgumentError, "Field :document not allowed!" if o[:fields] && o[:fields].include?(:document)
      case input.class.to_s
      when 'String'
        #@text = input[0..TEXT_SIZE]
        if o[:fields]
          @fields.concat( o[:fields])
          o[:fields].each{|f|
            ftext = input.find_tag(f)[0]
            warn "No content for #{did}:#{f}"if !ftext
            @flm[f] = LanguageModel.new(ftext)
            #debug "#{f}: #{@flm[f].size}"
          }
          @lm = LanguageModel.create_by_merge(@flm.map{|k,v|v.f})
        else
          @lm = LanguageModel.new(input)
        end
      when 'Hash' #{field1=>flm1,field2=>flm2,...}
        @flm = input
        @lm = LanguageModel.create_by_merge(@flm.map{|k,v|v.f})
        raise DataError unless @flm.map{|k,v|v.size}.sum == @lm.size
      end
      @flm[:document] = @lm
    end
    
    def get_flm(fields = nil)
      (!fields)? @lm : LanguageModel.create_by_merge(@flm.find_all{|k,v|fields.include?(k)}.map{|e|e[1].f})
    end
    
    def to_s
      "#{dno} #{did}"
    end
    
    def blank?
      @lm.f.blank?
    end
    
    def cosim(doc, field = :document)
      @cosim[doc.dno] = {} if !@cosim[doc.dno]
      return @cosim[doc.dno][field] if @cosim[doc.dno][field]
      result = tfidf(field).product(doc.tfidf(field)).sum{|k,v|v} / 
               (tfidf_size(field) * doc.tfidf_size(field))
      @cosim[doc.dno][field] =  (result.nan?)? 0 : result
      #tfidf.cosim(doc.tfidf)
    end
    
    def tfidf(field = :document)
      @tfidf[field] ||= @flm[field].tfidf(@col.df,@col.docs.size)
    end
    
    def tfidf_size(field = :document)
      @tfidf_size[field] ||= tfidf(field).normalize
    end
    
    def tsim(doc)
      return @tsim[doc.dno] if @tsim[doc.dno]
      value_sec = @fts[:basetime] - doc.fts[:basetime]
      value_n = 1 / Math.log((value_sec / 3600).abs+1)
      @tsim[doc.dno] = (value_n > 1)? 1 : value_n
    end
    
    def normalize(value, threshold = MAX_FEATURE_VALUE)
      new_value = Math.log(value+1) / threshold
      (new_value > 1)? 1 : new_value
    end
    
    def feature_vector(doc)
      result = [cosim(doc,:title), cosim(doc,:content), cosim(doc,:uri), cosim(doc,:tag), tsim(doc)]
      result << normalize($clf.read('o', @dno, doc.dno))
      result << $clf.read('t', @dno, doc.dno)
      result << normalize($clf.read_sum('o', @dno), MAX_FEATURE_VALUE2)
      puts "[feature_vector] #{@did} = #{result.inspect}"
      Vector.elements(result)
    end
    
    def to_trectext()
      template = ERB.new(IO.read("rubylib/ir/template/doc_trectext.xml.erb"))
      template.result(binding)
    end
    
    def to_yaml()
      result = [dno, did]
      result << @flm.map_hash{|k,v|[k,v.f] if k != :document}
      #result << @fts
      begin
        result.to_yaml        
      rescue Exception => e
        error "[Document::to_yaml] Unhandled Exceptions ", e
        nil
      end
    end
    
    def self.create_from_yaml(yaml_str, o = {})
      #debugger
      begin
        yaml_obj = YAML.load(yaml_str)
      rescue Exception => e
        error "[create_from_yaml] error", e
        return nil
      end
      #features = yaml_obj[3] if yaml_obj[3] && yaml_obj[3].class == Hash
      index_content = yaml_obj[2].map_hash{|k,v|[k,LanguageModel.new(v)]} if yaml_obj[2] && yaml_obj[2].class == Hash
      Document.new(yaml_obj[0], yaml_obj[1], index_content, o)
    end
  end
end