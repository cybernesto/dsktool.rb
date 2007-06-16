#
# dsktool.rb
#
# == Synopsis
#
# Manipulate DSK format files (as used by Apple 2 emulators)
#
# == Usage
#
# dsktool.rb [switches] <filename.dsk>
#  -c | --log               display catalog
#  -e | --extract FILENAME      extract file by name (either to stdout, 
#                               or file specified by --output)
#  -h | --help                  display this message
#  -l | --list FILENAME         monitor style listing (disassembles 65C02 opcodes)
#  -o | --output FILENAME       specify name to save extracted file as
#  -x | --explode               extract all files 
#  -v | --version               show version number
#
# Currently only works with DOS 3.3 format 
# DSK images can be
#
# examples:
#	dsktool.rb -c DOS3MASTR.dsk.gz
#	dsktool.rb -l FID DOS3MASTR.dsk
#	dsktool.rb --list fid -o fid.asm DOS3MASTR.dsk
#	dsktool.rb --extract "COLOR DEMOSOFT" DOS3MASTR.dsk
#	dsktool.rb -e HELLO -o HELLO.bas DOS3MASTR.dsk
#	dsktool.rb -x DOS3MASTR.dsk.gz
#

DSKTOOL_VERSION="0.1.3"

require 'optparse'
require 'rdoc/usage'

#due to a bug in rdoc, tghe Usage won't work correctly when run from a gem executable
# see http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/211297
# Display usage from the given file
def RDoc.usage_from_file(input_file, *args)
	comment = File.open(input_file) do |file|
		RDoc.find_comment(file)
	end
	comment = comment.gsub(/^\s*#/, '')

	markup = SM::SimpleMarkup.new
	flow_convertor = SM::ToFlow.new
    
	flow = markup.convert(comment, flow_convertor)

	format = "plain"

	unless args.empty?
		flow = extract_sections(flow, args)
	end

	options = RI::Options.instance
	if args = ENV["RI"]
		options.parse(args.split)
	end
	formatter = options.formatter.new(options, "")
	formatter.display_flow(flow)
	exit
end


catalog=false
explode=false
output_filename=nil
extract_filename=nil
list_filename=nil
explode_directory=nil
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage_from_file(__FILE__)}
opts.on("-v","--version") do
	puts "dsktool.rb "+DSKTOOL_VERSION
	exit
end
opts.on("-c","--catalog") {catalog=true}
opts.on("-x","--explode") {explode=true}
opts.on("-l","--list FILENAME",String) {|val| list_filename=val.upcase}
opts.on("-e","--extract FILENAME",String) {|val| extract_filename=val.upcase}
opts.on("-o","--output FILENAME",String) {|val| output_filename=val}
filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
RDoc::usage_from_file(__FILE__,'Usage') if (filename.nil?)

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
	if (dsk.is_dos33?) then
		dsk.dump_catalog
	else
		puts "#{filename} is not in DOS 3.3 format"
	end
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
		puts "'#{extract_filename}' not found in #{filename}"
	else
		output_file<<file
	end
end

if (!list_filename.nil?) then
	file=dsk.files[list_filename]
	if file.nil? then
		puts "'#{list_filename}' not found in #{filename}"
	else
		if file.instance_of?(BinaryFile)
			output_file<<file.disassembly
		else
			puts "'#{list_filename}' is not a binary file"
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
