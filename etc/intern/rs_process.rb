load 'code/rs_library.rb'
require 'time'
$work_path = "B06_raw"

# Data for each query
files_all = Dir.entries($work_path)
$swap_id = 0
puts "File list read... (#{files_all.size} files)"
process_data(files_all, '20100612', '20100709', 'all')
process_data(files_all, '20100612', '20100625', 'train')
process_data(files_all, '20100626', '20100709', 'test')

# Weekly Data Processing
process_data(files_all, '20100612', '20100618', 'w1')
process_data(files_all, '20100619', '20100625', 'w2')
process_data(files_all, '20100626', '20100702', 'w3')
process_data(files_all, '20100703', '20100709', 'w4')
#process_data(files_all, '20100710', '20100717', 'w5')
