require 'test_helper'
require 'app/batch_job_handler'

class BatchJobTest < ActiveSupport::TestCase
  def setup
    @basedate = Time.parse("2009-07-02").to_date
    @dj = DailyJob.new("test", @basedate)
  end
  
  # @todo easier matching of date column ?
  def test_daily_jobs
    @dj.create_stat
    assert_equal 2, Stat.all(:conditions=>{:basedate=>(@basedate-1).to_time.in_time_zone}).size
  end
end
