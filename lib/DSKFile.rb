$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))



#Generic Apple II file
class DSKFile	
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

# Adapted from FID.C -- a utility to browse Apple II .DSK image files by Paul Schlyter (pausch@saaf.se)
#
#Applesoft file format:
# <Length_of_file> (16-bit little endian)
# <Line>
# ......
# <Line>
# where <Line> is:
# <Next addr>  (16-bit little endian)
# <Line no>    (16-bit little endian: 0-65535)
# <Tokens and/or characters>
# <End-of-line marker: $00 >
#
	APPLESOFT_TOKENS = [
	       "END","FOR","NEXT","DATA","INPUT","DEL","DIM","READ",
		"GR","TEXT","PR#","IN#","CALL","PLOT","HLIN","VLIN",
		"HGR2","HGR","HCOLOR=","HPLOT","DRAW","XDRAW","HTAB",
		"HOME","ROT=","SCALE=","SHLOAD","TRACE","NOTRACE",
		"NORMAL","INVERSE","FLASH","COLOR=","POP","VTAB",
		"HIMEM=","LOMEM=","ONERR","RESUME","RECALL","STORE",
		"SPEED=","LET","GOTO","RUN","IF","RESTORE","&","GOSUB",
		"RETURN","REM","STOP","ON","WAIT","LOAD","SAVE","DEF",
		"POKE","PRINT","CONT","LIST","CLEAR","GET","NEW",
		"TAB(","TO","FN","SPC(","THEN","AT","NOT","STEP","+",
		"-","*","/","^","AND","OR",">","=","<","SGN","INT",
		"ABS","USR","FRE","SCRN(","PDL","POS","SQR","RND",
		"LOG","EXP","COS","SIN","TAN","ATN","PEEK","LEN",
		"STR$","VAL","ASC","CHR$", "LEFT$","RIGHT$","MID$","?",
		"?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?","?"
]

	def buffer_as_applesoft_file(buffer)

		length=buffer[0]+buffer[1]*256
		index=2
		s=""
		while (index<length)
			index+=2 #skip over the "next address" field
			break if buffer[index].nil?
			break if buffer[index+1].nil?
			line_no=buffer[index]+buffer[index+1]*256
			index+=2 #skip over the "line number" field
			s+=sprintf("%u",line_no)
			done_line=false
			last_char_space=false
			while (!done_line)			
				b=buffer[index]
				break if b.nil?
				if b>=0x80 then
					if !last_char_space then
						s+=" "
					end
					s+=APPLESOFT_TOKENS[b-0x80]+" "
					last_char_space=true
				else
					s+=b.chr
					last_char_space=false
				end
				index+=1
				done_line=(index>=length)||(buffer[index]==0)
			end
			s+="\n"
			index+=1        # skip over "end of line" marker
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
