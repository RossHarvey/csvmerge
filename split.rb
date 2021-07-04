require 'rubygems'
require 'csv'

class Split

  def run
    puts 'Clearing cols/'
    system 'rm -rf cols; mkdir cols'
    puts 'Reading merged_db.csv...'
    table = CSV.read 'r/merged_db.csv', :headers=>true
    table.headers.each_with_index do |colname, i|
      puts "Writing #{colname}"
      File.open('cols/' + (table.headers[i].tr ' /', '_:'), 'w') do |f|
        f.puts table.by_col[colname]
      end
    end
      
  end

  self
end.new.run
