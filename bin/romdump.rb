#!/usr/bin/env ruby

# romdump.rb
#
# == Synopsis
#
# display a BIN file assuming it is a Apple 2 ROM dump
#
# == Usage
#
# romdump.rb [switches] <filename.bin>
#  -b | --base BASE   use BASE as start of disassembly (implies --list)
#                     BASE will be interpreted as a hex number 
#                     (can be prefixed with $, 0x, or nothing)
#  -f | --font        treat all bytes as 8 bit wide font
#  -l | --list        list disassembly of all bytes
#  -x | --hex         dump as hex and ASCII
#  -h | --help        display this message
#  -v | --version     show version number
#
# switchs can be combined, as in
#   romdump.rb edm.bin -xl -b $D000


ROMDUMP_VERSION="0.0.1"

#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)
require 'rubygems'
require 'optparse'
require 'rdoc_patch' #RDoc::usage patched to work under gem executables
base_address=0
font=false
hex=false
list=false
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage_from_file(__FILE__)}
opts.on("-v","--version") do
		puts File.basename($0)+" "+ROMDUMP_VERSION
	exit
end
opts.on("-f","--font"){font=true}
opts.on("-x","--hex"){hex=true}
opts.on("-l","--list"){list=true}
opts.on("-b","--base BASE",String) do |val| 
  base_address=val.tr("$","").hex
  list=true
end
filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
RDoc::usage_from_file(__FILE__,'Usage') if (filename.nil?)

file_bytes=open(filename,"rb").read

require 'DumpUtilities'
require 'D65'
if (font) then
  puts DumpUtilities.font_dump(file_bytes)
end
if (hex) then
  puts DumpUtilities.hex_dump(file_bytes)
end
if (list) then
  puts D65.disassemble(file_bytes,base_address)
end
