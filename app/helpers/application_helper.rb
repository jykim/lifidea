module ApplicationHelper
  def clickable_tag_list(tag_list)
    out = []
    tag_list.each do |tag|
      out << link_to(tag.name, tag_path(tag))
    end
    out.join(', ')
  end
  
  def get_cur_env
     " / #{Rails.env}" unless Rails.env.production?
  end
  
  def f(arg, o={})
    case arg.class.to_s
    when "String"
      arg[0..o[:limit]] if o[:limit]
    when "NilClass"
      ""
    end
  end
end
