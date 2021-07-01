require 'rubygems'
require 'csv'

#FOCUS = /^Mailing.[sS]tate/ # for analysis, extract only this field match

class Transpose

  READMODE  = 'r:UTF-8'
  WRITEMODE = 'w:UTF-8'
# WRITEMODE = 'w:windows-1252'
  IDIR      = 'db2/'
  ENCODING  = 'UTF-8'

  RENAME    = {
    'Mailing state'             => 'Mailing State',
    'Mailing state or province' => 'Mailing State',
    'Mailing State/Provience'   => 'Mailing State',
    'Audited By'                => 'Audit By',
    'Audit Company'             => 'Audit By',
    'Classified Adv. e-mail'    => 'Classified Adv. Email',
    'Classified Advertising e-mail' =>
                                   'Classified Adv. Email',
    'Mailing address'           => 'Mailing Address',
    'Mailing address 1'         => 'Mailing Address 1',
    'Mailing address 2'         => 'Mailing Address 2',
    'Mailing city'              => 'Mailing City',
    'Mailing postal code'       => 'Mailing Postal Code',
    'Delivery methods'          => 'Delivery Methods',
    'Display Advertising e-mail'=> 'Display Adv. Email',
    'Display Adv. E-mail'       => 'Display Adv. Email',
    'General/National Adv. E-mail' =>
                                   'General/National Adv. Email',
    "Advertising phone"         => "Advertising Phone",
    "Editorial phone"           => "Editorial Phone",
    "Office phone"              => "Office Phone",
    "Other phone"               => "Other Phone",
    "Areas Served - City/County or Portion Thereof, or Zip codes" =>
    "Areas Served - City/County or Portion Thereof, or ZIP Codes",

  }

  def run
    @field_index = {}
    # (null) input and output records
    irs = ors = nirs = nors = 0
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
            f2.puts editheader f1.gets.gsub(' ,', ',')
            # this first scan is textual cleanup and not really CSV-aware
            while s = f1.gets
              irs += 1
              r = editbody s
              if r.size == 0
                nirs += 1
              else
                f2.puts r
              end
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
      IO.write "r/headers", (@field_index.keys.join "\n")
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
                next if (defined? FOCUS) and not (FOCUS =~ key)
                if key[/ [pP]hone/]
                  original = value
                  value = value.strip.gsub(
                    /^1?[ -]?\.?\(*(\d\d\d) ?\)*[- .\/]*(\d\d\d)[- .]*(\d\d\d\d)/, '(\1) \2-\3')
                                     .gsub(/ ? ?(, )?\(?\/?(x|ext)[-. :]*(\d+)[ )]*$/i, ' x\3')
                                     .gsub(/ x_*$/, '')
                  report_on_phone value, original
#                 if !value[/^\(\d\d\d\) \d\d\d-\d\d\d\d( x\d+)?$/]
#                   puts "in field >#{key}< non-conforming phone: >#{value}<" if key[" Phone"]
#                 end
                end
                newrecord[@field_index[RENAME[key] || key]] = value # relocate field
              end
            end
            if newrecord.size == 0
              nors += 1
            else
              mcsv << newrecord
              ors += 1
            end
          end
        end
      end
      puts '%5d input records' % irs
      puts '%5d null input records' % nirs
      puts '%5d null output records' % nors
      puts '%5d output records' % ors
      puts '%5d fields' % @field_index.size
      puts '%5d harmonized phone numbers' % @harmonized_phones
    end
  end

  def report_on_phone value, original
    if value != original
      # puts
      # puts "was >#{original}<"
      # puts "now #{value}"
      @harmonized_phones += 1
    end
  end

  def editheader s
    s.strip.gsub(' ,', ',')
           .gsub(/,,*$/, '')
#          .gsub('Mailing ZIP', ZIP)
#          .gsub('Mailing zip', ZIP)
#          .gsub('Mailing ZIP Code', ZIP)
#          .gsub('Mailing Zip Code', ZIP)
#          .gsub('Mailing ZIP/Postal', ZIP)


    # header fixups aren't just style -- they merge intended-identical columns
    # this quadratically reduces space--we are over half-way to the google sheets
    # size limit as it is now
  end

  def editbody s
    s.strip.gsub(/[^[:ascii:]]/, '').gsub(/,,*$/,'')
  end

  # Compile a unique list of all fields. Depends on stable hash order.
  def track file, fields
    fields.each do |hcname| # header column name
      raise if hcname == ''
      if defined? FOCUS
        next unless FOCUS =~ hcname
      end
      if hcname # ,, can produce a nil field
        s = RENAME[hcname] || hcname
        if !@field_index[s]
          @field_index[s] = @field_index.size
        end
      end
    end
    fields
  end

  self
end.new.run
