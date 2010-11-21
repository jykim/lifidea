require 'test_helper'
require 'rake'

class SolrSearcherTest < ActiveSupport::TestCase
  def setup()
    @searcher = SolrSearcher.new
    `rake sunspot:solr:reindex RAILS_ENV=test`
    @target = Item.find_by_did('cal0')
    #Rake::Task['sunspot:reindex'].execute  
  end
  
  # Test keyword / similarity search
  def test_keyword_search()
    query_word = @target.title.scan(/\w+/)
    
    result = @searcher.search_by_keyword(query_word[0..1].join(" "))
    result.each{|e|debug e[:item].title}
    assert(result.size > 0)

  end
  
  def test_similarity_search()
    result = @searcher.search_by_item(@target.id, 'con')
    result.each{|e|debug e.inspect}
    assert(result.size == 0)
    
    result = @searcher.search_by_item(@target.id, 'doc')
    result.each{|e|debug e.inspect}
    assert(result.size > 0)
  end
end