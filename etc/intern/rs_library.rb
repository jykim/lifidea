load 'rubylib_include.rb'
C_QID, C_RANK, C_URL, C_DS, C_NDS, C_HRS = 0, 9, 10, 12, 13, 14

def	process_data( files_all, start_date, end_date, batch_id)
	puts "== Processing #{batch_id} =="
	output_path = "B06_#{batch_id}"
	Dir.mkdir(output_path) if !File.exists?(output_path)
	i = 0
	files_all.find_all{|e|e=~/\d+\_(\d+)T\d+/ ; $1 && $1 >= start_date && $1 <= end_date }.sort.group_by{|e|e.split(/[_\.]/)[0]}.each do |qid,files|
		next if files.size < ((Time.parse(end_date) - Time::parse(start_date))/86400).to_i + 1
		qfs = {} # additional query features
		#next if $qid && $qid != qid
		
		# Read files
		values = files.map{|file| IO.read(File.join($work_path, file)).split(/[\n\r]+/).map{|e|e.split("\t")}.each{|e|e[2] = e[2].split(" ")[0].gsub('/','_')}}
		v_docs = values.map{|e|e.map{|e2|[e2[C_URL], e2[C_HRS]]}} # filter [URL, Scores] only
		
		# Pairwise Correlation
		#taus1 = v_docs.map_cons(2).map{|e|e[0].kendalls_tau e[1]}
		overlaps1 = v_docs.map_cons(2).map{|e|(e[0][0..0] & e[1][0..0]).size}
		taus3 = v_docs.map_cons(2).map{|e|e[0].kendalls_tau e[1], 2}
		overlaps3 = v_docs.map_cons(2).map{|e|(e[0][0..2] & e[1][0..2]).size/3.0}
		taus5 = v_docs.map_cons(2).map{|e|e[0].kendalls_tau e[1], 4}
		overlaps5 = v_docs.map_cons(2).map{|e|(e[0][0..4] & e[1][0..4]).size/5.0}
		overlaps = v_docs.map_cons(2).map{|e|(e[0] & e[1]).size/10.0}

		# Cumulative Correlation
		cTaus = v_docs[1..-1].map{|e|v_docs[0].kendalls_tau e}
		cOverlaps = v_docs[1..-1].map{|e|(v_docs[0] & e).size/10.0}
		
		# Doc-level Result (change)
		qfs['ins'], qfs['swap'] = [0], [0]
		File.open(File.join(output_path, "result_cdocs_#{qid}.tsv"),'w'){|f|
			values.each_with_index{|value,j| # for each pair of days
				next if j == 0
				ins = (v_docs[j-1] - v_docs[j])
				ins.each{|d|
					result = values[j-1].find{|e|e[C_URL] == d[0]}.dup ; result[2] = value[0][2] # Update the date of deleted document
					f.puts [result, 'del', ''].flatten.join("\t")}
				(v_docs[j] - v_docs[j-1]).each{|d|f.puts [value.find{|e|e[C_URL] == d[0]}, 'add', ''].flatten.join("\t")}
				
				pref_a, pref_b, common_docs = v_docs[j-1].to_comb, v_docs[j].to_comb, (v_docs[j] & v_docs[j-1])
				swaps = (pref_b - pref_a).find_all{|e|common_docs.include?(e[0]) && common_docs.include?(e[1])}
				
				swaps.find_all{|e|e[0][1].to_i > e[1][1].to_i}.
					each{|d|f.puts extract_swap_info(values[j-1].find{|e|e[C_URL] == d[0][0]}, values[j-1].find{|e|e[C_URL] == d[1][0]}, value.find{|e|e[C_URL] == d[0][0]}, value.find{|e|e[C_URL] == d[1][0]}, 'swapP')}
				swaps.find_all{|e|e[0][1].to_i < e[1][1].to_i}.
					each{|d|f.puts extract_swap_info(values[j-1].find{|e|e[C_URL] == d[0][0]}, values[j-1].find{|e|e[C_URL] == d[1][0]}, value.find{|e|e[C_URL] == d[0][0]}, value.find{|e|e[C_URL] == d[1][0]}, 'swapN')}
				swaps.find_all{|e|e[0][1].to_i == e[1][1].to_i}.
					each{|d|f.puts extract_swap_info(values[j-1].find{|e|e[C_URL] == d[0][0]}, values[j-1].find{|e|e[C_URL] == d[1][0]}, value.find{|e|e[C_URL] == d[0][0]}, value.find{|e|e[C_URL] == d[1][0]}, 'swapU')}
				qfs['ins'] << ins.size ; qfs['swap'] <<  swaps.size
			}
		}
		
		# Doc-level Result (stable docs)
		File.open(File.join(output_path, "result_sdocs_#{qid}.tsv"),'w'){|f|
			stable_docs = v_docs.inject(v_docs[0]){|result,e| result & e }.map{|e|e[0]}
			qfs['stable'] = stable_docs.size
			results = values.map{|value|value.find_all{|e|stable_docs.include?(e[C_URL])}}
			#results.collapse.sort_by{|e|e[C_URL]}.each{|e|f.puts e.join("\t")}
			results.collapse.group_by{|e|e[C_URL]}.each{|k,v| f.puts [v[0][C_QID], v.map{|e|e[C_RANK].to_i}.range, v.map{|e|e[C_DS].to_f}.range, v.map{|e|e[C_RANK].to_i}.var, v.map{|e|e[C_DS].to_f}.var, k].join("\t")}
		}
		
		# Daily Result
		File.open(File.join(output_path, "result_daily_#{qid}.tsv"),'w'){|f|
			prev_dcg1, prev_dcg3, prev_dcg5 = 0, 0, 0
			f.puts ['QID', 'Date', 
					'NDCG1', 'dNDCG1', 'cNDCG1', 'dScore1' ,'drScr1',
					'NDCG3', 'dNDCG3', 'cNDCG3', 'dScore3' ,'drScr3',
					'NDCG5', 'dNDCG5', 'cNDCG5', 'dScore5' ,'drScr5',
					'Overlap1','Overlap3','Overlap5',"Tau3","Tau5",
					"cTau",'cOvrlap','cIns','cSwap','cStable','Query'].join("\t")
			values.each_with_index{|value,j|
				cur_dcg1, cur_dcg3, cur_dcg5 = value[0][6].to_f.r3, value[0][7].to_f.r3, value[0][8].to_f.r3
				f.puts [value[0][0], value[0][2], 
					cur_dcg1, (j==0)? 0 : (cur_dcg1 - prev_dcg1), (j==0)? 0 : (cur_dcg1 - values[0][0][3].to_f.r3), value[1][C_URL].to_f.r3, value[1][11].to_f.r3, 
					cur_dcg3, (j==0)? 0 : (cur_dcg3 - prev_dcg3), (j==0)? 0 : (cur_dcg3 - values[0][0][4].to_f.r3), value[3][C_URL].to_f.r3, value[3][11].to_f.r3, 
					cur_dcg5, (j==0)? 0 : (cur_dcg5 - prev_dcg5), (j==0)? 0 : (cur_dcg5 - values[0][0][5].to_f.r3), value[5][C_URL].to_f.r3, value[5][11].to_f.r3, 
					(j==0)? 1 : overlaps1[j-1], (j==0)? 1 : overlaps3[j-1].r3, (j==0)? 1 : overlaps5[j-1].r3, (j==0)? 1 : taus3[j-1].r3, (j==0)? 1 : taus5[j-1].r3, 
					(j==0)? 1 : cTaus[j-1].r3, (j==0)? 1 : cOverlaps[j-1].r3, qfs['ins'][j], qfs['swap'][j], (j==0)? 1 : overlaps[j-1], value[0][1] ].join("\t")
				prev_dcg1, prev_dcg3, prev_dcg5 = cur_dcg1, cur_dcg3, cur_dcg5
			}
		}
		
		
		# Aggregate Result
		values_r5, values_r3, values_r1 = values.map{|e|e[5]}, values.map{|e|e[3]}, values.map{|e|e[1]}

		File.open(File.join(output_path, "result_all_#{qid}.tsv"),'w'){|f|
			f.puts [
				values[0][0][0], values[0][0][1].split(/\s+/).size, overlaps1.avg, overlaps3.avg, overlaps5.avg, taus3.avg, taus5.avg, qfs['ins'], qfs['swap'], qfs['stable'], 
				values_r1.map{|e|e[C_DS].to_f}.avg, values_r1.map{|e|e[C_NDS].to_f}.avg, values_r5.map{|e|e[3].to_f}.avg, values_r5.map{|e|e[3].to_f}.var, values_r5.map{|e|e[3].to_f}.range, values_r5.map{|e|e[6].to_f}.avg, values_r5.map{|e|e[6].to_f}.var, values_r5.map{|e|e[6].to_f}.range, 
				values_r3.map{|e|e[C_DS].to_f}.avg, values_r3.map{|e|e[C_NDS].to_f}.avg, values_r5.map{|e|e[4].to_f}.avg, values_r5.map{|e|e[4].to_f}.var, values_r5.map{|e|e[4].to_f}.range, values_r5.map{|e|e[7].to_f}.avg, values_r5.map{|e|e[7].to_f}.var, values_r5.map{|e|e[7].to_f}.range, 
				values_r5.map{|e|e[C_DS].to_f}.avg, values_r5.map{|e|e[C_NDS].to_f}.avg, values_r5.map{|e|e[5].to_f}.avg, values_r5.map{|e|e[5].to_f}.var, values_r5.map{|e|e[5].to_f}.range, values_r5.map{|e|e[8].to_f}.avg, values_r5.map{|e|e[8].to_f}.var, values_r5.map{|e|e[8].to_f}.range, values[0][0][1]].join("\t")
		}
		
		i += 1
		puts "Processed #{i}th query" if i % 1000 == 0
	end
end

def	extract_swap_info(doc1a, doc2a, doc1, doc2, swap_type)
	$swap_id += 1
	[[doc1a, swap_type, 'S'+$swap_id.to_s].flatten.join("\t"), [doc2a, swap_type, 'S'+$swap_id.to_s].flatten.join("\t"), 
	 [doc1, swap_type,  'S'+$swap_id.to_s].flatten.join("\t"), [doc2, swap_type,  'S'+$swap_id.to_s].flatten.join("\t")]
end
