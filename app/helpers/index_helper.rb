module IndexHelper
  def index_fields
    {:title=>title, :uri=>uri, :content=>content}. #, :tag=>tag_titles.join(",")
      merge(metadata).find_all{|k,v|v}.to_hash
  end
  
  def create_index(content = nil)
    #puts "Tag : #{index_fields[:tag_titles].inspect}\n#{index_fields.map_hash{|k,v|[k, LanguageModel.new(v)]}}"
    #debugger if index_fields[:tag_titles].blank?
    index_doc = IR::Document.new(id, did, content || index_fields.map_hash{|k,v|[k, LanguageModel.new(v)]})
    write_attribute(:textindex, index_doc.to_yaml)
    write_attribute(:indexed_at, Time.now.in_time_zone(TIMEZONE))
    save!
  end
  
  def get_index(o = {})
    #puts "[get_index] #{id}"
    begin
      @index ||= if textindex
        IR::Document.create_from_yaml(textindex)
        #features = {:basetime=>basetime, :occur_count=>$clf.read_sum('o',id), :click_count=>$clf.read_sum('c',id)}
        #IR::Document.create_from_yaml(textindex, o.merge(:features=>features))
      else
        IR::Document.new(id, did, index_fields.values.join(" "), o)
      end
    rescue Exception => e
      error "[get_index] Unknown error in #{id}", e
      []
    end    
  end
end