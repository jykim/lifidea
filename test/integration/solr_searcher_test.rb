require 'test_helper'
require 'rake'
ENV['all'] = 'true'
require 'task_include'
Ddl::Application.load_tasks

class SolrSearcherTest < ActiveSupport::TestCase
  def setup()
    @ss = SolrSearcher.new
    #{}`rake sunspot:solr:reindex RAILS_ENV=test`
    @target = Item.find_by_did('cal0')
    @target_con = Item.find_by_did('qry1')
    @query_word = @target.title.scan(/\w+/)
    Rake::Task['sunspot:solr:reindex'].execute  
  end
  
  def test_calc_df()
    #debugger
    assert(@ss.calc_df(@query_word[0]) > @ss.calc_df(@query_word[0], @query_word[1..-1]), 
      'Inclusion of more word should decrease count')
    assert(@ss.calc_df(@query_word[0]) == @ss.calc_df(@query_word[0], @query_word[0]), 
      "Inclusion of the same word should not decrease count")
    assert_equal(0, @ss.calc_df(@query_word[0], "", @query_word[0]), 
      "Exclusion of the same word should make the count zero")
  end
  
  # Test keyword / similarity search
  def test_keyword_search()
    #debugger
    assert(@ss.search_by_keyword(TEXT_DUMMY, :raw=>true).total > 0)
    
    result_docs = @ss.search_by_keyword(@query_word)
    #debugger
    assert(result_docs.size > 0)
    assert(1, result_docs.find_all{|e|e[:id] == @target.id})
  end
  
  def test_similarity_search()
    #result = @ss.search_by_item(@target.id, 'con')
    #result.each{|e|debug e.inspect}
    #assert(result.size == 0)
    
    result = @ss.search_by_item(@target.id, 'doc')
    result.each{|e|debug e.inspect}
    assert(result.size > 0, 
      "At least one item find for #{@target}(#{@target.id})")
  end
  
  def test_concept_similarity_search()
    result = @ss.search_by_item(@target_con.id, 'con')
    result.each{|e|debug e.inspect}
    assert(result.size > 0, 
      "At least one item find for #{@target_con}(#{@target_con.id})")    
  end
  
  # 
  def test_search_with_context()
    result = @ss.search_by_item(@target.id, 'doc').map{|e|{:id=>e[:id], :score=>e[:score]}}
    @cv = ContextVector.new ; @cv.clear
    
    result_with_context = @ss.search_by_item_with_context(@target.id, 'doc')
    assert_equal(result, result_with_context, 
      "Search result should not change with the empty context vector")
      
    @ss.build_context_vector()
  end
end