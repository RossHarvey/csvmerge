require 'rubygems'
require 'csv'

class Transpose

  READMODE  = 'r:UTF-8'
  WRITEMODE = 'w:UTF-8'
# WRITEMODE = 'w:windows-1252'
  IDIR      = 'db2/'
  ENCODING  = 'UTF-8'

  def run
    @field_index = {}
    CSV.open "r/fieldsurvey.csv", "w" do |survey|
      # read every file in binary mode, filter 8-bit characters,
      # trailing commas, and spaces before commas in headers.
      # (encoding is not UTF-8 but also not an obvious codepage,
      # leading to core errors when trying to encode as UTF-8)
      ARGV.each do |file|
        puts file
        bytes8bit = IO.binread file
        StringIO.open bytes8bit do |f1|
          File.open IDIR + file, WRITEMODE do |f2|
            # read CSV header
            f2.puts trim f1.gets.gsub(' ,', ',').gsub(' phone', ' Phone')
            # now read the actual records
            while s = f1.gets
              f2.puts trim s
            end
          end
        end
      end
      # read each again and build up the overall field list
      ARGV.each do |file|
        File.open IDIR + file, READMODE do |f|
          t = [file, *track(file, (CSV.parse f.gets).first)]
          survey << t
        end
      end
      puts '-' * 80
      # read each file yet again and merge
      @harmonized_phones = 0
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
              if key && value
                if key[" Phone"]
                  original = value
                  value = value.strip.gsub(/^1?[ -]?\.?\(*(\d\d\d) ?\)*[- .\/]*(\d\d\d)[- .]*(\d\d\d\d)/, '(\1) \2-\3')
                                     .gsub(/ ? ?(, )?\(?\/?(x|ext)[-. :]*(\d+)[ )]*$/i, ' x\3')
                                     .gsub(/ x_*$/, '')
                  report_on_phone value, original
                  if !value[/^\(\d\d\d\) \d\d\d-\d\d\d\d( x\d+)?$/]
                    puts "in field >#{key}< non-conforming phone: >#{value}<" if key[" Phone"]
                  end
                end
                newrecord[@field_index[key]] = value # relocate field
              end
            end
            mcsv << newrecord
          end
        end
      end
      puts '%d fields' % @field_index.size
      puts '%d harmonized phone numbers' % @harmonized_phones
      format = "%40s | %-40s"
      # puts format % ["<- FIELD -<", ">- FIRST SEEN IN ->"]
    end
  end

  def report_on_phone value, original
    if value != original
      puts
      puts "was >#{original}<"
      puts "now #{value}"
      @harmonized_phones += 1
    end
  end

  def trim s
    s.gsub(/[^[:ascii:]]/, '').strip.gsub(/,,*$/,'')
  end

  # Compile a unique list of all fields. Depends on stable hash order.
  def track file, fields
    fields.each do |hcn| # header column name
      raise if hcn == ''
      if hcn # ,, can produce a nil field
        ocn = @field_index[hcn] # original column name
        if ocn
          puts 'In "%s" field "%s" reoccurs' % [file, hcn]
        else
          @field_index[hcn] = @field_index.size
          puts 'In "%s" field "%s" originates' % [file, ocn]
        end
      end
    end
    fields
  end

  self
end.new.run
