ActiveRecord::Schema.define(:version => 1) do

  create_table :employees, :force => true do |t|
    t.column :name, :string
  end

  create_table :employee_edges, :force => true do |t|
    t.column :from_id, :integer
    t.column :to_id, :integer
  end

end