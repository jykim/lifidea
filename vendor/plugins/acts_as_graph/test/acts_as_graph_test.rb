require File.join(File.dirname(__FILE__), 'test_helper')

class Employee < ActiveRecord::Base
  acts_as_graph :order => 'name'
  def to_s; name; end
end

class ActsAsGraphTest < Test::Unit::TestCase
  fixtures :employees, :employee_edges
  
  def test_outgoing_nodes
    assert_equal [employees(:patty)], employees(:barney).outgoing_nodes
  end

  def test_outgoing_edges
    assert_equal [employee_edges(:barney_patty)], employees(:barney).outgoing_edges
  end

  def test_incoming_nodes
    assert_equal [employees(:fred), employees(:wilma)], employees(:barney).incoming_nodes
  end

  def test_incoming_edges
    assert_equal [employee_edges(:fred_barney), employee_edges(:wilma_barney)], employees(:barney).incoming_edges
  end
  
  def test_edge_extremities
    assert_equal employees(:wilma), employee_edges(:wilma_barney).from
    assert_equal employees(:barney), employee_edges(:wilma_barney).to
  end
  
  def test_class_gets_edges_method
    # http://aslakhellesoy.com/articles/2006/02/09/announcement-new-javascript-canvas-graph-library
    expected_edges = [
      employee_edges(:aslak_dave),
      employee_edges(:aslak_fred),
      employee_edges(:barney_patty),
      employee_edges(:fred_barney),
      employee_edges(:fred_wilma),
      employee_edges(:patty_aslak),
      employee_edges(:wilma_barney),
      employee_edges(:wilma_dino)
    ]
    # edges are not sorted
    #assert_equal edges, Employee.edges
    edges = Employee.edges
    assert_equal expected_edges.length, edges.length
    expected_edges.each do |expected_edge|
      assert edges.index(expected_edge)
    end
  end
  
  def test_destroys_association_but_not_other_end
    employees(:wilma).destroy

    expected_edges = [
      employee_edges(:aslak_dave),
      employee_edges(:aslak_fred),
      employee_edges(:barney_patty),
      employee_edges(:fred_barney),
      employee_edges(:patty_aslak)
    ]

    edges = Employee.edges
    assert_equal expected_edges.length, edges.length
    expected_edges.each do |expected_edge|
      assert edges.index(expected_edge)
    end
    
    expected_employees = [
      employees(:aslak),
      employees(:barney),
      employees(:dave),
      employees(:dino),
      employees(:fred),
      employees(:patty)
    ]
    assert_equal expected_employees, Employee.find(:all, :order => 'name')
  end
  
  def test_can_build_graph_by_linking_nodes
    foo = Employee.create :name => 'foo'
    bar = Employee.create :name => 'bar'
    foo.outgoing_nodes << bar
    assert_equal [bar], foo.outgoing_nodes
  end

  def test_class_gets_graph_method
    require 'rgl/dot'
    Employee.graph.write_to_graphic_file('png')
  end
  
end