# Standalone Ruby Library

require 'rubygems'
#require 'ruby-debug'
require 'jcode'
require 'matrix'
$KCODE = "u"

#require 'test/unit'
require 'extensions/extensions.rb'
require 'extensions/exceptions.rb'
require 'extensions/table.rb'
require 'globals/globals.rb'
require 'ir/language_model.rb'
require 'ir/inference_network.rb'
require 'ir/stemmer.rb'
require 'ir/stopwords.rb'
require 'ir/index.rb'
require 'ir/document.rb'
require 'ir/concept_hash.rb'
require 'ir/params_search.rb'

#include Test::Unit::Assertions