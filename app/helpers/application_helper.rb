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
  
  def display_url(item)
    case item.uri
    when /\.(#{FileCollector::FILE_FORMAT_BINARY})$/
      "http://docs.google.com/viewer?url=#{url_encode(item.uri.strip)}&embedded=true"
    when /^http/
      if item.uri =~ /wikipedia/
        item.uri + "?printable=true"
      elsif item.itype == 'blog'
        url_for :action=>:show_content, :id=>item.id
      elsif item.itype == 'query'
        url_for :action=>:show_content, :id=>item.id, :layout=>nil
      else
        item.uri
      end
    else
      url_for :action=>:show_content, :id=>item.id, :layout=>nil
    end
  end
  
  def search_local(qtype, query, o={})
    $searcher = SolrSearcher.new
    @rank_list = $searcher.process_request(qtype, query, o)
  end
end
