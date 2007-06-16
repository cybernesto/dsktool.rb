#
# dsktool
#
# == Synopsis
#
# Manipulate DSK format files
#
# == Usage
#
# dsktool.rb [switches] <filename.dsk>
#  -c | --catalog               display catalog
#  -d | --disassemble FILENAME  disassemble 65C02 opcodes (binary files only)
#  -e | --extract FILENAME      extract file by name (either to stdout, 
#                               or file specified by --output)
#  -h | --help                  display this message
#  -o | --output FILENAME       specify name to save extracted file as
#  -x | --explode               extract all files 
#
# examples:
#	dsktool -c adtpro.dsk
#	dsktool -d FID adtpro.dsk
#	dsktool -d FID -o fid.asm adtpro.dsk
#	dsktool -e "COLOR DEMOSOFT" adtpro.dsk
#	dsktool -e HELLO -o HELLO.bas adtpro.dsk
#	dsktool -x adtpro.dsk
#
# == Author
# Jonno Downes (jonno@jamtronix.com)
#
# == Copyright
# Copyright (c) 2006 Jonno Downes (jonno@jamtronix.com)
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require '../lib/DSK'
require 'optparse'
require 'rdoc/usage'
catalog=false
explode=false
output_filename=nil
extract_filename=nil
list_filename=nil
explode_directory=nil
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage}
opts.on("-c","--catalog") {catalog=true}
opts.on("-x","--explode") {explode=true}
opts.on("-d","--disassemble FILENAME",String) {|val| list_filename=val.upcase}
opts.on("-e","--extract FILENAME",String) {|val| extract_filename=val.upcase}
opts.on("-o","--output FILENAME",String) {|val| output_filename=val}
filename=opts.parse(ARGV)[0] rescue RDoc::usage('usage')
RDoc::usage('usage') if (filename.nil?)

dsk=DSK.read(filename)
output_file= case
	when (output_filename.nil?) then STDOUT
	else File.open(output_filename,"wb")
end
	
if(catalog) then	
	dsk.dump_catalog
end

if(explode) then
	output_dir=filename.sub(/\.[^.]*$/,"")
	if !(File.exists?(output_dir)) then
		Dir.mkdir(output_dir)	
	end
			
	dsk.files.each_value do |f|
		output_filename=output_dir+"/"+f.filename+f.file_extension
		File.open(output_filename,"wb") <<f
	end
end


if (!extract_filename.nil?) then
	file=dsk.files[extract_filename]
	if file.nil? then
		puts "file #{extract_filename} not found in #{filename}"
	else
		output_file<<file
	end
end

if (!list_filename.nil?) then
	file=dsk.files[list_filename]
	if file.nil? then
		puts "file #{extract_filename} not found in #{filename}"
	else
		if file.instance_of?(BinaryFile)
			output_file<<file.disassembly
		else
			puts "file #{extract_filename} not a binary file"
		end
	end
end
