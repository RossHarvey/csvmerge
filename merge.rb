require 'rubygems'
require 'csv'

#FOCUS = /^Mailing.[sS]tate/ # for analysis, extract only this field match

class Transpose

  READMODE  = 'r:UTF-8'
  WRITEMODE = 'w:UTF-8'
  IDIR      = 'db2/'
  ENCODING  = 'UTF-8'
  SUBSET    = false
  EN_DASH   = 0x96

# Renames work by preventing the old column from being created in
# the first place. Entries may be many-to-one but not transitive.

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
    "Mailing Postal code"       => "Mailing Postal Code",
    "Mailing zip"               => 'Mailing ZIP',
    "Mailing ZIP Code"          => 'Mailing ZIP',
    "Mailing Zip Code"          => 'Mailing ZIP',
    "Mailing province"          => "Mailing Province",

    "ZIP/Postal code"           => "ZIP/Postal Code",
    "Postal code"               => "Postal Code",

    'Delivery methods'          => 'Delivery Methods',
    'Display Advertising e-mail'=> 'Display Adv. Email',
    'Display Adv. E-mail'       => 'Display Adv. Email',
    'General/National Adv. E-mail' =>
                                   'General/National Adv. Email',
    "Advertising phone"         => "Advertising Phone",
    "Advertising fax"           => "Advertising Fax",
    "Editorial phone"           => "Editorial Phone",
    "Editorial fax"             => "Editorial Fax",
    "Office phone"              => "Office Phone",
    "Other phone"               => "Other Phone",
    "Areas Served - City/County or Portion Thereof, or Zip codes" =>
    "Areas Served - City/County or Portion Thereof, or ZIP Codes",
    "Provience"                 => "Province",
    "Company name"              => "Company Name",
    "Main (survey) contact"     => "Main Contact",
    "Main Contatct"             => "Main Contact",
    "State/Province"            => "State",
    "Master"                    => "Master Category",
    "Types"                     => "Type",
    "Editorial e-mail"          => "Editorial Email",

    "Street address 1"          => "Street Address 1",
    "Street address 2"          => "Street Address 2",
    "General e-mail"            => "General Email",
    "General E-mail"            => "General Email",
    "Parent company"            => "Parent Company",
    "Corporate/Parent Company"  => "Parent Company",
    "Parent company (for newpapers)" =>
                                   "Parent Company",
    "Parent Company/Group    "  => "Parent Company",
    "Main contact"              => "Main Contact",
    "Year established"          => "Year Established",
    "News services"             => "News Services",

    "Advertising"               => "Advertising (Open inch rate) Weekday/Saturday",
    "Advertising (Open Inch Rate) Weekday/Saturday" =>
    "Advertising (Open inch rate) Weekday/Saturday",

    "Mechanical specifications" => "Mechanical Specifications",

=begin
  TODO: map both zip and postal code keys together
    "Mailing ZIP Code"          => "Mailing ZIP",
    "Mailing ZIP/Postal"        => "Mailing ZIP",
    "Mailing Zip Code"          => "Mailing ZIP",
    "Mailing zip"               => "Mailing ZIP",
    "Street Zip Code"           => "Street ZIP Code",
    "ZIP/Postal Code"           => "ZIP Code",
    "Zip/Postal code"           => "ZIP Code",
    "Zip Codes Served"          => "ZIP Codes Served",
=end

  }

# formerly in editheader
#          .gsub('Mailing ZIP', ZIP)
#          .gsub('Mailing zip', ZIP)
#          .gsub('Mailing ZIP Code', ZIP)
#          .gsub('Mailing Zip Code', ZIP)
#          .gsub('Mailing ZIP/Postal', ZIP)

  GLOBAL_REMOVE = {
    "If other, please specify:" => true,
  }

# GLOBAL_KEEP = "Advertising"

  CELL_UPDATES = [
    [ "Master Category",
        "Newspaper Comic Section Groupsand Networks",
        "Newspaper Comic Section Groups and Networks" ],
    [ "Type",
        "Newspaper",
        "Newspapers"],
  ]

  def run

    @field_index = {} # the accumulated final fields
    @null_type_warning = {} # track component db's with a null type field
    @tpatch = @mcpatch = @cellmerge = @trs = @htrs =
    @endash = @nonco = @irs = @ors = @nirs = @nors = 0 # (null) input and output records

    pass1 # dborig/*.csv -> db2/. Textual fixups, all files rewritten to db2
    pass2 # only headers read from db2 -- column merges and name fixups
    pass3 # read all db2 CSVs and merge into one file

    printstats

  end

  def pass1
    # read every file in binary mode, filter 8-bit characters,
    # trailing commas, and spaces before commas in headers.
    ARGV.each do |file|
      puts file
      bytes8bit = IO.binread file
      StringIO.open bytes8bit do |f1|
        File.open IDIR + file, WRITEMODE do |f2|
          # read CSV header
          f2.puts editheader f1.gets.gsub(' ,', ',')
          @htrs += 1
          # this first scan is textual cleanup and not really CSV-aware
          while s = f1.gets
            @irs += 1
            r = editbody s
            if r.size == 0
              @nirs += 1
            else
              f2.puts r
              if r != s
                @trs += 1
              end
            end
          end
        end
      end
    end
  end

  def pass2
    puts '=' * 80 # read again, but just the headers, and build up the overall field list
    ARGV.each do |file|
      puts file
      File.open IDIR + file, READMODE do |f|
        track file, (CSV.parse f.gets).first
      end
    end
    IO.write "r/headers", (@field_index.keys.join "\n")
  end

  def pass3
    puts '-' * 80 # read and merge
    @harmonized_phones = 0
    CSV.open "r/merged_db.csv",
             "w",
             :write_headers => true,
             :headers       => @field_index.keys do |mcsv|
      ARGV.each do |file|
        puts file
        csv = CSV.parse(File.read(IDIR + file, :encoding => ENCODING), headers: true)
        csv.each do |row|
          next unless row.any? # filter out ,,,,, lines (no stat atm)
          newrecord = []
#         check_null_type file, row
          row.each do |(key, value)|
            next unless key && value
            next if (defined? FOCUS) and not (FOCUS =~ key)
            next if GLOBAL_REMOVE[key]
            next if (defined? GLOBAL_KEEP) && !(key.start_with? GLOBAL_KEEP)
            format_phone_field key, value
            @cellmerge += 1 if RENAME[key]
            mergedkey = RENAME[key] || key
            idx = @field_index[mergedkey]
            raise "#{key} not found #{@field_index}" unless idx
            check_overwrite key, newrecord, idx, value
            newrecord[idx] = value # relocate field
            update_cells newrecord, mergedkey, idx, value
          end
          if newrecord.size == 0
            @nors += 1
          else
            try_first_cols_fix file, row, newrecord unless defined? GLOBAL_KEEP
            mcsv << (SUBSET ? newrecord[0..2] + [file] : newrecord)
            @ors += 1
          end
        end
      end
    end
  end

  def printstats
    puts '%5d input records' % @irs
    puts '%5d null input records' % @nirs
    puts '%5d null output records' % @nors
    puts '%5d output records' % @ors
    puts '%5d header records edited' % @htrs
    puts '%5d data records edited' % @trs
    puts '%5d fields' % @field_index.size
    puts '%5d harmonized phone numbers' % @harmonized_phones
    puts '%5d non-conforming numbers remain' % @nonco
    puts '%5d en-dash glyphs converted' % @endash
    puts '%5d Type fields patched' % @tpatch
    puts '%5d Master Category fields patched' % @mcpatch
    puts '%5d Cells merged from %d redundant columns' % [@cellmerge, RENAME.size]
  end

  def try_first_cols_fix file, catrow, row
    if row[1].nil? || row[1].empty?
      row[1] = File.basename file, '.csv'
      @mcpatch += 1
    end
    if row[0].nil? || row[0].empty?
      if row[1] == "Equipment, Supply and Service Companies"
        row[0] = "Services"
        @tpatch += 1
      end
    end
  end

  def check_null_type file, row
#   unless "dborig/" + (row[1] || "")  + ".csv" == file
#     unless file == "dborig/News, Picture and Syndicate Services.csv"
#       puts 'm' * 80
#       puts row[1]
#       puts file
#       puts 'Master Category unexpected'
#       # raise
#     end
#   end
    if row[0].nil? || row[0].empty?
      if !@null_type_warning[file]
        puts
        puts '#' * 80
        puts "\"#{file}\" is missing a type field"
        puts
        @null_type_warning[file] = true
      end
    end
  end

  def update_cells newrecord, mergedkey, idx, value
    CELL_UPDATES.each do |u|
      if mergedkey == u[0] && value == u[1]
        newrecord[idx] = u[2]
      end
    end
  end

  def format_phone_field key, value
    if key[/ [pP]hone$|[fF]ax$/]
      original = value.clone
      value.replace value.strip.gsub(
        /^1?[ -]?\.?\(*(\d\d\d) ?\)*[- .\/]*(\d\d\d)[- .]*(\d\d\d\d)/, '(\1) \2-\3')
                               .gsub(/ ? ?(, )?\(?\/?(x|ext)[-. :]*(\d+)[ )]*$/i, ' x\3')
                               .gsub(/ x_*$/, '')
      report_on_phone value, original
      if !value[/^\(\d\d\d\) \d\d\d-\d\d\d\d( x\d+)?$/]
        @nonco += 1
  #     puts "in field >#{key}< non-conforming phone: >#{value}<" if key[" Phone"]
      end
    end
  end

  def check_overwrite key, newrecord, idx, value
    if newrecord[idx]
      # this can happen with duplicate fields, usually something
      # like: mail street, city, state, office street, city, state
      puts "Overwrite of #{key}/#{RENAME[key] || '--'} at #{idx}"
      puts "Originally #{newrecord[idx]}"
      puts "Now        #{value}"
      pp newrecord
      raise if newrecord[idx] != value
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
  end

  def editbody s
    r = s.strip.gsub(/,,*$/,'').tr("\xA0".b, " ".b)

    while true
      i = r.index EN_DASH.chr
      break if i.nil?
      b = r.bytes
      i = b.index EN_DASH
      raise if i.nil?
      if i > 0 &&
        ('0'.ord..'9'.ord) === b[i - 1] &&
        ('0'.ord..'9'.ord) === b[i + 1] # then
        b[i] = '-'.ord
        @endash += 1
      else
        b.delete_at i
      end
      r = b.pack 'C*'
    end

    r.gsub(/[^[:ascii:]]/, '')
  end

  # Merge this CSV file's fields to the master list.

  def track file, fields
    dups = {}; havedups = nil
    fields.each_with_index do |hcname, i|
      next if GLOBAL_REMOVE[hcname]
      next if (defined? GLOBAL_KEEP) && !(hcname.start_with? GLOBAL_KEEP)
      # apply various sanity checks
      raise "column #{i} zero-length string" if hcname == ''
      raise "column #{i} nil" if hcname.nil?
      if dups[hcname]
        puts "#{hcname} is duplicated in columns #{dups[hcname]} and #{i}"
        havedups = true
      end
      dups[hcname] = i
    end
    raise if havedups # error out for dups in one file, dups between
    #                   CSV files are expected
    # now, add to the master list if not already there
    # must be RENAME{}-concious
    fields.each do |hcname| # header column name
      raise if hcname == ''
      if defined? FOCUS
        next unless FOCUS =~ hcname
      end
      if hcname # Instances of ,, can produce a nil field
        s = RENAME[hcname] || hcname
        if !@field_index[s]
          if !GLOBAL_REMOVE[s]
            if !(defined? GLOBAL_KEEP) || (hcname.start_with? GLOBAL_KEEP)
              @field_index[s] = @field_index.size
            end
          end
        end
      end
    end
  end

  self
end.new.run
