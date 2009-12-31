require 'ddl_include'
require 'extractor/extractor_runner'

class DailyJob
  attr_accessor :jid
  def initialize(jid, basedate = nil)
    @jid = jid
    @basedate = basedate
  end
  
  def perform()
    begin
      move_files_for_collection()
      create_stat()      
    rescue Exception => e
      return false
    end
    true
  end
  
  def move_files_for_collection()
    Source.active.each do |e|
      if e.o[:copy_daily_from]
        find_in_path(e.o[:copy_daily_from]) do |fp, fn|
          File.move(fp, e.uri.gsub('file://',''))
        end
      end
    end
  end
  
  def create_stat()
    create_stat_for((@basedate-1).to_s, (@basedate-1).to_s)
  end
end

def enque_daily_job()
  today = Time.now.to_date ; jid = "DJ_#{today}"
  date_last_job = SysConfig.find_by_title("DATE_LAST_BATCH_JOB")
  if Time.now.hour >= get_config("HOUR_DAYBREAK").to_i && Time.now.at_beginning_of_day > date_last_job.content.to_utc #!DelayedJobs.find_by_jid(jid)
    Delayed::Job.enqueue DailyJob.new(jid, today)
    DelayedJobs.last.update_attributes(:jid=>jid)
    date_last_job.update_attributes(:content=>today.to_s(:db))
  end
end

