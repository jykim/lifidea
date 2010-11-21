require 'collector/collector_runner'

while($running) do
  $lgr.info "[collector.rb] Job started at #{Time.now}.\n"
  begin
    run_collector(:source=>ARGV[0])    
  rescue Exception => e
    $lgr.error "[collector.rb] Unhandled exception! #{e.inspect}\n"
  end
  $lgr.info "[collector.rb] Job finished at #{Time.now}.\n"
  sleep Source.sync_interval_default
end
