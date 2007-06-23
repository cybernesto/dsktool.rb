#!/usr/bin/ruby
# dsktool.rb
#
# == Synopsis
#
# Manipulate DSK format files (as used by Apple 2 emulators)
#
# == Usage
#
# dsktool.rb [switches] <filename.dsk>
#  -c | --catalog               display catalog
#  -e | --extract FILENAME      extract file by name (either to stdout, 
#                               or file specified by --output)
#  -h | --help                  display this message
#  -d | --dump FILENAME         hex dump
#  -l | --list FILENAME         monitor style listing (disassembles 65C02 opcodes)
#  -o | --output FILENAME       specify name to save extracted file as
#  -r | --raw                   don't convert basic files to ASCII
#  -x | --explode               extract all files 
#  -v | --version               show version number
#
#	Currently only works with DOS 3.3 format DSK images 
#	Will uncompress gzipped files (with extension .gz)
#	input files can be URLs
#
# examples:
#	dsktool.rb -c DOS3MASTR.dsk.gz
#	dsktool.rb -l FID DOS3MASTR.dsk
#	dsktool.rb --list fid -o fid.lst DOS3MASTR.dsk
#	dsktool.rb --extract "COLOR DEMOSOFT" DOS3MASTR.dsk
#	dsktool.rb -e HELLO -o HELLO.bas DOS3MASTR.dsk
#	dsktool.rb -x DOS3MASTR.dsk.gz
#	dsktool.rb -x DOS3MASTR.dsk.gz -o /tmp/DOS3MASTR/
#	dsktool.rb -c http://jamtronix.com/dsks/apshai.dsk.gz

DSKTOOL_VERSION="0.1.5"

#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'optparse'
require 'rdoc_patch' #RDoc::usage patched to work under gem executables

catalog=false
explode=false
output_filename=nil
extract_filename=nil
extract_mode=:default
explode_directory=nil
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage_from_file(__FILE__)}
opts.on("-v","--version") do
		puts File.basename($0)+" "+DSKTOOL_VERSION
	exit
end
opts.on("-r","--raw") {extract_mode=:raw}
opts.on("-c","--catalog") {catalog=true}
opts.on("-x","--explode") {explode=true}
opts.on("-l","--list FILENAME",String) do |val| 
	extract_filename=val.upcase
	extract_mode=:list	
end
opts.on("-d","--dump FILENAME",String) do |val| 
	extract_filename=val.upcase
	extract_mode=:hex
end
opts.on("-e","--extract FILENAME",String) {|val| extract_filename=val.upcase}
opts.on("-o","--output FILENAME",String) {|val| output_filename=val}
filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
RDoc::usage_from_file(__FILE__,'Usage') if (filename.nil?)

	
require 'DSK'
dsk=DSK.read(filename)
output_file= case
	when (output_filename.nil?) || (explode) then STDOUT
	else File.open(output_filename,"wb")
end
	
if(catalog) then	
	if (dsk.is_dos33?) then
		dsk.dump_catalog
	else
		puts "#{filename} is not in DOS 3.3 format"
	end
end

if(explode) then
	output_dir=output_filename.nil??File.basename(filename,".*"):output_filename
	if !(File.exists?(output_dir)) then
		Dir.mkdir(output_dir)	
	end
			
	dsk.files.each_value do |f|
		if (raw_mode) then
			output_filename=output_dir+"/"+f.filename+".raw"
			File.open(output_filename,"wb") <<f.contents
		else
			output_filename=output_dir+"/"+f.filename+f.file_extension
			File.open(output_filename,"wb") <<f
		end
	end
end


if (!extract_filename.nil?) then
	file=dsk.files[extract_filename]
	if file.nil? then
		puts "'#{extract_filename}' not found in #{filename}"
	else
		output_file<< case extract_mode
			when :raw then file.contents
			when :hex then file.hex_dump
			when :list then 	
				if file.instance_of?(BinaryFile)
					file.disassembly
				else
					puts "'#{extract_filename}' is not a binary file"
					exit
				end
			else	file.to_s 
		end
	end
end

# == Author
# Jonno Downes (jonno@jamtronix.com)
#
# == Copyright
# Copyright (c) 2007 Jonno Downes (jonno@jamtronix.com)
#
#Permission is hereby granted, free of charge, to any person obtaining
#a copy of this software and associated documentation files (the
#"Software"), to deal in the Software without restriction, including
#without limitation the rights to use, copy, modify, merge, publish,
#distribute, sublicense, and/or sell copies of the Software, and to
#permit persons to whom the Software is furnished to do so, subject to
#the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
