module ActiveRecord # :nodoc:
  module Acts #:nodoc:
    module Graph # :nodoc:
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      # Author: Originally by Tammer Saleh (tammersaleh.com)
      # Updated to rails 2.3.2 by Shayne Huddleston and maintained by George Harkin <montana.harkin@gmail.com>

      # Specify this act if you want the model to represent nodes in a directed graph structure.
      # This act optionally allows you to perform various graph algorithms on your graphs using
      # RGL (http://rgl.rubyforge.org/rgl/index.html) if you have it installed.
      #
      # This act requires that you have a join table for the edges. Unless you specify otherwise,
      # the name of the join table is expected to be the singular name of the nodes table - suffixed
      # by <tt>_edges</tt>. The join table should have at least three columns - <tt>id</tt>, 
      # <tt>from_id</tt> and <tt>to_id</tt>.
      # 
      #   class Employee < ActiveRecord::Base
      #     acts_as_graph
      #   end
      #   
      #   Example : 
      #   
      #   fred ---------> wilma
      #     |               |
      #     +--> barney <---+
      #
      #   # Define the nodes
      #   fred      = Employee.create(:name => "fred")
      #   wilma     = Employee.create(:name => "wilma")
      #   barney    = Employee.create(:name => "barney")
      #
      #   # Define the edges
      #   EmployeeEdge.create(:from => fred, :to => wilma)
      #   EmployeeEdge.create(:from => fred, :to => barney)
      #   EmployeeEdge.create(:from => wilma, :to => barney)
      #
      #   # Query the nodes
      #   barney.incoming_nodes   # => [fred, wilma]
      #   wilma.outgoing_edges    # => [wilma_barney]
      #
      #   # Get all of the edges
      #   Employee.edges  # => Array of EmployeeEdge
      #
      #   # Get an RGL graph representing all of the edges
      #   # (Requires RGL: http://rgl.rubyforge.org/rgl/index.html)
      #   Employee.graph  # => RGL::DirectedAdjacencyGraph
      #
      #   # Create an image file (Requires RGL and Graphviz: http://www.graphviz.org/)
      #   require 'rgl/dot'
      #   Employee.graph.write_to_graphic_file('png')
      #
      # You don't have to specify a class for the edges.
      # After specifying the act, a class for the edges will be dynamically defined. Example:
      #
      #   class EmployeeEdge
      #     def from; ...;end
      #     def to; ...;end
      #   end
      #
      # However, should you want to add more behaviour to the edge class, you're free to define it yourself,
      # as well as add additional columns to the associated table.
      #
      # The following instance methods are added to the class after specifying the act:
      # * outgoing_edges : Returns all edges pointing out from this node.
      # * incoming_edges : Returns all edges pointing in to this node.
      # * outgoing_nodes : Returns all nodes that the outgoing edges point to.
      # * incoming_nodes : Returns all nodes that the incoming edges point from.
      #
      # The following class methods are added to the class after specifying the act:
      # * edges : Returns all the edges in the database.
      # * graph : Returns a RGL::DirectedAdjacencyGraph representing all the nodes and edges in the database.
      #
      module ClassMethods
        def acts_as_graph(options = {})
          # TODO: options for
          # :include_from (ignored - always true if order is set)
          # :include_to (ignored - always true if order is set)

          class_name = options[:class_name] || "#{self.name}Edge"
          join_table = options[:join_table] || class_name.pluralize.underscore
          from_key = options[:from_key] || 'from_id'
          to_key = options[:to_key] || 'to_id'
          order = options[:order]
          
          eval <<-EOF
            class ::#{class_name} < ::ActiveRecord::Base
              belongs_to :from, :class_name => '#{self.name}', :foreign_key => '#{from_key}'
              belongs_to :to, :class_name => '#{self.name}', :foreign_key => '#{to_key}'
            end
          EOF
          
          has_many :outgoing_edges, {
            :class_name => class_name,
            :foreign_key => from_key,
            :include => :to,
            :order => order,
            :dependent => :destroy
          }

          has_many :incoming_edges, {
            :class_name => class_name,
            :foreign_key => to_key,
            :include => :from,
            :order => order,
            :dependent => :destroy
          }
          
          has_many :outgoing_nodes, :through => :outgoing_edges, :source => :to, :order => order
          has_many :incoming_nodes, :through => :incoming_edges, :source => :from, :order => order

          class_eval <<-EOV
            include ActiveRecord::Acts::Graph::InstanceMethods

            def self.edges
              # Ideally we should :include => [:from, :to] but the SQL fails...
              #{class_name}.find :all
            end

            def self.graph
              begin
                require 'rgl/adjacency'
                dg = RGL::DirectedAdjacencyGraph.new
                edges.each{|edge| dg.add_edge(edge.from, edge.to)}
                find(:all).each{|vertex| dg.add_vertex(vertex)}
                dg
              rescue MissingSourceFile
                raise "RGL must be installed when using the graph method. See http://rgl.rubyforge.org/rgl/index.html"
              end
            end

          EOV
        end
        
      end
  
      module InstanceMethods #:nodoc:
      end
    end
  end
end

ActiveRecord::Base.send :include, ActiveRecord::Acts::Graph
