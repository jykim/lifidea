class RubyIndexer
  def initialize(args)
    
  end
  
  def index_item(item, o = {})
    
    if item.content
       item.create_index
    else
      #debug "[index_item] using content from #{item.link_items[0..9].map{|e|e.id}.inspect}"
      content = item.link_items[0..25].map{|d|d.get_index.get_flm([:title,:uri,:tag]).f}.merge_by_sum
      #puts content.inspect
      item.create_index(:title=>LanguageModel.new(item.title), :tag=>LanguageModel.new(item.tag_titles.join(",")), 
      :content => LanguageModel.new(content), :uri => LanguageModel.new(item.uri))
    end
  end
end
