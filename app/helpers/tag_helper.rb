module TagHelper
  # Create tags & links
  # @param titles [String] comma-separated string of tags
  # @param otype [String] type of occurrences
  def add_tags(titles, otype = "t")
    tags = sanitize_input(titles).map{|t|Item.find_or_create(t.strip, 'tag')}    
    #debug "[add_tags] titles = [#{titles}] otype = #{otype} (#{@tag_titles})"
    tags.each{|c|Link.find_or_create(self.id, c.id, otype)}
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
  def replace_tags(titles, otype = 't')
    clear_tags()
    add_tags(titles, otype)
  end
  
  # Read tag titles & update cache
  def tag_titles(otype = 't')
    if tags_saved
      tags_saved.split(",")
    else
      cond = otype ? {:links=>{:otype=>otype, :in_id=>id}} : {:links=>{:in_id=>id}}
      result = Item.all(:joins=>{:links=>:item}, :conditions=>cond).map(&:title)
      update_attributes!(:tags_saved=>result.join(","))
      result
    end
  end
  
  def tagged_with?(tag)
    tag_titles.split(",").include?(tag)
  end
end