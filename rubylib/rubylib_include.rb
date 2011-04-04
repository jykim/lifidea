# Standalone Ruby Library

require 'rubygems'
#require 'ruby-debug'
require 'jcode'
require 'matrix'
$KCODE = "u"

#require 'test/unit'
require 'extensions/extensions.rb'
#require 'extensions/open-uri.rb'
require 'extensions/exceptions.rb'
load 'extensions/table.rb'
require 'globals/file'
require 'globals/globals.rb'
require 'globals/ddl.rb'
require 'ir/language_model.rb'
require 'ir/inference_network.rb'
require 'ir/stemmer.rb'
require 'ir/stopwords.rb'
require 'ir/index.rb'
require 'ir/document.rb'
require 'ir/concept_hash.rb'
require 'ir/params_search.rb'
require 'ir/user_model.rb'

#include Test::Unit::Assertions