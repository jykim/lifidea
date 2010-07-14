load 'code/rs_library.rb'
require 'time'
$work_path = "B06_raw"

# Data for each query
files_all = Dir.entries($work_path)
$swap_id = 0
puts "File list read... (#{files_all.size} files)"
process_data(files_all, '20100617', '20100707', 'all')
#process_data(files_all, '20100617', '20100626', 'train')
#process_data(files_all, '20100627', '20100707', 'test')

# Weekly Data Processing
#process_data(files_all, '20100613', '20100619', 'w1')
#process_data(files_all, '20100620', '20100626', 'w2')
#process_data(files_all, '20100627', '20100703', 'w3')
#process_data(files_all, '20100704', '20100710', 'w4')
#process_data(files_all, '20100711', '20100717', 'w5')
