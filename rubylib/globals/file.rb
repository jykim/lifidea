require 'find'

# Read from CSV
# - assume more than two lines of file, with the header in the first line
# @return [Array<Hash<Symbol,String>>] : 
def read_csv(filename, o = {})
  #header = o[:header] || true
  content = FasterCSV.parse(IO.read(filename).to_lf, :row_sep => "\n")
  if o[:output] == :array
    content[1..-1]
  else
    content[1..-1].map{|c|content[0].map_hash_with_index{|h,i|[h.downcase.to_sym, c[i]]}}
  end
end

# Write to CSV
# @param :summary
def write_csv(filename, content, o = {})
  mode = o[:mode] || 'w'
  if o[:summary]
    content << o[:summary].map_with_index{|e,i|
      case e.class.to_s
      when "String"
        e
      when "Symbol"
        content.map{|l|l[i]}.find_all{|e2|e2.respond_to?(:abs)}.send(e) if e
      end
    }
  end
  if o[:normalize]
    o[:normalize].each_with_index{|e,i|
      next if !e
      case e
      when :minmax
        max, min = content.map{|l|l[i]}.max, content.map{|l|l[i]}.min
        next if max == min
        content.each{|l|l[i] = (l[i] - min) / (max - min)}
      end
    }
  end
  content = [o[:header]].concat(content) if o[:header]
  File.open(filename, mode){|f|f.puts content.map{|e|e.to_csv}.join("")}
end

def print_csv(csvdata)
  csvdata.each{|row|p row}
  nil
end

def file_write(file_name , var , o = {})
  path = o[:path] || PATH_DATA
  fullpath = File.join(path,file_name)
  mode = o[:mode] || 'w'
  if o[:protect] && File.exist?(fullpath)
    return nil
  end
  File.open( fullpath  , mode){|file| file.puts var}    
end

def file_read(file , o = {})
  path = o[:path] || PATH_DATA
  IO.read(File.join(path,file))
end

def file_backup(file)
  ret = `cp #{file} #{file}.bak`
  puts "[file_backup] return = #{ret}"
  ret
end

def file_dump( dump_name , var )
  File.open( dump_name , 'w') {|f| Marshal.dump(var , f) }
end

def file_load( dump_name )
  File.open( dump_name , 'r') {|f| return Marshal.load(f) }
end

# Find files in given path
# @option <Bool> :recursion whether to find in subfolder (default : false)
# @option <RegEx> :filter find only files matching filter
def find_in_path(path, o={})
  result = []
  if o[:recursion]
    Find.find(path) do |fp|
      fn = File.basename(fp)
      next if !FileTest.file?(fp) || fn =~ /^\./ || (o[:filter] && !(o[:filter] =~ fn))
      #puts "#{fp} started..."
      if block_given?
        yield fp,fn
      else
        result << fp
      end
    end
  else
    Dir.entries(path).each do |fn|
      fp = File.join(path, fn)
      next if ['.','..'].include?(fn) || File.directory?(fp) || (o[:filter] && !(o[:filter] =~ fn))
      if block_given?
        yield fp,fn
      else
        result << fp
      end
    end
  end
  result
end

# Perform batch rename
# @example
#  batch_rename('.',/candidate([0-9]+)/,"c\\1", :commit=>true)
def batch_rename(path , ptn_fr, ptn_to, o={})
  find_in_path(path, o.merge(:filter=>ptn_fr)) do |fp,fn|
    puts cmd = "mv #{fp} #{File.join(File.dirname(fp), fn.gsub(ptn_fr,ptn_to))}"
    `#{cmd}` if o[:commit]
  end
  nil
end

def batch_edit(path , o = {})
  new_path = o[:new_path] || 'tmp'
  begin
    Dir.mkdir( new_path ) if !File.exist?( new_path ) &&  !o[:skip_output]
    find_in_path(path, o) do |fp,fn|
      new_file = File.join(new_path , fn)
      while File.exists?(new_file)
        #puts "[batch_edit] Duplicated Filename : #{new_file}"
        if (no = new_file.scan(/\[([0-9]+)\]/)).size == 0
          new_file = new_file[0..-5] + '[1].xml'            
        else
          new_file = new_file.gsub!("[#{no[-1][0]}]" , "[#{no[-1][0].to_i+1}]")
        end
      end
      result = yield new_file, IO.read(fp)
      File.open(new_file, 'w'){|f| f.puts result} if !o[:skip_output]
      puts "#{fn} finished..."
    end
  rescue SystemCallError
    $stderr.print "[batch_edit] IO failed: " + $! + "\n"
  end
end