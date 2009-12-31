class Array
  def in_groups_of(number, fill_with = nil, &block)
     require 'enumerator'
     collection = dup
     collection << fill_with until collection.size.modulo(number).zero? unless fill_with == false
     grouped_collection = [] unless block_given?
     collection.each_slice(number) do |group|
       block_given? ? yield(group) : grouped_collection << group
     end
     grouped_collection unless block_given?
   end

   # Divide the array into one or more subarrays based on a delimiting +value+
   # or the result of an optional block.
   #
   # ex.
   #
   #   [1, 2, 3, 4, 5].split(3)                # => [[1, 2], [4, 5]]
   #   (1..10).to_a.split { |i| i % 3 == 0 }   # => [[1, 2], [4, 5], [7, 8], [10]]
   def split(value = nil, &block)
     block ||= Proc.new { |e| e == value }
     inject([[]]) do |results, element|
       if block.call(element)
         results << []
       else
         results.last << element
       end
       results
     end
   end
end

module Enumerable
  # Collect an enumerable into sets, grouped by the result of a block. Useful,
  # for example, for grouping records by date.
  #
  # e.g. 
  #
  #   latest_transcripts.group_by(&:day).each do |day, transcripts| 
  #     p "#{day} -> #{transcripts.map(&:class) * ', '}"
  #   end
  #   "2006-03-01 -> Transcript"
  #   "2006-02-28 -> Transcript"
  #   "2006-02-27 -> Transcript, Transcript"
  #   "2006-02-26 -> Transcript, Transcript"
  #   "2006-02-25 -> Transcript"
  #   "2006-02-24 -> Transcript, Transcript"
  #   "2006-02-23 -> Transcript"
  def group_by
    inject({}) do |groups, element|
      (groups[yield(element)] ||= []) << element
      groups
    end
  end if RUBY_VERSION < '1.9'

  # Calculates a sum from the elements. Examples:
  #
  #  payments.sum { |p| p.price * p.tax_rate }
  #  payments.sum(&:price)
  #
  # This is instead of payments.inject { |sum, p| sum + p.price }
  #
  # Also calculates sums without the use of a block:
  #   [5, 15, 10].sum # => 30
  #
  # The default identity (sum of an empty list) is zero. 
  # However, you can override this default:
  #
  # [].sum(Payment.new(0)) { |i| i.amount } # => Payment.new(0)
  #
  def sum(identity = 0, &block)
    return identity unless size > 0
    if block_given?
      map(&block).sum
    else
      inject { |sum, element| sum + element }
    end
  end

  # Convert an enumerable to a hash. Examples:
  # 
  #   people.index_by(&:login)
  #     => { "nextangle" => <Person ...>, "chade-" => <Person ...>, ...}
  #   people.index_by { |person| "#{person.first_name} #{person.last_name}" }
  #     => { "Chade- Fowlersburg-e" => <Person ...>, "David Heinemeier Hansson" => <Person ...>, ...}
  # 
  def index_by
    inject({}) do |accum, elem|
      accum[yield(elem)] = elem
      accum
    end
  end
end

class String 
  # Does the string start with the specified +prefix+?
  def starts_with?(prefix)
    prefix = prefix.to_s
    self[0, prefix.length] == prefix
  end

  # Does the string end with the specified +suffix+?
  def ends_with?(suffix)
    suffix = suffix.to_s
    self[-suffix.length, suffix.length] == suffix      
  end
end

=begin
  Blank
=end
class Object #:nodoc:
  # "", "   ", nil, [], and {} are blank
  def blank?
    if respond_to?(:empty?) && respond_to?(:strip)
      empty? or strip.empty?
    elsif respond_to?(:empty?)
      empty?
    else
      !self
    end
  end
end

class NilClass #:nodoc:
  def blank?
    true
  end
end

class FalseClass #:nodoc:
  def blank?
    true
  end
end

class TrueClass #:nodoc:
  def blank?
    false
  end
end

class Array #:nodoc:
  alias_method :blank?, :empty?
end

class Hash #:nodoc:
  alias_method :blank?, :empty?
end

class String #:nodoc:
  def blank?
    empty? || strip.empty?
  end
end

class Numeric #:nodoc:
  def blank?
    false
  end
end