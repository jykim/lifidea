require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
$running = true
Signal.trap("TERM") do 
  $running = false
end
