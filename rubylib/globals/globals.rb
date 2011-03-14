
def str2time(str)
  if str.class == Time then return str end
  Time.mktime(*ParseDate::parsedate(str,true))
end

def fp(obj)
  case obj.class.to_s
  when "Float"
    obj.r3
  else
    obj
  end
end