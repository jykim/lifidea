require 'test_helper'

class RubySearcherTest< ActiveSupport::TestCase  
  DOC_ROOT = "test/fixtures/docs/trec/"
  def setup()
    @fields = [:a,:b,:c] ; @field_dists = {} ; @docs = []
    
    @col_dist = (1..10).to_a.map_hash{|e|["t"+e.to_s, rand(10)]}.to_p
    @fields.each{|f|@field_dists[f] = ((1..10).to_a.map_hash{|e|['t'+f.to_s+e.to_s, rand(10)]}.to_p.smooth(0.1, @col_dist))}
    0.upto(10){|i|@docs[i] = create_doc(i, "d"+i.to_s)}
    @col = IR::Index.new(@docs, :cid=>'test', :fields=>@fields)
    #debug @col.flm.map{|k,v|[k,v.size]}.inspect
    @rs = RubySearcher.new(@col, :rule=>RubySearcher::RULE_DEF)
  end
  
  def create_doc(dno, did)
    flms = @field_dists.map_hash{|field,flm| [field, LanguageModel.new(flm.sample_pdist(100).join(" "))]}
    doc = IR::Document.new(dno, did , flms)
    File.open(DOC_ROOT+did+".txt", "w"){|f|f.puts doc.to_trectext}
    doc
  end
  
  def test_keyword_search()
    queries, results = [], []
    0.upto(0) do |i|
      #debugger
      queries[i] = '#combine(#wsum(0.6 t1.(a) 0.4 t1.(b)) #wsum(0.3 t2.(a) 0.7 t2.(b)))'#@docs[i].lm.p.sample(2).join(" ")
      #puts "Query : #{queries[i]}"
      #run_indri(queries[i])
      results[i] = @rs.search_by_keyword("t1 t2", :indri_query=>queries[i])
      #puts results[i].map{|e|e.join("\t")}.join("\n")
    end
  end
end