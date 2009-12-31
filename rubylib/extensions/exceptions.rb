class DataError < Exception
  def initialize(msg)
    error "[DataError] #{msg}"
  end
end

class ExternalError < Exception
  def initialize(msg)
    error "[ExternalError] #{msg}"
  end
end

#class ArgumentError < Exception
#  def initialize(msg)
#    err "[ArgumentError] #{msg}"
#  end
#end