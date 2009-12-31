require 'test_helper'

class OccurrenceTest < ActiveSupport::TestCase
  
  def setup
    @d1 = Item.create(:did=>"d1", :basetime=>Time.now, :metadata=>{})
    @c1 = Tag.create(:title=>"c1")
  end
  
  # Replace this with your real tests.
  test "the truth" do
    @d1.add_tags("c1", "m")
    @d1.add_tags("c2", "m")
    #debugger
    assert_equal([], ["c1","c2"] - @d1.tag_titles)
    assert_equal([], ["c1","c2"] - @d1.tag_titles("m"))
    assert_equal("c1", @d1.tags[0].title)
    assert_equal("c1", @d1.occurrences[0].tag.title)
  end
end
