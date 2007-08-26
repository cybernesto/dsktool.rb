$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'D65'

#NADOL (Nibbles Away Disk Optimized Language) file
class NADOLFile	
	attr_accessor(:filename,:contents) 
	def initialize(filename,contents)
		@filename=filename
		@contents=contents
	end

	def to_s
		@contents
	end

	def file_extension
		".bin"
	end
	def hex_dump
		#assumes file is a multiple of 16 bytes, which it always should be
		s=""
		(0..(@contents.length/16)-1).each {|line_number|
			 lhs=""
			 rhs=""
			 start_byte=line_number*16
			 line=@contents[start_byte..start_byte+15]
			 line.each_byte {|byte|
				  lhs+= sprintf("%02X ", byte)
				  rhs+= (byte%128).chr.sub(/[\x00-\x1f]/,'.')
		 	}
			s+=sprintf("%02X\t%s %s\n",start_byte,lhs,rhs)
		}
		s
	end
end

#a file on a NADOL dsk that does not appear to be in NADOL tokenised format
class NADOLBinaryFile<NADOLFile
	def disassembly(start_address=0x8000) 
		require 'D65'
		D65.disassemble(@contents,start_address)
	end
end


#file packed by the NADOL EDITOR application.
#format is a series of  unnumbered lines, where each line has the following format:
#  <Length>     (8-bit: including length byte, line no, contents, zero>
#  <Tokens and/or Characters>
#  <Zero byte>  ($00, to mark the end of the S-C Asm source line)
# each byte in the line is interpreted as follows:
# $00 - end of line marker
# $01 - $64 - NADOL tokens
# $65 - $70 - ??? unknown
# $71 - $7f - 1 to F spaces
# $80 - $FF - ASCII character with high bit set
class NADOLTokenisedFile < NADOLFile
	NADOL_EDITOR_TOKENS = [
	"?",		#00 (so we can use token as an index in to this array)
	"READ(",	#01
	"FREE(",	#02
	"NOT(",	#03
	"LENGTH(",	#04
	"PDL(",	#05
	"SIZEOF(",	#06
	"LSCRN(",	#07
	"HSCRN(",	#08
	"CHECK(",	#09
	"MAKE(",	#0a
	"SCREEN(",	#0b
	"HEXPACK ",#0c
	"PROCEDURE ",#0d
	"ENDPROC",	#0e
	"FUNCTION ",#0f
	"ENDFUNC",	#10
	"IF ",	#11
	"ELSE",	#12
	"ENDIF",	#13
	"WHILE ",	#14
	"ENDWHILE",#15
	"DEFINE ",	#16
	"RESULT=",	#17
	"PRINT",	#18
	"PRINTHEX",#19
	"PRINTBYTE",#1a
	"LABEL ",	#1b
	"GOTO ",	#1c
	"INVERSE",	#1d
	"NORMAL",	#1e
	"FLASH",	#1f
	"CASE ",	#20
	"GOTOXY(",	#21
	"CLEAR",	#22
	"NEW",	#23
	"HOME",	#24
	"CLREOL",	#25
	"CLREOP",	#26
	"PRBLOCK(",#27
	"STOP",	#28
	"COPY(",	#29
	"FILL(",	#2a
	"MASK(",	#2b
	"RSECT(",	#2c
	"WSECT(",	#2d
	"RBLOCK(",	#2e
	"WBLOCK(",	#2f
	"WTRACK(",	#30
	"WSYNC(",	#31
	"RECAL(",	#32
	"DISPLAY(",#33
	"RTRACK(",	#34
	"RSYNC(",	#35
	"BEEP(",	#36
	"DISASM(",	#37
	"TEXT",	#38
	"FORMAT(",	#39
	"SETFORMAT(",#3a
	"WORKDRIVE ",#3b
	"INIT ",	#3c
	"LOAD ",	#3d
	"SAVE ",	#3e
	"CATALOG",	#3f
	"DELETE ",	#40
	"RENAME ",	#41
	"PACK ",	#42
	"CONVERT(",#43
	"INPUT(",	#44
	"LORES",	#45
	"PLOT(",	#46
	"HLINE(",	#47
	"VLINE(",	#48
	"COLOR=",	#49
	"FIND(",	#4a
	"HIRES",	#4b
	"HCOLOR=",	#4c
	"HPLOT",	#4d
	"CALL(",	#4e
	"PR#",	#4f
	"IN#",	#50
	"FILTER(",	#51
	"LIST",	#52
	"RUN",	#53
	"AUXMOVE(",#54
	"LCMOVE(",	#55
	"DELAY(",	#56
	"INTEGER",	#57
	"BYTE",	#58
	" AND ",	#59
	" OR ",	#5a
	" MOD ",	#5b
	" XOR ",	#5c
	" WITH ",	#5d
	" TO ",	#5e
	" AT ",	#5f
	"TAB(",	#60
	"ENDCASE",	#61
	"MON:",	#62
	"EDIT",	#63
	"SAVE@"	#64
]


	#check whether a given series of bytes can be a valid NADOL tokenised file
	#heuristics are:
	# - bytes 
	def  NADOLTokenisedFile.can_be_nadol_tokenised_file?(buffer)
		r=true
		i=0
		while i<buffer.length
			line_length=buffer[i]
			if buffer[i+line_length-1]!=0 then
				r=false
				break
			end
			i+=line_length
		end
		r
	end
	
	def to_s
		NADOLTokenisedFile.buffer_as_tokenised_file(@contents)
	end
	def file_extension
		".nad"
	end

	private
	def  NADOLTokenisedFile.buffer_as_tokenised_file(buffer)
		s=""
		index=0
		while (index<buffer.length)
			line_length=buffer[index]
			index+=1
			end_of_line=index+line_length-2
			while(index<end_of_line)
				b=buffer[index]
				if (b<=0x64) then
					s+=NADOL_EDITOR_TOKENS[b]
				elsif(b>0x70 and b<0x80) then
					s+=" "*(b-0x70)
				elsif(b>=0x80) then
					s+=(b-0x80).chr
				else
					raise sprintf("unknown token %02X at offset %04X",b,index)
				end
				index+=1 #move to next char
			end
			index+=1 #skip over end-of-line marker
			s+="\n"
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
