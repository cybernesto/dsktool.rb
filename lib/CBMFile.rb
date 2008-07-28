$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'D64'
require 'FSImageFile'
#CBM DOS File


class CBMFile		< FSImageFile
  attr_reader :file_type  
  def initialize(filename,contents,file_type)
    super(filename,contents)
    @file_type=file_type
  end
  
  def to_ascii
    CBMImage.p2a(contents)
  end
  
  def directory_entry
    sprintf "%-16s  %3s  $%04X",filename,file_type,contents.length
  end

  def can_be_basic?
    return false unless file_type=="PRG"
    return false unless @contents[0]==0x01 && @contents[1]==0x08
    true
  end

  def to_s
    if can_be_basic? then
      to_cbm_basic_file
    else
         CBMImage.p2a(contents)
    end
  end
  
  def contents_without_header
		@contents[2..@contents.length-1]
	end
  
	def disassembly
    require 'D65'
		start_address=(@contents[0]+@contents[1]*256)
		D65.disassemble(contents_without_header,start_address)
	end

  
CBM_BASIC_TOKENS={
0x80=>"END",
0x81=>"FOR",
0x82=>"NEXT",
0x83=>"DATA",
0x84=>"INPUT#",
0x85=>"INPUT",
0x86=>"DIM",
0x87=>"READ",
0x88=>"LET",
0x89=>"GOTO",
0x8A=>"RUN",
0x8B=>"IF",
0x8C=>"RESTORE",
0x8D=>"GOSUB",
0x8E=>"RETURN",
0x8F=>"REM",
0x90=>"STOP",
0x91=>"ON",
0x92=>"WAIT",
0x93=>"LOAD",
0x94=>"SAVE",
0x95=>"VERIFY",
0x96=>"DEF",
0x97=>"POKE",
0x98=>"PRINT#",
0x99=>"PRINT",
0x9A=>"CONT",
0x9B=>"LIST",
0x9C=>"CLR",
0x9D=>"CMD",
0x9E=>"SYS",
0x9F=>"OPEN",
0xA0=>"CLOSE",
0xA1=>"GET",
0xA2=>"NEW",
0xA3=>"TAB(",
0xA4=>"TO",
0xA5=>"FN",
0xA6=>"SPC(",
0xA7=>"THEN",
0xA8=>"NOT",
0xA9=>"STEP",
0xAA=>"+",
0xAB=>"-",
0xAC=>"*",
0xAD=>"/",
0xAE=>"^",
0xAF=>"AND",
0xB0=>"OR",
0xB1=>">",
0xB2=>"=",
0xB3=>"<",
0xB4=>"SGN",
0xB5=>"INT",
0xB6=>"ABS",
0xB7=>"USR",
0xB8=>"FRE",
0xB9=>"POS",
0xBA=>"SQR",
0xBB=>"RND",
0xBC=>"LOG",
0xBD=>"EXP",
0xBE=>"COS",
0xBF=>"SIN",
0xC0=>"TAN",
0xC1=>"ATN",
0xC2=>"PEEK",
0xC3=>"LEN",
0xC4=>"STR$",
0xC5=>"VAL",
0xC6=>"ASC",
0xC7=>"CHR$",
0xC8=>"LEFT$",
0xC9=>"RIGHT$",
0xCA=>"MID$",
0xCB=>"GO",
0xFF=>"PI",
  }
  
#the following codes have special functions in strings
 CBM_CHR_CODES={
  5=>"<WHITE>",
  14=>"<LOWER CASE>",
  17=>"<DOWN>",
  18=>"<RVS ON>",
  19=>"<CLR/HOME>",
  20=>"<INST/DEL>",
  28=>"<RED>",
  29=>"<RIGHT>",
  30=>"<GRN>",
  31=>"<BLU>",
  129=>"<ORANGE>",
  133=>"<F1>",
  134=>"<F3>",
  135=>"<F5>",
  136=>"<F7>",
  137=>"<F2>",
  138=>"<F4>",
  139=>"<F6>",
  140=>"<F8>",
  141=>"<SHIFT RETURN>",
  142=>"<UPPER CASE>",
  144=>"<BLK>",
  145=>"<DOWN>",
  146=>"<RVS OFF>",
  147=>"<CLR/HOME>",
  148=>"<INST/DEL>",
  149=>"<BROWN>",
  150=>"<LT RD>",
  151=>"<GREY 1>",
  152=>"<GREY 2>",
  153=>"<LT GREEN>",
  154=>"<LT BLUE>",
  155=>"<GREY 3>",
  156=>"<PUR>",
  157=>"<LEFT>",
  158=>"<YEL>",
  159=>"<CYN>"

}
  #CBM Basic files have the following structure;
  # first 2 bytes in file are mem address for file to be relocated to
  # then come 1 or more lines. each line has following structure:
  # <2 bytes start of next line in RAM>
  # <2 bytes line number>
  # <tokens>
  # 0 byte
  def to_cbm_basic_file
    s=""
    p=2 #skip over first 2 bytes, which are where a PRG file would get relocated to
    end_of_file=false
    #
    while p<@contents.length && !end_of_file do
      p+=2 #skip over the pointer to the next line in RAM
      line_number=@contents[p]+(@contents[p+1]<<8)
      s+=sprintf("%d ",line_number)
      p+=2 
      end_of_line=false
      in_quotes=false
      while p<@contents.length && !end_of_line do
        b=@contents[p]
        p+=1
        if b==0 then 
          end_of_line=true
          s+="\n"
        elsif in_quotes && !CBM_CHR_CODES[b].nil? then
          s+=CBM_CHR_CODES[b]
        elsif b==0x22 then
          in_quotes=!in_quotes
          s+=0x22.chr          
        elsif b>=0x80 && !in_quotes then
          token=CBM_BASIC_TOKENS[b]
          s+=(token.nil? ? "<UNKNOWN TOKEN $#{sprintf("%2X",b)}>": token)        
        else           
          s+=b.chr
        end 
      end
      end_of_file=(@contents[p]==0 && @contents[p+1]==0) #is the address of the next line $0000?
    end
    s
  end
end


# == Author
# Jonno Downes (jonno@jamtronix.com)
#
# == Copyright
# Copyright (c) 200873490- Jonno Downes (jonno@jamtronix.com)
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
