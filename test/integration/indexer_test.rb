require 'test_helper'

class IndexerTest < ActiveSupport::TestCase
  def setup()
    @src = Source.find_by_title("Other Docs")
    @initial_file_count = 14
    run_collector(:source=>@src.id, :force=>true)
  end
  
  def test_indexer
    @idx = Indexer.new
    #Document.all(:conditions=>["itype != ?", "document"]).
    #  each{|d|d.update_attributes!(:updated_at=>Time.now.advance(:days => -30))}
    #debugger
    docs = @idx.find_target_items
    file_docs = docs.find_all{|d|d.source.id == @src.id}
    #assert_equal(9, docs.size)
    assert_equal(2, file_docs.size)
    @idx.read_files(file_docs)
    docs.each{|d|@idx.index_item(d)}
    docs.each{|d|assert(d.textindex)}
  end
end
