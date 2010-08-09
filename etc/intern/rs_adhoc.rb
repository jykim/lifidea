
def add_date_col(file)
	data = IO.read(file).split("\n")
	date = file.scan(/\d{8}/)[0]
	dates = ['CreateTime',[[date[0..3],date[4..5],date[6..7]].join("-")]*(data.size-1)].flatten
	File.open(file+'.new','w'){|f|
		data.each_with_index{|e,i|
			f.puts e+"\t#{dates[i]}"}}
end

add_date_col "queries_chk.txt.google.20100709.res"
add_date_col "queries_chk.txt.google.20100710.res"
add_date_col "queries_chk.txt.google.20100711.res"
add_date_col "queries_chk.txt.google.20100712.res"
add_date_col "queries_chk.txt.google.20100713.res"
add_date_col "queries_chk.txt.google.20100714.res"
add_date_col "queries_chk.txt.google.20100715.res"
add_date_col "queries_chk.txt.yahoo.20100709.res"
add_date_col "queries_chk.txt.yahoo.20100710.res"
add_date_col "queries_chk.txt.yahoo.20100711.res"
add_date_col "queries_chk.txt.yahoo.20100712.res"
add_date_col "queries_chk.txt.yahoo.20100713.res"
add_date_col "queries_chk.txt.yahoo.20100714.res"
add_date_col "queries_chk.txt.yahoo.20100715.res"
add_date_col "queries_chk.txt.yahoo.20100714.res"
add_date_col "queries_chk.txt.yahoo.20100715.res"
