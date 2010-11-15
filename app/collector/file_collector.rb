require 'ddl_include'

# Collect from Files
class FileCollector < Collector
  FILES_IN_BATCH = 50 # Max. no of files processsed at a time
  MAX_FILE_LENGTH = 5000
  FILE_FORMAT_TEXT = "html|xml|txt|tex"
  FILE_FORMAT_BINARY = "pdf|doc|ppt|xls|pptx|docx|xlsx"
  INDEX_FILE_FORMAT = [FILE_FORMAT_TEXT, FILE_FORMAT_BINARY].join("|")
  
  # Prepare Collection
  # - Keep the list of indexed files so that they won't be indexed again
  def open_source()
    if @docs_read.size > 0
      return 
    end
    debug "[open_source] start with #{@docs_read.size} docs"
    docs = Item.find_all_by_source_id(@src.id)
    @docs_read = docs.map_hash{|d|[d.uri, d.basetime]} unless docs.blank?
    debug "[FileCollector#open_source] #{@docs_read.size} docs read"
  end
  
  # @option o [String] :file_format  : fetch files of specific extension
  # @option o [Bool] :path_as_tag : use file path as tag 
  def read_from_source(o = {})
    data_path = @src.uri.gsub("file://","")
    puts "Working on #{@src.title} (#{data_path})"
    result = [] ; file_count = 0
    find_in_path(data_path, :recursion=>true) do |fp, fn|
      filename, mtime = fp.gsub(data_path+'/', ""), File.new(fp).mtime
      #puts filename
      #debugger
      next if (@docs_read[fp] && @docs_read[fp] >= mtime) || (File.dirname(fp) == /\./) ||
        (!@src.o[:trec] && !(File.extname(fp) =~ /\.(#{@src.o[:file_format] || INDEX_FILE_FORMAT})/i))
      break if file_count >= FILES_IN_BATCH ; file_count += 1
      debug "[FileCollector#read_from_source] Working on #{fp}" # #{@docs_read[fp]} >= #{mtime}
      if @src.o[:trec]
        content = IO.read(fp)
        did = content.find_tag("DOCNO")[0]
      elsif @src.o[:enron]
        content = IO.read(fp).find_tag("body")[0]
        did = content.find_tag("DOCNO")[0].strip
        title = content.find_tag("Subject")[0].strip
        metadata = {:from=>content.find_tag("From")[0].strip, 
          :to=>content.find_tag("To")[0].strip, :date=>content.find_tag("Date")[0].strip}
      elsif fp =~ /\.(FILE_FORMAT_TEXT)$/i
        debug "Content read for #{fp}"
        content = IO.read(fp)
      else
        content = nil
      end
      tag_list = File.dirname(filename).gsub("/", ",") if @src.o[:path_as_tag]      
      did  ||= filename ; title ||= filename
      result << {:itype=>@src.itype, :title=>title,:did=>did, :uri=>fp, :basetime=>mtime, :content=>content,
        :metadata=>(metadata || {:filename=>filename, :tag_list=>tag_list})}
      @docs_read[fp] = mtime
    end#find
    result
  end
  
  def close_source()
  end
end
