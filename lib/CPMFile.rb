$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'DSKFile'
require 'HGR'

class CPMFile < DSKFile
  attr_accessor :file_type
	def initialize(filename,contents,file_type)
		raise "filename too long - #{filename}" unless filename.length<=15
		@filename=filename
		@contents=contents
    @file_type=file_type
	end
  
  def full_filename
    "#{@filename}.#{@file_type}"
  end
    
	def to_s
    @contents
	end
  
	def file_extension
		return "."+@file_type.downcase
	end

	def can_be_picture?		
		file_type==:foto && HGR.can_be_hgr_screen?(@contents)
	end

	def to_png(pallete_mode=:amber)
		HGR.buffer_to_png(@contents,pallete_mode)
	end
end

class MBASICFile<CPMFile
  
  #the CP/M MBASIC file format is very similar to the MS-DOS BASICA/GWBASIC formats, described at
  #http://www.chebucto.ns.ca/~af380/GW-BASIC-tokens.html
  #The differences are:
  #     tokens have different values
  #     the order of bytes in the floating byte values is reversed. i.e +1.5 is stored as 0x00,0x00,0x40,0x81 not 0x81,0x40,0x00,0x00

  SINGLE_BYTE_TOKENS={
	0x81=>'END',
	0x82=>'FOR',
	0x83=>'NEXT',
	0x84=>'DATA',
	0x85=>'INPUT',
	0x86=>'DIM',
	0x87=>'READ',
	0x88=>'LET',
	0x89=>'GOTO',
	0x8A=>'RUN',
	0x8B=>'IF',
	0x8C=>'RESTORE',
	0x8D=>'GOSUB',
	0x8E=>'RETURN',
	0x8F=>'REM',
	0x90=>'STOP',
	0x91=>'PRINT',
	0x92=>'CLEAR',
	0x93=>'LIST',
	0x94=>'NEW',
	0x95=>'ON',
	0x96=>'DEF',
	0x97=>'POKE',
	0x98=>'CONT',
	0x9B=>'LPRINT',
	0x9C=>'LLIST',
	0x9D=>'WIDTH',
	0x9E=>'ELSE',
	0x9F=>'TRACE',
	0xA0=>'NOTRACE',
	0xA1=>'SWAP',
	0xA2=>'ERASE',
	0xA3=>'EDIT',
	0xA4=>'ERROR',
	0xA5=>'RESUME',
	0xA6=>'DEL',
	0xA7=>'AUTO',
	0xA8=>'RENUM',
	0xA9=>'DEFSTR',
	0xAA=>'DEFINT',
	0xAB=>'DEFSNG',
	0xAC=>'DEFDBL',
	0xAD=>'LINE',
	0xAE=>'POP',
	0xAF=>'WHILE',
	0xB0=>'WEND',
	0xB1=>'CALL',
	0xB2=>'WRITE',
	0xB3=>'COMMON',
	0xB4=>'CHAIN',
	0xB5=>'OPTION',
	0xB6=>'RANDOMIZE',
	0xB7=>'SYSTEM',
	0xB8=>'OPEN',
	0xB9=>'FIELD',
	0xBA=>'GET',
	0xBB=>'PUT',
	0xBC=>'CLOSE',
	0xBD=>'LOAD',
	0xBE=>'MERGE',
	0xBF=>'FILES',
	0xC0=>'NAME',
	0xC1=>'KILL',
	0xC2=>'LSET',
	0xC3=>'RSET',
	0xC4=>'SAVE',
	0xC5=>'RESET',
	0xC6=>'TEXT',
	0xC7=>'HOME',
	0xC8=>'VTAB',
	0xC9=>'HTAB',
	0xCA=>'INVERSE',
	0xCB=>'NORMAL',
	0xCC=>'GR',
	0xCD=>'COLOR',
	0xCE=>'HLIN',
	0xCF=>'VLIN',
	0xD0=>'PLOT',
	0xD1=>'HGR',
	0xD2=>'HPLOT',
	0xD3=>'HCOLOR',
	0xD4=>'BEEP',
	0xD5=>'WAIT',
	0xDD=>'TO',
	0xDE=>'THEN',
	0xDF=>'TAB(',
	0xE0=>'STEP',
	0xE1=>'USR',
	0xE2=>'FN',
	0xE3=>'SPC(',
	0xE4=>'NOT',
	0xE5=>'ERL',
	0xE6=>'ERR',
	0xE7=>'STRING$',
	0xE8=>'USING',
	0xE9=>'INSTR',
	0xEA=>"'",
	0xEB=>'VARPTR',
	0xEC=>'SCRN',
	0xED=>'HSCRN',
	0xEE=>'INKEY$',
	0xEF=>'>',
	0xF0=>'=',
	0xF1=>'<',
	0xF2=>'+',
	0xF3=>'-',
	0xF4=>'*',
	0xF5=>'/',
	0xF6=>'^',
	0xF7=>'AND',
	0xF8=>'OR',
	0xF9=>'XOR',
	0xFA=>'EQV',
	0xFB=>'IMP',
	0xFC=>'MOD',
	0xFD=>'\\',
}
DOUBLE_BYTE_TOKENS={
	0x81=>'LEFT$',
	0x82=>'RIGHT$',
	0x83=>'MID$',
	0x84=>'SGN',
	0x85=>'INT',
	0x87=>'SQR',
	0x88=>'RND',
	0x89=>'SIN',
	0x8A=>'LOG',
	0x8B=>'EXP',
	0x8C=>'COS',
	0x8D=>'TAN',
	0x8E=>'ATN',
	0x8F=>'FRE',
	0x90=>'POS',
	0x91=>'LEN',
	0x92=>'STR$',
	0x93=>'VAL',
	0x94=>'ASC',
	0x95=>'CHR$',
	0x96=>'PEEK',
	0x97=>'SPACE$',
	0x98=>'OCT$',
	0x99=>'HEX$',
	0x9A=>'LPOS',
	0x9B=>'CINT',
	0x9C=>'CSNG',
	0x9D=>'CDBL',
	0x9E=>'FIX',
	0xAA=>'CVI',
	0xAB=>'CVS',
	0xAC=>'CVD',
	0xAE=>'EOF',
	0xAF=>'LOC',
	0xB0=>'LOF',
	0xB1=>'MKI$',
	0xB2=>'MKS$',
	0xB3=>'MKD$',
	0xB4=>'VPOS',
	0xB5=>'PDL',
	0xB6=>'BUTTON',
}


def to_s
  if @contents[0]==0xFF then
    buffer_as_gbasic(@contents)
  else
    @contents
  end
end

def parse_bytes_as_float(bytes)
	return 0.0 if bytes[0]==0
	exponent=2**(bytes[0]-0x80)
	first_byte=bytes[1]
	sign=-1.0	#assume it's negative
	if first_byte<0x80 then
		sign=1.0
		first_byte+=0x80
	end	
	mantissa=(first_byte/256.0)*sign
	2.upto(bytes.length-1) do |i|
		mantissa+=(bytes[i]/(256.0**i))
	end
	return sprintf("%8f",exponent*mantissa).to_f
end


def buffer_as_gbasic(buffer)
	s=""
	p=1
	while(p<buffer.length) && (buffer[p]!=0)
		p+=2	#skip the 2 byte pointer to the start of next line
		line_number=buffer[p]+(buffer[p+1]<<8)
		p+=2
		s+= "#{line_number} "		
		while(p<buffer.length) && (buffer[p]!=0)
			c=buffer[p]
			p+=1

			if (c==0x3A) then 	#if its a ':'

				if buffer[p]==0x9E then	#ELSE is actually stored as :ELSE
					c=buffer[p]
					p+=1
				end
				if buffer[p]==0x8F then	#' is actually stored as :REM'					
					c=buffer[p+1]
					p+=2
				end
			end
			if c<0x20 then
				case (c)
					when 0x0B	#OCTAL CONSTANT
						constant=buffer[p]+(buffer[p+1]<<8)
						s+=sprintf("&O%o",constant)
						p+=2

					when 0x0C	#HEX CONSTANT
						constant=buffer[p]+(buffer[p+1]<<8)
						s+=sprintf("&H%X",constant)
						p+=2
					when 0x0E	#DECIMAL LINE NUMBER
						constant=buffer[p]+(buffer[p+1]<<8)
						s+=sprintf("%d",constant)
						p+=2
					when 0x0F	#one byte constant
						constant=buffer[p]
						s+=sprintf("%d",constant)
						p+=1
					when 0x11..0x1B	#packed constant 0..9
						s+=sprintf("%d",c-0x11)
					when 0x1C	#DECIMAL LINE NUMBER
						constant=buffer[p]+(buffer[p+1]<<8)
						s+=sprintf("%d",constant)
						p+=2
          when 0x1D #4 byte floating point
          	constant=parse_bytes_as_float(buffer[p..p+3].reverse)
            s+=constant.to_s
            p+=4
          when 0x1F #8 byte floating point
          	constant=parse_bytes_as_float(buffer[p..p+7].reverse)
            s+=constant.to_s
            p+=8
				end

			elsif c<0x80 then
				s+=c.chr
			else

				if c==0xFF then
					
					c=buffer[p]
					p+=1
					token=DOUBLE_BYTE_TOKENS[c]
				else
					token=SINGLE_BYTE_TOKENS[c]
				end
				s+=(token.nil?) ? sprintf("[%02X]",c):token


			end
		end
		s+="\n"
	p+=1
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
