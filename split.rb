#!/usr/bin/env ruby

require 'rubygems'
require 'csv'

# Splits the DB into columns, each column in a separate file...
# The normal next step is:
#   $ colordiff -u -r refcols/ cols/

class Split

  def run
    puts 'Clearing cols/'
    system 'rm -rf cols; mkdir cols'
    puts 'Reading merged_db.csv...'
    collisions = 0

    table = CSV.read 'r/merged_db.csv', :headers=>true

    table.headers.each_with_index do |colname, i|
      puts "Writing #{colname} index=#{i}"
      ofn = 'cols/' + (table.headers[i].tr ' /', '_:')
      if test 'e', ofn
        puts; puts
        puts "#{colname} already exists, probably a case-folding collision"
        puts
        system "grep -i '#{colname}' r/headers"
        puts
        collisions += 1
      end
      File.open ofn, 'w' do |f|
        f.puts table.by_col[colname]
      end
    end

    puts "#{collisions} collisions"

  end

  self
end.new.run
