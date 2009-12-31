Gem::Specification.new do |s|
  s.name    = 'acts_as_graph'
  s.version = '0.1'
  s.date    = '2009-07-20'

  s.summary = %q{acts_as_graph is a Rails plugin that facilitates a Graph like interface to ActiveRecord.}
  s.description = %q{acts_as_graph is a Rails plugin that facilitates a Graph like interface to ActiveRecord.}

  s.authors = ["Tammer Saleh", "Shayne Huddleston", "George Harkin"]
  s.email = %q{montana.harkin@gmail.com}
  s.homepage = %q{http://github.com/harking/acts_as_graph}

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.has_rdoc = false 
  #s.rdoc_options = ["--inline-source", "--charset=UTF-8"]

  s.files = %w(CHANGELOG MIT-LICENSE README Rakefile init.rb lib/acts_as_graph.rb)
  s.test_files %w(test/acts_as_graph_test.rb test/database.yml test/schema.rb test/test_helper.rb test/fixtures/employee_edges.yml test/fixtures/employees.yml)

  s.add_dependency('activerecord', '>= 2.3.2')
end

