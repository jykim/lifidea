require 'test_helper'

class TestFileCollector < Test::Unit::TestCase
  def setup
    @src = Source.find_by_title("TREC Docs")
    @initial_file_count = 11
  end
    
  def test_file_collector
    Item.find_all_by_source_id(@src.id).each{|e|e.destroy}
    file_count = run_collector(:source=>@src.id, :force=>true)
    #assert(file_count, Item.find_all_by_itype(@src.itype).size)
    assert(file_count > 0, 'Something should be collected!')
  end
  
  def test_partial_collection
    run_collector(:source=>@src.id, :force=>true)
    sleep(1)
    @modified_file = File.join(@src.uri.gsub("file://",""), "d0.txt")
    #puts Rails.root, @modified_file
    FileUtils.touch(@modified_file)
    File.open(@modified_file, 'a'){|f|f.puts "modified!"}
    FileUtils.touch(@modified_file+".new")
    run_collector(:source=>@src.id, :force=>true)
    #debugger
    assert_equal(File.new(@modified_file).mtime, Item.find_by_uri(@modified_file).basetime, "modified file was collected")
    assert_equal(@initial_file_count+1, Item.find_all_by_source_id(@src.id).size,  "new file was collected")      
    File.unlink(@modified_file+".new")
  end
end