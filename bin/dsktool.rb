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
#	dsktool -c DOS3MASTR.dsk
#	dsktool -d FID DOS3MASTR.dsk
#	dsktool -d fid -o fid.asm DOS3MASTR.dsk
#	dsktool -e "COLOR DEMOSOFT" DOS3MASTR.dsk
#	dsktool -e HELLO -o HELLO.bas DOS3MASTR.dsk
#	dsktool -x DOS3MASTR.dsk
#
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

#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)
	
require 'DSK'
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
