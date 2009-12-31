require 'test_helper'
require 'app/extractor/extractor_runner'
require 'batch_job_handler'

class StatExtractorTest < ActiveSupport::TestCase
  def setup
    @rules = Rule.stat_rules
    @se = StatExtractor.new
    #Time.zone = "UTC"
  end
  
  test "select documents within the period" do
    basedate = Time.parse("2007-07-10")
    assert_equal(86400 , @se.period_end_at(basedate,"day") - @se.period_start_at(basedate,"day"))
    
    # Two documents should be found under the following range
    @se.select_docs_by(basedate, "day", "all", {}){|itype,docs|assert_equal(2, docs.size)}
    @se.select_docs_by(basedate+86399, "day", "all", {}){|itype,docs|assert_equal(2, docs.size)}

    # No document should be found 
    @se.select_docs_by(basedate-1, "day", "all", {}){|itype,docs|flunk}
    @se.select_docs_by(basedate-86400, "day", "all", {}){|itype,docs|flunk}
    @se.select_docs_by(basedate+86400, "day", "all", {}){|itype,docs|flunk}
  end
  
  def test_stat_period
    start_at, end_at = Time.parse("2009-06-01"), Time.parse("2009-07-31")
    #debugger
    create_stat_for(start_at.to_s, end_at.to_s)
    cond = {:basedate=>(start_at..end_at)}
    assert_in_delta(Stat.get_wavg(/^cal_score_avg_month/, cond), Stat.get_wavg(/^cal_score_avg_week/, cond) , 0.001, 
      "Statistics values of avg(month) == avg(week)" )
    assert_in_delta(Stat.get_wavg(/^cal_score_avg_month/, cond), Stat.get_wavg(/^cal_score_avg_day/, cond) , 0.001, 
      "avg(month) == avg(day)" )
  end
  
  def test_calendar_stat
    run_collector(:itype=>'calendar', :force=>true)
    #debugger
    # Select document by tags
    @se.select_docs_by('2009-08-01', "month", "all", {:tag=>/fun/}){|itype,docs|assert_equal(1, docs.size)}
    create_stat_for("2009-09-01","2009-09-10")
    # Calculate schedule for tagged schedules
    assert_equal(1.5, Stat.get_wavg(/^cal_high_scored_avg_month/), "tagged schedules are selected correctly")    
  end
  
  def test_log_stat
    @dj = DailyJob.new("test")
    run_collector(:itype=>"app_log", :file_name=>'app_log.txt', :force=>true)
    @se.select_docs_by(Time.parse("2009-06-05"), "day", "app_log", {}){|itype,docs|assert_equal(60, docs.size)}
    create_stat_for("2009-06-05","2009-06-10")
    @dj.move_files_for_collection
  end
end
  