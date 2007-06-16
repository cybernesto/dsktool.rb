$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'D65'

#Apple DOS 3.3 file
class DOSFile
	
	attr_accessor(:filename,:locked,:file_type,:sector_count,:contents) 
	def initialize(filename,locked,sector_count,contents)
		@filename=filename
		@locked=locked
		@sector_count=sector_count
		@file_type="?"
		@contents=contents
	end

	#File type as displayed in Apple DOS 3.3 Catalog
	def file_type
	end

	def to_s
		@contents
	end

end

class TextFile < DOSFile
	def file_type
		"T"
	end

	def file_extension
		".txt"
	end

	def to_s
		s=""
		@contents.each_byte{|b| s+=(b%0x80).chr.tr(0x0D.chr,"\n")}
		s
	end
end

class BinaryFile < DOSFile
	def file_type
		"B"
	end
	
	def file_extension
		".bin"
	end

	def disassembly
			start_address=(@contents[0]+@contents[1]*256)
			D65.disassemble(@contents[2..@contents.length-1],start_address)
	end
end

class IntegerBasicFile < DOSFile
	def file_type
		"I"
	end
	
	def file_extension
		".bas"
	end
	
	#display file with all INTEGER BASIC tokens expanded to ASCII
	def to_s
		buffer_as_integer_basic_file(@contents)
	end	

private

IB_REM_TOKEN =0x5D
IB_UNARY_PLUS = 0x35
IB_UNARY_MINUS = 0x36
IB_QUOTE_START = 0x28
IB_QUOTE_END = 0x29
INTEGER_BASIC_TOKENS=  [
        # $00-$0F 
        "HIMEM:","<$01>", "_",     " : ",
        "LOAD",  "SAVE",  "CON",   "RUN",  #  Direct commands 
        "RUN",   "DEL",   ",",     "NEW",
        "CLR",   "AUTO",  ",",     "MAN",

        # $10-$1F 
        "HIMEM:","LOMEM:","+",     "-",     # Binary ops 
        "*",     "/",     "=",     "#",
        ">=",    ">",     "<=",    "<>",
        "<",     "AND",   "OR",    "MOD",

        # $20-$2F
        "^",     "+",     "(",     ",",
        "THEN",  "THEN",  ",",     ",",
        "\"",    "\"",    "(",     "!",
        "!",     "(",     "PEEK",  "RND",

        # $30-$3F 
        "SGN",   "ABS",   "PDL",   "RNDX",
        "(",     "+",     "-",     "NOT",   # Unary ops 
        "(",     "=",     "#",     "LEN(",
        "ASC(",  "SCRN(", ",",     "(",

        # $40-$4F
        "$",     "$",     "(",     ",",
        ",",     ";",     ";",     ";",
        ",",     ",",     ",",     "TEXT",  # Statements 
        "GR",    "CALL",  "DIM",   "DIM",

        # $50-$5F 
        "TAB",   "END",   "INPUT", "INPUT",
        "INPUT", "FOR",   "=",     "TO",
        "STEP",  "NEXT",  ",",     "RETURN",
        "GOSUB", "REM",   "LET",   "GOTO",

        # $60-$6F
        "IF",    "PRINT", "PRINT", "PRINT",
        "POKE",  ",",     "COLOR=","PLOT",
        ",",     "HLIN",  ",",     "AT",
        "VLIN",  ",",     "AT",    "VTAB",

        # $70-$7F 
        "=",     "=",     ")",     ")",
        "LIST",  ",",     "LIST",  "POP",
        "NODSP", "DSP",  "NOTRACE","DSP",
        "DSP",   "TRACE", "PR#",   "IN#",
    ]


# Adapted from FID.C -- a utility to browse Apple II .DSK image files by Paul Schlyter (pausch@saaf.se)
# FID was downloaded from http://stjarnhimlen.se/apple2/
 #   Integer Basic file format:
 #
 #   <Length_of_file> (16-bit little endian)
 #   <Line>
 #   ......
 #   <Line>
 #
 #   where <Line> is:
 #      1 byte:   Line length
 #      2 bytes:  Line number, binary little endian
 #      <token>
 #      <token>
 #      <token>
 #      .......
 #      <end-of-line token>
 #
 #   <token> is one of:
 #      $12 - $7F:   Tokens as listed below: 1 byte/token
 #      $80 - $FF:   ASCII characters with high bit set
 #      $B0 - $B9:   Integer constant, 3 bytes:  $B0-$B9,
 #                     followed by the integer value in
 #                     2-byte binary little-endian format
 #                     (Note: a $B0-$B9 byte preceded by an
 #                      alphanumeric ASCII(hi_bit_set) byte
 #                      is not the start of an integer
 #                      constant, but instead part of a
 #                      variable name)
 #
 #   <end-of-line token> is:
 #      $01:         One byte having the value $01
 #                   (Note: a $01 byte may also appear
 #                    inside an integer constant)
 #
 #  Note that the tokens $02 to $11 represent commands which
 #  can be executed as direct commands only -- any attempt to
 #  enter then into an Integer Basic program will be rejected
 #  as a syntax error.  Therefore, no Integer Basic program
 #  which was entered through the Integer Basic interpreter
 #  will contain any of the tokens $02 to $11.  The token $00
 #  appears to be unused and won't appear in Integer Basic
 #  programs either.  However, $00 is used as an end-of-line
 #  marker in S-C Assembler source files, which also are of
 #  DOS file type "I".
 #
 #  (note here a difference from Applesoft Basic, where there
 #  are no "direct mode only" commands - any Applesoft commands
 #  can be entered into an Applesoft program as well).
 #
 #

	def is_alnum(c)
		!((c.chr=~/[A-Za-z0-9]/).nil?)
	end
	def buffer_as_integer_basic_file(buffer)

		length=buffer[0]+buffer[1]*256
		index=2
		s=""

		while (index<length)
			in_REM = false
			in_QUOTE = false
			lead_SP = false
			last_AN = false
			last_TOK = false

			line_length=buffer[index]
			index+=1 #skip over the "line length" field
			line_no=buffer[index]+buffer[index+1]*256
			index+=2 #skip over the "line number" field
			s+=sprintf("%u ",line_no)
			done_line=false
			while (!done_line)			
				lead_SP = lead_SP || last_AN
				b=buffer[index]
				if (b >= 0x80 ) then
					if ( !in_REM && !in_QUOTE && !last_AN && (b>= 0xB0 && b <= 0xB9) ) then
						integer = buffer[index+1]+buffer[index+2]*256
						index+=2
						s+=sprintf( (last_TOK && lead_SP ) ? " %d" : "%d", integer )
						lead_SP = true
					else
				
						c = b & 0x7F
						if (!in_REM && !in_QUOTE && last_TOK && lead_SP && is_alnum(c)) then
							s+=" "
						end
						if ( c >= 0x20 ) then
							s+=c.chr						
						else
							s+="^"+(c+0x40).chr
						end
						last_AN = is_alnum(c)
					end
					last_TOK =false			
				else
					
					token = INTEGER_BASIC_TOKENS[b]
					lastchar = token[token.length-1]
					case b
						when IB_REM_TOKEN then in_REM = true
						when IB_QUOTE_START then in_QUOTE = true
						when IB_QUOTE_END then in_QUOTE = false
					end
					
					if lead_SP && ( is_alnum(token[0]) ||
						    b == IB_UNARY_PLUS ||
						    b == IB_UNARY_MINUS ||
						    b == IB_QUOTE_START  ) then
						s+=" "
					end
					s+=token
					last_AN  = false
					lead_SP = is_alnum(lastchar) || lastchar == ')' || lastchar == '\"'
					last_TOK = true
				end
				index+=1
				done_line=(index>length)||(buffer[index]==0x01)
			end
			s+="\n"
			index+=1        # skip over "end of line" marker
		end
	       s
	end

end


class AppleSoftFile < DOSFile

	
	def file_type
		"A"
	end
	#display file with all AppleSoft BASIC tokens expanded to ASCII
	def to_s
		buffer_as_applesoft_file(@contents)
	end	
	
	def file_extension
		".bas"
	end

private

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

# Adapted from FID.C -- a utility to browse Apple II .DSK image files by Paul Schlyter (pausch@saaf.se)
# FID was downloaded from http://stjarnhimlen.se/apple2/
#
#Applesoft file format:
#
#<Length_of_file> (16-bit little endian)
#<Line>
#......
#<Line>
#
#where <Line> is:
#<Next addr>  (16-bit little endian)
#<Line no>    (16-bit little endian: 0-65535)
#<Tokens and/or characters>
#<End-of-line marker: $00 $00 bytes>
#


	def buffer_as_applesoft_file(buffer)

		length=buffer[0]+buffer[1]*256
		index=2
		s=""
		while (index<length)
			index+=2 #skip over the "next address" field
			line_no=buffer[index]+buffer[index+1]*256
			index+=2 #skip over the "line number" field
			s+=sprintf("%u ",line_no)
			done_line=false
			while (!done_line)
				b=buffer[index]
				if b>=0x80 then
					s+=APPLESOFT_TOKENS[b-0x80]+" "
				else
					s+=b.chr
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
