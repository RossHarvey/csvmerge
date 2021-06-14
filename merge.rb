require 'rubygems'
require 'csv'

class Transpose

  ENCODING  = 'windows-1252'
  READMODE  = 'r:' + ENCODING
  WRITEMODE = 'w:' + ENCODING
  IDIR      = 'db2/'

  def run
    @uniq_fields = {}
    @field_index = {}
    CSV.open "r/fieldsurvey.csv", "w" do |csv|
      ARGV.each do |file|
        File.open file, READMODE do |f1|
          File.open IDIR + file, WRITEMODE do |f2|
            f2.puts f1.gets.gsub(' ,', ',')
            while s = f1.gets
              f2.puts s
            end
          end
        end
      end
      ARGV.each do |file|
        File.open IDIR + file, READMODE do |f|
          t = [file, *track(file, (CSV.parse f.gets).first)]
          csv << t
        end
      end
      puts '-' * 80
      CSV.open "r/merged_db.csv",
               "w",
               :write_headers => true,
               :headers       => @field_index.keys do |mcsv|
        ARGV.each do |file|
          csv = CSV.parse(File.read(IDIR + file, :encoding => ENCODING), headers: true)
          csv.each do |row|
            newrecord = []
            row.each do |(key, value)|
              p [file, key, value, @field_index[key]]
              newrecord[@field_index[key]] = value if key && value
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
    p '>>>'
    p file
    p fields
    fields.each do |hcn| # header column name
      raise if hcn == ''
      if hcn # ,, can produce a nil field
        ocn = @field_index[hcn] # original column name
        ofn = @uniq_fields[hcn] # original file name
        if ocn
          puts 'In "%s" field "%s" reoccurs' % [file, hcn]
        else
          @field_index[hcn] = @field_index.size
          @uniq_fields[hcn] = file
          puts 'In "%s" field "%s" originates' % [file, ocn]
        end
      end
    end
    fields
  end

  self
end.new.run
