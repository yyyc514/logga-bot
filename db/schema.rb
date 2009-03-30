ActiveRecord::Schema.define(:version => 20081125045518) do
 
  create_table "chats", :force => true do |t|
    t.string   "channel"
    t.string   "message_type"
    t.text     "message"
    t.datetime "created_at"
    t.integer  "person_id"
    t.integer  "other_person_id"
    t.boolean  "delta",           :default => false
  end
 
  create_table "days", :force => true do |t|
    t.date    "date"
    t.integer "chats_count", :default => 0
  end
 
  create_table "hostnames", :force => true do |t|
    t.string   "hostname"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
 
  create_table "hostnames_people", :id => false, :force => true do |t|
    t.integer "person_id"
    t.integer "hostname_id"
  end
 
  create_table "lines", :force => true do |t|
    t.string  "nick"
    t.integer "lines", :default => 1
  end
 
  create_table "people", :force => true do |t|
    t.string  "name"
    t.integer "chats_count", :default => 0
    t.text "notes"
  end
 
  create_table "runtimes", :force => true do |t|
    t.string   "name"
    t.datetime "last_run"
  end
 
  create_table "tips", :force => true do |t|
    t.string  "command"
    t.string  "description"
    t.text    "text"
    t.integer "user_id"
  end
 
  create_table "users", :force => true do |t|
    t.string   "login",                     :limit => 40
    t.string   "name",                      :limit => 100, :default => ""
    t.string   "email",                     :limit => 100
    t.string   "crypted_password",          :limit => 40
    t.string   "salt",                      :limit => 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remember_token",            :limit => 40
    t.datetime "remember_token_expires_at"
  end
 
  add_index "users", ["login"], :name => "index_users_on_login", :unique => true
 
  create_table "votes", :force => true do |t|
    t.integer  "person_id"
    t.integer  "other_person_id"
    t.integer  "chat_id"
    t.boolean  "positive",        :default => true
    t.datetime "created_at"
  end
 
  create_table "words", :force => true do |t|
    t.string  "word"
    t.integer "times"
  end
 
end