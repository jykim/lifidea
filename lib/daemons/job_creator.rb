#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

require File.dirname(__FILE__) + "/../../config/environment"

$running = true
Signal.trap("TERM") do 
  $running = false
end


#while($running) do
#  
#  $lgr.error "Job started at #{Time.now}.\n"
#
#  #load File.dirname(__FILE__) + "/../../app/collector/rss_collector.rb"
#  
#  sleep 300
#end
load File.dirname(__FILE__) + "/../../app/batch_job_handler.rb"

while($running) do
  enque_daily_job()
  sleep(300)  
end
