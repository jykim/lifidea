module TagHelper
  # Create tags & occurrences
  # @param titles [String] comma-separated string of tags
  # @param otype [String] type of occurrences
  def add_tags(titles, otype = "u")
    tags = sanitize_input(titles).map{|t|Tag.find_or_create(t.strip)}    
    #debug "[add_tags] titles = [#{titles}] otype = #{otype} (#{@tag_titles})"
    tags.each{|c|Occurrence.find_or_create(self.id, c.id, otype)}
    #@tag_titles = [tag_titles,titles].flatten.uniq.join(",")
    #update_attributes!(:tag_titles=>@tag_titles)
  end
  
  def sanitize_input(titles)
    if titles.class == String
      titles.split(",").find_all{|e|!e.blank?}
    else
      titles
    end
  end
  
  def clear_tags()
    occurrences.clear
  end
  
  # Replace existing tags with given tags
  def replace_tags(titles, otype = 'u')
    clear_tags()
    add_tags(titles, otype)
  end
  
  #def tag_titles()
  #  Tag.all(:joins=>{:occurrences=>:tag}, :conditions=>{:occurrences=>{:item_id=>id}}).map(&:title)
  #end
  
  def tag_titles(otype = nil)
    #read_attribute(:concept_titles)|| []
    cond = otype ? {:occurrences=>{:otype=>otype, :item_id=>id}} : {:occurrences=>{:item_id=>id}}
    Tag.all(:joins=>{:occurrences=>:tag}, :conditions=>cond).map(&:title)
  end
end