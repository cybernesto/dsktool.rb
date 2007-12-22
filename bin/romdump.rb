#!/usr/bin/env ruby

# dsktool.rb
#
# == Synopsis
#
# display a BIN file assuming it is a Apple 2 ROM dump
#
# == Usage
#
# romdump.rb [switches] <filename.bin>
#  -f | --font                  ROM contains 8x8 font
#  -h | --help                  display this message
#  -v | --version               show version number
#

ROMDUMP_VERSION="0.0.1"

#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)
require 'rubygems'
require 'optparse'
require 'rdoc_patch' #RDoc::usage patched to work under gem executables

font=false
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage_from_file(__FILE__)}
opts.on("-v","--version") do
		puts File.basename($0)+" "+ROMDUMP_VERSION
	exit
end
opts.on("-f","--font"){font=true}
filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
RDoc::usage_from_file(__FILE__,'Usage') if (filename.nil?)

file_bytes=open(filename,"rb").read

require 'DumpUtilities'
require 'D65'
if (font) then
  puts DumpUtilities.font_dump(file_bytes)
  else 
    puts DumpUtilities.hex_dump(file_bytes)
    puts "\n\n"
    puts D65.disassemble(file_bytes)
  end