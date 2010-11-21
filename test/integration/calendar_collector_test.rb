require 'test_helper'

class CalendarCollectorTest < ActionController::TestCase
  def setup
    @src = Source.find_by_title("New Calendar")
    run_collector(:source=>@src.id, :force=>true)
    #assert_equal(30, Item.find_all_by_source_id(@src.id).size)
  end

  def test_filter
    #Source w/ Filter
    Item.find_all_by_itype(@src.itype).each{|d|d.destroy}
    $collectors[@src.id].src.update_attributes!(:filter=>{:title=>/PIM/})
    #debug "[test] filter : #{@src.filter.inspect}"
    run_collector(:source=>@src.id, :force=>true)
    assert_equal(20, Item.find_all_by_source_id(@src.id).size)
  end
  
  def test_metadata
    scored_docs = Item.find_all_by_source_id(@src.id).find_all{|d|d.m[:score]}
    scored_tag_docs = Item.find_all_by_source_id(@src.id).find_all{|d|d.tagged_with?("scored")}
    tag_scored_tag_docs = Item.find_all_by_source_id(@src.id).find_all{|d|d.tagged_with?("tag_scored")}
    #debugger
    #assert_equal(7+6, scored_docs.size, "Metadata extraction from markup" )
    #assert_equal(0, (scored_docs - scored_tag_docs).size, "Tag extraction from metadata")
    #assert_equal(0, (scored_tag_docs - tag_scored_tag_docs).size, "Tag extraction from tag")
  end
end
