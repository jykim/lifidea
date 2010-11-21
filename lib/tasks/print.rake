require 'ddl_include'

namespace :print do
  desc "Export Concept Links into dot file"
  task :concept_links => :environment do
    template = ERB.new(IO.read('lib/tasks/graph_neato.erb'))
    $clf = cache_data('clf', Searcher.load_features())
    threshold = ENV['threshold'] || 1
    ltype = ENV['ltype'] || 'k'
    level = ENV['level'] || 1
    degree = ENV['degree'] || 5
    filename = ENV['filename'] || "data/concept_links_#{$renv}_#{ENV['concept']}_#{ltype}#{threshold}-#{level}-#{degree}.dot"
    conditions = if ENV['concept']
      rel_concepts = get_relevant_concepts(ENV['concept'].to_i, threshold.to_f, level.to_i, degree.to_i)
      ['ltype = ? and weight >= ? and (in_id in (?) or out_id in (?))', ltype, threshold.to_f, rel_concepts, rel_concepts]
    else
      ['ltype = ? and weight >= ?', ltype, threshold.to_f]
    end
    nodes = Link.all(:conditions=>conditions).
      find_all{|l| (l.initem && l.initem.concept? && l.outitem && l.outitem.concept?)}.
      map{|l|{:from=>l.outitem.title, :to=>l.initem.title, :weight=>l.weight}} #, :label=>l.ltype
    File.open(filename , "w"){|f| f.puts template.result(binding) }
    puts 'created dot file...'
    puts cmd = "neato -T png -o #{filename}.png #{filename}"
    `#{cmd}`
  end
end