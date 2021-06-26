require 'rubygems'
require 'csv'

class Transpose

  READMODE  = 'r:UTF-8'
  WRITEMODE = 'w:UTF-8'
# WRITEMODE = 'w:windows-1252'
  IDIR      = 'db2/'
  ENCODING  = 'UTF-8'

  def run
    @uniq_fields = {}
    @field_index = {}
    # TODO: if the occasional 8-bit chars are not noise,
    #       further analyze encoding
    CSV.open "r/fieldsurvey.csv", "w" do |survey|
      # read every file in binary mode, filter 8-bit characters,
      # trailing commas, and spaces before commas in headers.
      # encoding is not UTF-8 but also not an obvious codepage,
      # leading to core errors when trying to encode as UTF-8
      ARGV.each do |file|
        puts file
        bytes8bit = IO.binread file
        StringIO.open bytes8bit do |f1|
          File.open IDIR + file, WRITEMODE do |f2|
            f2.puts trim f1.gets.gsub(' ,', ',')
            while s = f1.gets
              f2.puts trim s
            end
          end
        end
      end
      # read each file again and build up the overall field list
      ARGV.each do |file|
        File.open IDIR + file, READMODE do |f|
          t = [file, *track(file, (CSV.parse f.gets).first)]
          survey << t
        end
      end
      puts '-' * 80
      # read each file yet again and merge
      CSV.open "r/merged_db.csv",
               "w",
               :write_headers => true,
               :headers       => @field_index.keys do |mcsv|
        ARGV.each do |file|
          puts file
          csv = CSV.parse(File.read(IDIR + file, :encoding => ENCODING), headers: true)
          csv.each do |row|
            newrecord = []
            row.each do |(key, value)|
              newrecord[@field_index[key]] = value if key && value
            end
            mcsv << newrecord
          end
        end
      end
      puts '%d uniq fields' % @uniq_fields.size
      format = "%40s | %-40s"
      puts format % ["<- FIELD -<", ">- FIRST SEEN IN ->"]
#     [@uniq_fields.keys.to_a, @uniq_fields.values.to_a].transpose.each do |row|
#       puts(format % row)
#     end
    end
  end

  def trim s
    s.gsub(/[^[:ascii:]]/, '').strip.gsub(/,,*$/,'')
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
