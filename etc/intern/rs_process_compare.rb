load 'code/rs_library.rb'
require 'time'
$work_path = "B06_raw_goog"
files_all = Dir.entries($work_path)
$swap_id = 0
puts "File list read... (#{files_all.size} files)"
process_data(files_all, '20100709', '20100716', 'goog')

$work_path = "B06_raw_yaho"
files_all = Dir.entries($work_path)
$swap_id = 0
puts "File list read... (#{files_all.size} files)"
process_data(files_all, '20100709', '20100716', 'yaho')

