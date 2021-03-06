$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'D65'
require 'DSKFile'
require 'HGR'

#Apple DOS 3.3 file
class DOSFile < DSKFile
	
	attr_accessor(:filename,:contents,:locked,:file_type_byte) 
	def initialize(filename,contents,locked=false,file_type_byte=nil)
		@filename=filename
		@locked=locked
		@contents=contents
    @file_type_byte=file_type_byte
    @file_type=sprintf("$%02X",file_type_byte)
  end


	#File type as displayed in Apple DOS 3.3 Catalog
	def file_type
		@file_type
	end
  def file_type_byte
		@file_type_byte
	end
  
#render a filename in form suitable for inclusion in a DOS catalog
  def  DOSFile.catalog_filename(filename)
    s=""
    for i in 0..29
      c=(filename[i])
      if c.nil? then
        c=0xA0        
        else 
        c=(c|0x80)
      end
      s+=c.chr
    end
    s
  end

  def catalog_filename
    DOSFile.catalog_filename(filename)
  end

end

class TextFile < DOSFile
	def file_type
		"T"
	end
  
  def file_type_byte
		0x00
	end

	def file_extension
		".txt"
	end

	def to_s
		s=""
		@contents.each_byte{|b| s+=(b%0x80).chr.tr(0x0D.chr,"\n")}    
    return s.sub(/\0*$/,"")    
	end

end

class BinaryFile < DOSFile
	def file_type
		"B"
	end
  
	def file_type_byte
		0x04
	end

	def file_extension
		".bin"
	end

	def contents_without_header
		file_length=contents[2]+contents[3]*256
		@contents[4..file_length+3]
	end
	def disassembly
		start_address=(@contents[0]+@contents[1]*256)
		D65.disassemble(contents_without_header,start_address)
	end

	def can_be_picture?
		start_address=(@contents[0]+@contents[1]*256)
		HGR.can_be_hgr_screen?(contents_without_header,start_address)
	end

	def to_png(pallete_mode=:amber)
		HGR.buffer_to_png(contents_without_header,pallete_mode)
	end
end

# Adapted from FID.C -- a utility to browse Apple II .DSK image files by Paul Schlyter (pausch@saaf.se)
 #Integer Basic file format:
 # <Length_of_file> (16-bit little endian)
 # <Line>
 # ......
 # <Line>
 #
 # where <Line> is:
 # 1 byte:   Line length
 # 2 bytes:  Line number, binary little endian
 # <token>
 # <token>
 # <token>
 # ......
 # <end-of-line token>
 #
 # <token> is one of:
 # $12 - $7F:   Tokens as listed below: 1 byte/token
 # $80 - $FF:   ASCII characters with high bit set
 # $B0 - $B9:   Integer constant, 3 bytes:  $B0-$B9,
 #                     followed by the integer value in
 #                     2-byte binary little-endian format
 #                     (Note: a $B0-$B9 byte preceded by an
 #                      alphanumeric ASCII(hi_bit_set) byte
 #                      is not the start of an integer
 #                      constant, but instead part of a
 #                      variable name)
 #
 # <end-of-line token> is:
 # $01:         One byte having the value $01
 #                   (Note: a $01 byte may also appear
 #                    inside an integer constant)
 #
 # Note that the tokens $02 to $11 represent commands which
 # can be executed as direct commands only -- any attempt to
 # enter then into an Integer Basic program will be rejected
 # as a syntax error.  Therefore, no Integer Basic program
 # which was entered through the Integer Basic interpreter
 # will contain any of the tokens $02 to $11.  The token $00
 # appears to be unused and won't appear in Integer Basic
 # programs either.  However, $00 is used as an end-of-line
 # marker in S-C Assembler source files, which also are of
 # DOS file type "I".
 #
 # (note here a difference from Applesoft Basic, where there
 # are no "direct mode only" commands - any Applesoft commands
 # can be entered into an Applesoft program as well).
class IntegerBasicFile < DOSFile
	def file_type
		"I"
	end
	
	def file_extension
		".bas"
	end
	
  def file_type_byte
		0x01
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

  def file_type_byte
		0x02
	end

	#display file with all AppleSoft BASIC tokens expanded to ASCII
	def to_s
		buffer_as_applesoft_file(@contents)
	end	
	
	def file_extension
		".bas"
	end
end

#Apple MusiComp / MusicMaster files are binary files with the following structure:
#00..01  where to load to (like any BIN file)
#02..03 length of file
#04..end of file = <data>, where data is of the form...
#         00..31     : note (4 octaves, note 0=D, 1=D#, 2=E, 3=F etc)
#         32..        : rest
#         80..FF     : "mode"
#                        bits 0..1 = timbre            
#                        bits 2..4 = length (whole,half,quarter,8th,sixteenth,dotted half,dotted quarter,dotted 8th)
#                        bits 5..6 = mode: the options are 0=H>S, 1=H>H, 2=S>S. but not sure what that actually means

class MusiCompFile < BinaryFile
  NOTES=["D","D#","E","F","F#","G","G#","A","A#","B","C","C#"]
 
  NOTE_LENGTHS=[
	"whole",
	"half",
	"quarter",
	"8th",
	"sixteenth",
	"dotted half",
	"dotted quarter",
	"dotted 8th",
]

  NOTE_MODES=[:H_S,:H_H, :S_S]
  TIMBRES=[	"Bright Acoustic Piano",	"Harmonica",	"Electric Guitar (clean)",	"French Horn"]

  def MusiCompFile.can_be_musicomp_file?(filename,contents)
    return false unless filename=~/ ;MU.{0,3}$/
    track_length=(contents[0x02,2].unpack("v")[0])-2
    return (track_length<contents.length-4)
  end
  
  def file_extension 
    ".mid"
  end
  
  def can_be_midi?
    true
  end
  
  def to_s
    to_midi
  end
  
  def to_midi
    track_length=(@contents[0x02,2].unpack("v")[0])-2
    track_contents=@contents[4,track_length]
    require 'midilib/sequence'
    require 'midilib/consts'
    seq = MIDI::Sequence.new()
    track = MIDI::Track.new(seq)
    seq.tracks << track
    track.events << MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(130))
    track.events << MIDI::MetaEvent.new(MIDI::META_SEQ_NAME, @filename)
    length=NOTE_LENGTHS[0]
    delta=seq.note_to_delta(length)
    #track.events << MIDI::ProgramChange.new(0, 25, 0)
    
    track_contents.each_byte do |byte|
      if byte==50 then  #rest
        track.events << MIDI::NoteOnEvent.new(0, 0, 0, 0)
        track.events << MIDI::NoteOffEvent.new(0, 0, 0, delta)
        
      elsif byte<=0x80 then #a note
        note=NOTES[byte%12]
        octave=byte/4	
        track.events << MIDI::NoteOnEvent.new(0, 14 + byte, 127, 0)
        track.events << MIDI::NoteOffEvent.new(0, 14 + byte, 127,  delta)

      else #mode control code
        mode=NOTE_MODES[byte%4]
        length=NOTE_LENGTHS[(byte/4)%8]
        delta=seq.note_to_delta(length)
        timbre=(byte/32)%4
      end
    end
    require 'stringio'
    op=StringIO.new("","wb")
    seq.write(op)
    op.string
    end
end

# Adapted from FID.C -- a utility to browse Apple II .DSK image files by Paul Schlyter (pausch@saaf.se)
#
#   S-C Assembler file format:
#
#  <Length_of_file> (16-bit little endian)
#  <Line>
#  ......
#  <Line>
#
#  where <Line> is:
#  <Length>     (8-bit: including length byte, line no, contents, zero>
#  <Line no>    (16-bit little endian: 0-65535)
#  <Characters>
#  <Zero byte>  ($00, to mark the end of the S-C Asm source line)
#
#  where <Characters> are an arbitrary sequence of:
#  <Literal character>:      $20 to $7E - literal characters
#  <Compressed spaces>:      $80 to $BF - represents 1 to 63 spaces
#  <Compressed repetition>:  $C0 <n> <ch> - represents <ch> n times
 #

class SCAsmFile < DOSFile
	def file_type
		"I"
	end

  def file_type_byte
		0x01
	end

	#display file with all tokens expanded
	def to_s
		SCAsmFile.buffer_as_scasm_file(@contents)
	end	
	
	def file_extension
		".asm"
	end

	def SCAsmFile.can_be_scasm_file?(buffer)
		if buffer.length<2 then
			return false
		end
		length=buffer[0]+buffer[1]*256
		index=2
		s=""
		while (index<length)
			line_length=buffer[index]
			line_no=buffer[index+1]+buffer[index+2]*256
			index+=3 #skip over the "line number" field
			#S-C Assembler lines always ends with a 0x00 
			if ( buffer[index+line_length-4] != 0x00 )
				return false
			end
			buffer[index..index+line_length-3].each_byte do |b|
					if b>0xc0 then
						return false
					end
			end
			index+= (line_length-3).abs
		end
		return true
	end
	
private
	def SCAsmFile.buffer_as_scasm_file(buffer)
		length=buffer[0]+buffer[1]*256
		index=2
		s=""
		while (index<length)
			line_length=buffer[index]
			line_no=buffer[index+1]+buffer[index+2]*256
			s+=sprintf("%d ",line_no)
			index+=3 #skip over the "line number" field
			end_of_line=index+line_length-4
			while(index<end_of_line)
				b=buffer[index]
				if (b==0xC0) then
					repeat_count=buffer[index+1]
					repeat_char=(buffer[index+2]).chr
					s+=repeat_char*repeat_count
					index+=3
				elsif(b>=0x80) then
					s+=" "*(b-0x80)
					index+=1
				else
					s+=b.chr
					index+=1
				end
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
