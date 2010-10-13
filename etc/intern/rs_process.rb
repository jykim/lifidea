load 'code/rs_library.rb'

# Data for each query
$work_path = "B06_raw_all"
files_all = Dir.entries($work_path) ; nil
puts "File list read... (#{files_all.size} files)"

# Weekly Data Processing
process_data(files_all, '20100611', '20100625', 'train2', :skip_sdocs=>true, 
	:work_date=>['20100611','20100613','20100615','20100617','20100619','20100621','20100623','20100625'])
process_data(files_all, '20100611', '20100625', 'train2', :skip_sdocs=>true, 
	:work_date=>['20100611','20100614','20100617','20100620','20100623'])

process_data(files_all, '20100611', '20100709', 'beg2end', :work_date=>['20100611','20100709'])

process_data(files_all, '20100611', '20100618', 'w1')
process_data(files_all, '20100618', '20100625', 'w2')
process_data(files_all, '20100625', '20100702', 'w3')
process_data(files_all, '20100702', '20100709', 'w4')

process_data(files_all, '20100611', '20100625', 'train')
process_data(files_all, '20100625', '20100709', 'test')

process_data(files_all, '20100611', '20100709', 'all')


build_output_files('w1')
build_output_files('w2')
build_output_files('w3')
build_output_files('w4')
                   
build_output_files('train')
build_output_files('test')
                   
build_output_files('all')




# Test Data (20 queries)
$work_path = "B06_raw_test"
files_all = Dir.entries($work_path) ; nil
process_data(files_all, '20100611', '20100618', 'w1t')

#process_data(files_all, '20100604', '20100604', 'test_ruby') ; nil

# Generate Top10 Rank list
# - used for swap re-ranking experiments
['20100611','20100612','20100613','20100614','20100615','20100616','20100617','20100618'].each{|e| build_topk_file(e, 'B06_raw_all')}
['20100619','20100620','20100621','20100622','20100623','20100624','20100625'].each{|e| build_topk_file(e, 'B06_raw_all')}
['20100626','20100627','20100628','20100629','20100630','20100701','20100702'].each{|e| build_topk_file(e, 'B06_raw_all')}
['20100703','20100704','20100705','20100706','20100707','20100708','20100709'].each{|e| build_topk_file(e, 'B06_raw_all')}

# Comparison of Stability for 3 Search Engines
$work_path = "B06_raw_goog"
files_all = Dir.entries($work_path) ; nil
process_data(files_all, '20100801', '20100817', 'goog', :short=>true, :skip_sdocs=>true, :skip_qurl_features=>true)
$work_path = "B06_raw_yaho"                           
files_all = Dir.entries($work_path) ; nil             
process_data(files_all, '20100801', '20100817', 'yaho', :short=>true, :skip_sdocs=>true, :skip_qurl_features=>true)
$work_path = "B06_raw_bing"                           
files_all = Dir.entries($work_path) ; nil             
process_data(files_all, '20100801', '20100817', 'bing', :short=>true, :skip_sdocs=>true, :skip_qurl_features=>true)
