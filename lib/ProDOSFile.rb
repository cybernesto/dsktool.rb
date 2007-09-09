$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'DSKFile'

#ProDOS file
class ProDOSFile < DSKFile
	attr_accessor :file_type,:aux_type
	
	def initialize(filename,contents,file_type,aux_type)
		@filename=filename
		@contents=contents
		@file_type=PRODOS_FILE_TYPES[file_type]
		@file_type=sprintf('$%02X',file_type) if @file_type.nil?
		@aux_type=aux_type
	end
#ProDOS file types from "Beneath Apple DOS pp 4-10 - 4-11)
PRODOS_FILE_TYPES={		
	0x00=>"",	#"Typeless File"
	0x01=>"BAD",	#"Bad blocks"
	0x04=>"TXT",	#"ASCII Text"
	0x06=>"BIN",	#"8 bit binary"
	0x0F=>"DIR",	#"Directory File"
	0x19=>"ADB",	#"AppleWorks Database"
	0x1A=>"AWP",	#"ApplWorks word processing"
	0x1B=>"ASP",	#"AppleWorks spreadsheet"
	0xEF=>"PAS",	#"ProDOS Pascal"
	0xF0=>"CMD",	#"ProDOS added command file"
	0xFC=>"BAS",	#"Applesoft BASIC"
	0xFD=>"VAR",	#"Applesoft stored variables"
	0xFE=>"REL",	#"Relocatable object module"
	0xFF=>"SYS",	#"ProDOS system"
}
	def file_extension
		return "."+@file_type.downcase
	end

	def to_s
		if @file_type=="BAS" then
			#applesoft detokeniser routine expects the first two bytes to be length of buffer
			buffer_length=2+contents.length
			buffer=(buffer_length%0x100).chr+(buffer_length/0x100).chr+contents
			buffer_as_applesoft_file(buffer)
		else
			contents
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

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
