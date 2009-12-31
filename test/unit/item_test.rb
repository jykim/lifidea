require 'test_helper'

class ItemTest < ActiveSupport::TestCase
    
  should "have Hash type metadata" do
    assert(Item.new(:metadata=>{}).m.class == Hash)
    assert(Item.new(:metadata=>{:a=>1}).m[:a] == 1)
    #assert(Item.new(:metadata=>"").m.class == Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch){Item.new(:metadata=>"").m}
  end

  context "A item with mark-up" do
    setup do
      @item = items("cal2")
      @item.add_tags("taga,tagb", "u")
    end

    should "get tag and metadata from markup" do
      @item.process_markup
      #debugger
      assert(@item.tag_titles.include?('tag1'), "tag1 exists")
      assert(@item.tag_titles.include?('tag2'), "tag2 exists")
      assert_equal(4, @item.tag_titles.size, "existing tags are not preserved #{@item.tag_titles.inspect}")
      assert_equal("meta_value", @item.m[:meta_key1])
      assert_equal(-2, @item.m[:meta_key3])
      assert_equal(-1, @item.m[:score])
    end
    
    should "have tags replaced by user" do
      #debugger
      new_tags = "taga,tagb,tagc"
      @item.add_tags("tag1,tag2")
      assert_equal(4, @item.tag_titles.size, "tags have not been added #{@item.tag_titles.inspect}")
      @item.replace_tags(new_tags)
      assert_equal(0, (@item.tag_titles - new_tags.split(",")).size, "tags have not been replaced properly #{@item.tag_titles.inspect}")
      #assert_equal(3, @item.tag_titles.size, "tags have not been replaced properly #{@item.tag_titles.inspect}")
    end
    
  end

  context "A item with multi-tag mark-up" do
    setup do
      @item = items("cal0")
    end
    
    should "get tags and metadata from markup" do
      @item.process_markup
      assert(1, (@item.tag_titles - ['tag1','tag2','tag3','tag4']).size)
      assert(@item.tag_titles.include?("non@alphabet-tag"))
      assert_equal("meta_value", @item.m[:meta_key3])
      assert_equal(-2, @item.m[:meta_key4])
    end
  end
  
  context "A item with tagging rules" do
    setup do
      @item = items("cal1")
      @rules = []
      @rules << rules("T1") << rules("T2") << rules("T2_2")
      assert_equal(3, @rules.size)
    end
    
    should "return text given target" do
      assert_equal(@item.title, @item.text_in(:title))
      assert_equal(@item.m[:meta_key1], @item.text_in(:meta_key1))
      assert_equal(@item.m[:type], @item.text_in(:type))
      assert_raise(ArgumentError){@item.text_in("title")}
    end
    
    should "be validated according to given condition(s)" do
      assert @item.validate_by_condition({}) 
      cond = {:title=>"/bla/",:type=>":hourly", :hour_do=>"1..4", :grade=>"['A0','A-']"}
      assert @item.validate_by_condition(cond) 
      
      assert !@item.validate_by_condition(cond.merge(:grade=>"['A+','B0']"))
      assert !@item.validate_by_condition(cond.merge(:title=>"/blo/"))
      assert @item.validate_by_condition(cond.merge(:title=>/bla/))
    end

    should "get tags from rule" do
      cond = {}
      @item.add_tags("tag0", "u")
      assert @item.validate_by_condition(cond.merge(:tag=>"/tag0/")), "tag0 exists!"
      assert !@item.validate_by_condition(cond.merge(:tag=>"/tag1/")), "tag1 doesn't exists!"
      @item.process_rules(@rules)
      assert_equal(5, @item.tags.size, "tags were created")
      assert_equal(5, @item.occurrences.size, "occurrences were created")
      #debugger
      assert @item.validate_by_condition(cond.merge(:tag=>"/tag1/")), "tag1 was created!"
      assert @item.validate_by_condition(cond.merge(:tag=>"/tag4/")), "tag4 was created!"
      assert @item.validate_by_condition(:tag=>/tag3/), "tag3 was created"
      assert_equal(5, @item.tag_titles.size)
    end
  end
end
