require 'test_helper'

class SearcherTest < ActiveSupport::TestCase
  INDRI_ROOT = "/Users/lifidea/app/indri-2.10/bin/"
  DOC_ROOT = "test/fixtures/docs/trec/"

  def setup()
    @fields = [:a,:b,:c] ; @field_dists = {} ; @docs = []
    
    @col_dist = (1..10).to_a.map_hash{|e|["t"+e.to_s, rand(10)]}.to_p
    @fields.each{|f|@field_dists[f] = ((1..10).to_a.map_hash{|e|['t'+f.to_s+e.to_s, rand(10)]}.to_p.smooth(0.1, @col_dist))}
    
    0.upto(10){|i|@docs[i] = create_doc(i, "d"+i.to_s)}
    @col = IR::Index.new(@docs, :cid=>'test', :fields=>@fields)
    debug @col.flm.map{|k,v|[k,v.size]}.inspect
    @searcher = Searcher.new(:rule=>Searcher::RULE_DEF)
    @searcher.cols = [@col]
  end
  
  def create_doc(dno, did)
    flms = @field_dists.map_hash{|field,flm| [field, LanguageModel.new(flm.sample(100).join(" "))]}
    doc = IR::Document.new(dno, did , flms)
    File.open(DOC_ROOT+did+".txt", "w"){|f|f.puts doc.to_trectext}
    doc
  end
  
  # list{a,b} : [[did1, score1], ...]
  #def rank_equivalent?(lista, listb)
  #  ranka = get_rank(lista)
  #end
  #
  #def get_rank(list)
  #  rank = 1
  #  list.map_with_index{|e,i|[e,(i > 0 && list[i][1] > list[i-1][1])? (rank += 1) : rank]}
  #end
  
  def test_with_indri()
    return if !File.exist?(INDRI_ROOT)
    queries, results = [], []
    0.upto(0) do |i|
      #debugger
      queries[i] = '#combine(#wsum(0.6 t1.(a) 0.4 t1.(b)) #wsum(0.3 t2.(a) 0.7 t2.(b)))'#@docs[i].lm.p.sample(2).join(" ")
      puts "Query : #{queries[i]}"
      #run_indri(queries[i])
      results[i] = @searcher.search("t1 t2", :indri_query=>queries[i])
      puts results[i].map{|e|e.join("\t")}.join("\n")
    end
  end
  
  def test_searcher()
    
  end

  def run_indri(query, rule = Searcher::RULE_DEF)
    `rm -rf #{RAILS_ROOT}/test/fixtures/index`
    `#{INDRI_ROOT}/buildindex #{RAILS_ROOT}/test/fixtures/index_docs.xml`
    puts `#{INDRI_ROOT}/runquery -index=#{RAILS_ROOT}/test/fixtures/index -rule='#{rule}' -query='#{query}'`
  end
end
