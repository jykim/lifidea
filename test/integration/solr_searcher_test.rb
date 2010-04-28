require 'test_helper'
require 'rake'

class SolrSearcherTest < ActiveSupport::TestCase
  def setup()
    @searcher = SolrSearcher.new
    #`rake sunspot:reindex RAILS_ENV=test`
    #Rake::Task['sunspot:reindex'].execute  
  end
  
  # Test keyword / similarity search
  def test_search()
    target = Item.find_by_did('cal0')
    query_word = target.title.scan(/\w+/)
    
    result = @searcher.search_by_keyword(query_word[0..1].join(" "))
    result.each{|e|debug e[0].title}
    assert(result.size > 0)

    result = @searcher.search_by_item(target.id, 'con')
    result.each{|e|debug e.inspect}
    assert(result.size > 0)
    
    result = @searcher.search_by_item(target.id, 'doc')
    result.each{|e|debug e.inspect}
    assert(result.size > 0)
  end
end