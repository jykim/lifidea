def fill_data( data, col_no )
  col_data = nil
  data.map do |row|
    if row[col_no]
      col_data = row[col_no]
      puts "col_data : #{col_data}"
    else
      row[col_no] = col_data
    end
    row
  end
end