$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'DSKFile'

#ProDOS file
class ProDOSFile < DSKFile
	attr_accessor :file_type,:aux_type,:full_filename
	
	def initialize(filename,contents,file_type,aux_type,full_filename)
		raise "filename too long - #{filename}" unless filename.length<=15
		@filename=filename
    @full_filename=full_filename
		@contents=contents
		@file_type=PRODOS_FILE_TYPES[file_type]
		@file_type=sprintf('$%02X',file_type) if @file_type.nil?
		@aux_type=aux_type
	end
#ProDOS file types from "Beneath Apple DOS pp 4-10 - 4-11)
PRODOS_FILE_TYPES={		
0x00=>"",      #"Typeless File"
 0x01=>"BAD",  #BAD blocks file
 0x02=>"PCD",  #Pascal CoDe file
 0x03=>"PTX",  #Pascal TeXt file
 0x04=>"TXT",  #ASCII text file
 0x05=>"PDA",  #Pascal DAta file
 0x06=>"BIN",  #BINary file
 0x07=>"CHR",  #CHaRacter font file
 0x08=>"PIC",  #PICture file
 0x09=>"BA3",  #Business BASIC (SOS) program file
 0x0A=>"DA3",  #Business BASIC (SOS) data file
 0x0B=>"WPD",  #Word Processor Document
 0x0F=>"DIR",  #subDIRectory file
 0x10=>"RPD",  #RPS data file
 0x11=>"RPI",  #RPS index file
 0x19=>"ADB",  #AppleWorks Database file
 0x1A=>"AWP",  #AppleWorks WordProcessing file
 0x1B=>"ASP",  #AppleWorks Spreadsheet file
 0x60=>"PRE",  #ProDOS preboot driver
 0x6B=>"NIO",  #PC Transporter BIOS and drivers
 0x6D=>"DVR",  #PC Transporter device drivers
 0x6F=>"HDV",  #MSDOS HardDisk Volume
 0xA0=>"WPF",  #WordPerfect document file
 0xA1=>"MAC",  #Macrofile
 0xA2=>"HLP",  #Help File
 0xA3=>"DAT",  #Data File
 0xA5=>"LEX",  #Spelling dictionary
 0xAC=>"ARC",  #General Purpose Archive file
 0xB0=>"SRC",  #ORCA/M & APW source file
 0xB1=>"OBJ",  #ORCA/M & APW object file
 0xB2=>"LIB",  #ORCA/M & APW library file
 0xB3=>"S16",  #ProDOS16 system file
 0xB4=>"RTL",  #ProDOS16 runtime library
 0xB5=>"EXE",  #APW shell command file
 0xB6=>"STR",  #ProDOS16 startup init file
 0xB7=>"TSF",  #ProDOS16 temporary init file
 0xB8=>"NDA",  #ProDOS16 new desk accessory
 0xB9=>"CDA",  #ProDOS16 classic desk accessory
 0xBA=>"TOL",  #ProDOS16 toolset file
 0xBB=>"DRV",  #ProDOS16 driver file
 0xBF=>"DOC",  #document file
 0xC0=>"PNT",  #//gs paint document
 0xC1=>"SCR",  #//gs screen file
 0xC8=>"FNT",  #Printer font file
 0xE0=>"LBR",  #Apple archive library file
 0xE2=>"ATI",  #Appletalk init file
 0xEF=>"PAS",  #ProDOS Pascal file
 0xF0=>"CMD",  #added command file
 0xF1=>"OVL",  #Overlay file
 0xF2=>"DBF",  #Database file
 0xF3=>"PAD",  #MouseWrite file
 0xF4=>"MCR",  #AE Pro macro file
 0xF5=>"ECP",  #ECP batch file
 0xF6=>"DSC",  #description file
 0xF7=>"TMP",  #temporary work file
 0xF8=>"RSX",  #linkable object module
 0xF9=>"IMG",  #ProDOS image file
 0xFA=>"INT",  #Integer BASIC program
 0xFB=>"IVR",  #Integer BASIC variables file
 0xFC=>"BAS",  #AppleSoft BASIC program
 0xFD=>"VAR",  #AppleSoft BASIC variables file
 0xFE=>"REL",  #ProDOS EDASM relocatable object module file
 0xFF=>"SYS",  #ProDOS8 system file}
}
	def file_extension
		return "."+@file_type.downcase
	end

	def to_s
		case @file_type
		when "BAS" then
			#applesoft detokeniser routine expects the first two bytes to be length of buffer
			buffer_length=2+contents.length
			buffer=(buffer_length%0x100).chr+(buffer_length/0x100).chr+contents
			buffer_as_applesoft_file(buffer)
		when "AWP" then
			buffer_as_awp_file(contents)			
		else
			#strip of the high bits
			s=""
			@contents.each_byte{|b| s+=(b%0x80).chr.tr(0x0D.chr,"\n")}
			s		end
	end

private
	#AWP format defined in http://www.umich.edu/~archive/apple2/technotes/ftn/FTN.1A.xxxx
	def buffer_as_awp_file(buffer)
		s=""
		i=300 #skip 300 byte header
		i+=2 if buffer[183]>3 #skip the first invalid line if SFMInVers non-zero
		while i<buffer.length-4 do
			command_byte_0=buffer[i]
			command_byte_1=buffer[i+1]
			i+=2
			if command_byte_1==0xD0 then #it's a carriage return line - do nothing
			elsif command_byte_1>0xD0 then #it's a command line - do nothing
			else #it's a text record
				bytes_in_line=command_byte_0
				control_byte=buffer[i+1]
#				carriage_return_after_line=(control_byte>=0x80)
				chars_remaining=control_byte%0x80
				buffer[i+2..i+2+chars_remaining-1].each_byte do |b|
					if b==0x16 then #tab char
						s<<"\t"
					elsif b==0x17 then
						s<<" "
					elsif b>=0x20 then
						s<<b.chr
					end
				end
				i+=bytes_in_line
				s<<"\n"
#				s<<"\n" if carriage_return_after_line 			
			end
		end		
		s
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
