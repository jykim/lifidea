require 'test_helper'

class TagTest < ActiveSupport::TestCase

  def setup
    @c1 = "Jinyoung Kim"
    @c2 = "Information Retrieval"
    @c3 = "안녕하세"
    @c4 = "good"
    Tag.find_or_create(@c1)
    Tag.find_or_create(@c2)
    Tag.find_or_create(@c3)
    Tag.find_or_create(@c4)
  end
  # 
  #test "tag initialization" do
  #  #debugger
  #  assert_equal "person", Tag.find_by_title(@c1).ctype
  #  assert_equal "pnoun", Tag.find_by_title(@c2).ctype
  #  assert_equal "pnoun", Tag.find_by_title(@c3).ctype
  #  assert_equal "noun",  Tag.find_by_title(@c4).ctype
  #end
  #
  #test "synonymy" do
  #  @c5 = "IR"
  #  @c6 = "Search"
  #  Tag.find_or_create(@c5, :synonym_id=>Tag.find_by_title(@c2).id)
  #  Tag.find_or_create(@c6, :synonym_id=>Tag.find_by_title(@c2).id)
  #  assert_equal Tag.find_by_title(@c2), Tag.find_by_title(@c5).synonym
  #  assert_equal [], [Tag.find_by_title(@c5),Tag.find_by_title(@c6)] - Tag.find_by_title(@c2).synonyms
  #end
end
