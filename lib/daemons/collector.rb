require File.dirname(__FILE__) + "/../../lib/daemon_include.rb"
require File.dirname(__FILE__) + "/../../app/collector/collector_runner.rb"

while($running) do
  $lgr.info "[collector.rb] Job started at #{Time.now}.\n"
  begin
  #debug ARGV.inspect
    run_collector(:source=>ARGV[0])    
  rescue Exception => e
    $lgr.error "[collector.rb] Unhandled exception! #{e.inspect}\n"
  end
  $lgr.info "[collector.rb] Job finished at #{Time.now}.\n"
  sleep Source.sync_interval_default
end