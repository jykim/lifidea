require 'ddl_include'

class ICALCollector < Collector
  def read_from_source(o = {})
    feed_text = read_uri(@src)
    #debugger
    return nil if !@src.update_sync_content(feed_text) && !o[:force]
    cals = Icalendar.parse(feed_text)
    cals[0].events.map do |e|
     {:did=>(e.uid),  :itype=>@src.itype, :title=>e.summary, :content=>e.description, :uri=>e.url.to_s, 
       :metadata=>{:location=>e.location}, :basetime=>e.dtstart.to_time.in_time_zone(TIMEZONE)}
    end
  end
end
