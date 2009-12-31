DL_TYPES = ['content','person','event','pubtime','caltime'].map{|e|e.to_sym}

class DocumentLinkExtractor
  # @deprecated
  def self.get_pubdate_links(docs, o={})
    o[:window] ||= 300
    result = []
    docs.sort_by{|d|d.basetime}.each_with_index do |d,i|
      j = 1
      while docs[i+j] && (time_gap = docs[i+j].basetime - d.basetime) > 0 && time_gap <= o[:window]
        if block_given?
          yield d, docs[i+j], time_gap
        else
          result << [d, docs[i+j], time_gap]
        end
        j += 1
      end
    end
    result
  end
  
  # Get Content Similarity Links
  # :tw : term weighting used
  def get_links_btw(docs1, docs2, o={})
    result = []
    debug "[get_links_btw] docs1 = #{docs1.size} / docs2 = #{docs2.size}"
    col = IR::Index.new([docs1,docs2].flatten.map{|d|d.index}, :init_df=>true)
    docs1.each do |d1|
      docs2.each do |d2|
        next if d1.id >= d2.id
        begin
          raise ArgumentError, "Textindex is missing for #{d1}/#{d2}" if !d1.textindex || !d2.textindex
          
          m = {}
          #d1.index.lm.f.cosim(d2.index.lm.f) # LM-based similarity
          m[:content] = d1.index.cosim(d2.index)
          m[:person] = (d1.concepts.find_all{|c|c.ctype=='person'} & d2.concepts.find_all{|c|c.ctype=='person'}).size
          m[:event] = (d1.concepts.find_all{|c|c.ctype=='event'} & d2.concepts.find_all{|c|c.ctype=='event'}).size
          m[:pubtime] = transform_feature(d1.basetime - d2.basetime, :time)
          m[:caltime] = transform_feature(d1.m[:start_at] - d2.basetime, :time) if d1.m[:start_at]
          raise ArgumentError, "[get_links_btw] cosim:NaN for #{d1}-#{d2}" if m[:content].nan?
          result << [d1, d2, m]
          #debug result[-1].inspect
          #debugger
        rescue Exception => e
          error("[get_links_btw] Unknown error",e)
        end
      end
    end
    result
  end
  
  def transform_feature(value, type)
    case type
    when :time
      value_n = 1 / Math.log((value / 3600).abs+1)
      (value_n > 1)? 1 : value_n
    end
  end
  
  # Insert DocumentLink instance into database
  # - only for ones with high attribute values
  # @param [Array<doc1, doc2, metadata>] doc_links 
  def insert_links(doc_links, order, o = {})
    o[:topk] ||= 100
    doc_links.sort_by{|e|e[2][order]}.reverse[0..o[:topk]].each{|e| DocumentLink.find_or_create(e, o)}
  end
end