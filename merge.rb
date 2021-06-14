require 'rubygems'
require 'charlock_holmes'
require 'csv'
require 'pry'

class Transpose

  ENCODING = 'windows-1252'
  READMODE = 'r:' + ENCODING

  def run
    @uniq_fields = {}
    @field_index = {}
    CSV.open "r/fieldsurvey.csv", "w" do |csv|
        # first scan all the field names in all dbs
        ARGV.each do |file|
          File.open file, READMODE do |f|
            t = [file, *track(file, (CSV.parse f.gets).first)]
            csv << t # + Array.new(73 - t.size)
          end
        end
        puts '-' * 80
        # Now merge
      CSV.open "r/merged_db.csv",
               "w",
               :write_headers => true,
               :headers       => @field_index.keys do |mcsv|
        ARGV.each do |file|
          csv = CSV.parse(File.read(file, :encoding => ENCODING), headers: true)
          # current_fields = (CSV.parse f.gets).first
          # while s = f.gets
          csv.each do |row|
            newrecord = []
            row.each do |(key, value)|
              newrecord[@field_index[key]] = value
            end
            mcsv << newrecord
          end
        end
      end
    end
    puts '%d uniq fields' % @uniq_fields.size
    format = "%40s | %-40s"
    puts format % ["<- FIELD -<", ">- FIRST SEEN IN ->"]
    [@uniq_fields.keys.to_a, @uniq_fields.values.to_a].transpose.each do |row|
      puts format % row
    end
  end

  # Compile a unique list of all fields. Depends on stable hash order.

  def track file, fields
    fields.each do |seen_yet|
      f = @uniq_fields[seen_yet]
      if f
        puts 'In "%s" field "%s" reoccurs' % [file, f]
      else
        @field_index[seen_yet] = @field_index.size
        @uniq_fields[seen_yet] = file
        puts 'In "%s" field "%s" originates' % [file, f]
      end
    end
    fields
  end

  self
end.new.run
