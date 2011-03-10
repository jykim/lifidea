# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20091205172650) do

  create_table "data_documents", :force => true do |t|
    t.string   "did"
    t.string   "uri",            :limit => 512
    t.string   "dtype"
    t.string   "title"
    t.integer  "source_id"
    t.text     "content"
    t.text     "metadata"
    t.text     "concept_titles"
    t.text     "textindex"
    t.datetime "basetime"
    t.boolean  "hidden_flag",                   :default => false
    t.boolean  "modified_flag",                 :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "indexed_at"
  end

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "jid"
  end

  create_table "games", :force => true do |t|
    t.integer  "user_id"
    t.string   "gid"
    t.integer  "query_count"
    t.integer  "score"
    t.text     "comment"
    t.datetime "start_at"
    t.datetime "finish_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "feedback"
    t.boolean  "hidden_flag"
    t.integer  "level"
  end

  create_table "histories", :force => true do |t|
    t.string   "htype"
    t.integer  "user_id"
    t.datetime "basetime"
    t.text     "metadata"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "item_id"
    t.string   "src_item_id"
    t.integer  "game_id"
  end

  add_index "histories", ["basetime"], :name => "index_histories_on_basetime"

  create_table "item_queries", :id => false, :force => true do |t|
    t.integer  "id",                            :default => 0,     :null => false
    t.string   "did"
    t.string   "uri",            :limit => 512
    t.string   "itype"
    t.string   "title"
    t.integer  "source_id"
    t.text     "content"
    t.text     "metadata"
    t.text     "tag_titles_bak"
    t.text     "textindex"
    t.datetime "basetime"
    t.boolean  "hidden_flag",                   :default => false
    t.boolean  "modified_flag",                 :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "indexed_at"
    t.boolean  "private_flag"
    t.text     "remark"
    t.boolean  "query_flag"
    t.integer  "user_id"
  end

  create_table "items", :force => true do |t|
    t.string   "did"
    t.string   "uri",            :limit => 512
    t.string   "itype"
    t.string   "title"
    t.integer  "source_id"
    t.text     "content"
    t.text     "metadata"
    t.text     "tag_titles_bak"
    t.text     "textindex"
    t.datetime "basetime"
    t.boolean  "hidden_flag",                   :default => false
    t.boolean  "modified_flag",                 :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "indexed_at"
    t.boolean  "private_flag"
    t.text     "remark"
    t.boolean  "query_flag"
    t.integer  "user_id"
  end

  add_index "items", ["did"], :name => "index_documents_on_did", :unique => true

  create_table "links", :force => true do |t|
    t.string   "lid"
    t.integer  "out_id"
    t.integer  "in_id"
    t.string   "remark"
    t.string   "judgment"
    t.float    "weight"
    t.text     "metadata"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "ltype",      :limit => 1
  end

  add_index "links", ["lid"], :name => "index_concept_links_on_lid", :unique => true

  create_table "logged_exceptions", :force => true do |t|
    t.string   "exception_class"
    t.string   "controller_name"
    t.string   "action_name"
    t.text     "message"
    t.text     "backtrace"
    t.text     "environment"
    t.text     "request"
    t.datetime "created_at"
  end

  create_table "occurrences", :force => true do |t|
    t.string   "oid"
    t.integer  "item_id"
    t.integer  "tag_id"
    t.string   "weight"
    t.string   "judgment"
    t.string   "otype",      :limit => 1
    t.text     "metadata"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "occurrences", ["oid"], :name => "index_occurrences_on_oid", :unique => true

  create_table "queries", :force => true do |t|
    t.string   "query_text"
    t.integer  "user_id"
    t.integer  "game_id"
    t.integer  "query_id"
    t.integer  "item_id"
    t.integer  "position"
    t.integer  "query_count"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "rules", :force => true do |t|
    t.string   "rid"
    t.string   "unit"
    t.string   "itype"
    t.string   "target"
    t.string   "rtype"
    t.string   "value"
    t.text     "condition"
    t.text     "option"
    t.boolean  "inactive_flag", :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "rules", ["rid"], :name => "index_rules_on_rid", :unique => true

  create_table "scores", :force => true do |t|
    t.integer  "user_id"
    t.integer  "document_id"
    t.integer  "position"
    t.text     "desc"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sources", :force => true do |t|
    t.string   "title"
    t.string   "itype"
    t.string   "uri"
    t.string   "sync_content"
    t.integer  "sync_interval"
    t.text     "option"
    t.text     "filter"
    t.datetime "sync_at"
    t.boolean  "active_flag",   :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "stats", :force => true do |t|
    t.string   "rid"
    t.string   "unit"
    t.string   "content"
    t.string   "sid"
    t.string   "stype"
    t.string   "source"
    t.string   "tag"
    t.integer  "doc_count"
    t.datetime "basedate"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "sys_configs", :force => true do |t|
    t.string   "title"
    t.text     "content"
    t.text     "remark"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

  create_table "tags", :force => true do |t|
    t.string   "tid"
    t.string   "uri"
    t.string   "ctype"
    t.string   "title"
    t.string   "remark"
    t.string   "judgment"
    t.text     "metadata"
    t.text     "textindex"
    t.boolean  "hidden_flag",   :default => false
    t.boolean  "modified_flag", :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "synonym_id"
    t.boolean  "private_flag"
    t.datetime "indexed_at"
  end

  add_index "tags", ["tid"], :name => "index_concepts_on_cid", :unique => true

  create_table "tags_old", :force => true do |t|
    t.string "name"
  end

  create_table "users", :force => true do |t|
    t.string   "uid"
    t.string   "utype"
    t.string   "name"
    t.string   "email"
    t.string   "hashed_password"
    t.string   "salt"
    t.text     "desc"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "level"
  end

end
