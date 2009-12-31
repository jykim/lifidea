require 'timeout.rb'
require 'hpricot'
module CollectorHelper
  TIMEOUT = 5
  
  def read_uri(src)
    uri = case src.uri
    when /^webcal/
      src.uri.gsub("webcal://","http://")
    else
      src.uri
    end
    
    if src.o[:id]
      open_opt = {:ssl_verify => false,  :http_basic_authentication=>[src.o[:id], src.o[:password]]}
    else
      open_opt = {}
    end
    open(uri, open_opt){|f|return f.read}
  end
  
  def clear_webpage(html)
    return "" if !html
    hpricot = Hpricot(html)
    hpricot.search("script").remove
    hpricot.search("link").remove
    hpricot.search("meta").remove
    hpricot.search("style").remove
    hpricot.inner_text.gsub(/\s{5,}/,"\n")
  end
end