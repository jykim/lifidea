require File.dirname(__FILE__) + "/ddl_include.rb"

$running = true
Signal.trap("TERM") do 
  $running = false
end
