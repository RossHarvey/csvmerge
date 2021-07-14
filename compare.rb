#!/usr/bin/env ruby

#
# print columns side-by-side using max terminal width
# numbers lines, skips blanks, and reports collisions
#

class Compare

  def run
    exit unless ARGV.size > 0
    inputs = []
    ARGV.each do |fn|
      inputs << [fn, (File.open fn, 'r')]
    end
    termcols = `stty size`.scan(/\d+/)[1].to_i
    printcols = (termcols - 7) / ARGV.size
    lineno = 0
    $stdout.write "      "
    ARGV.each do |fn|
      $stdout.write " %-*.*s" % [printcols, printcols, fn]
    end; puts
    collisions = 0
    begin
      combined_line = ""
      col_len = 0
      collision = false
      still_reading = inputs.reduce nil do |memo, (fn, fh)|
        s = fh.gets
        nns =   s || '' # non-null s
        newcol_len = nns.strip.size
        collision ||= col_len > 0 && newcol_len > 0
        combined_line << "%-*.*s" % [printcols, printcols, nns.chomp]
        col_len += newcol_len
        memo      || s
      end
      lineno += 1
      if combined_line.strip.size > 0
        puts "%c%5d %s" % [collision ? 'c':' ', lineno, combined_line]
      end
      if collision
        collisions += 1
      end
    end while still_reading
    puts "#{collisions} collisions"
  end

  self
end.new.run
