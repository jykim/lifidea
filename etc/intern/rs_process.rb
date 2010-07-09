load 'code/rs_library.rb'
require 'time'
$work_path = "B06_raw"

# Data for each query
files_all = Dir.entries($work_path)
$swap_id = 0
puts "File list read... (#{files_all.size} files)"
process_data(files_all, '20100617', '20100626', 'train')
process_data(files_all, '20100627', '20100705', 'test')
