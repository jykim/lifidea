require 'test_helper'
require 'app/batch_job_handler'

class TestLogCollector < Test::Unit::TestCase
  def setup
    @src = Source.find_by_itype("app_log")
    run_collector(:itype=>@src.itype, :file_name=>'app_log.txt', :force=>true)
    @dj = DailyJob.new("test")
  end
  
  def test_app_log_collector
    assert_equal(60, Item.find_all_by_source_id(@src.id).size)
    @dj.move_files_for_collection
  end
end