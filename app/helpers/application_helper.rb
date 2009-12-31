# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  #include TagsHelper

  def clickable_tag_list(tag_list)
    out = []
    tag_list.each do |tag|
      out << link_to(tag.name, tag_path(tag))
    end
    out.join(', ')
  end
  
  def get_cur_env
     " / #{ENV["RAILS_ENV"]}" unless ENV["RAILS_ENV"] == 'production'
  end
end
