$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
class D65
# 6502 Disassembler with annotations
# based on 6502disassembler.js : n. landsteiner, electronic tradion 2005; e-tradion.net

unless defined?(OPCODES) then
OPCODES= [
	['BRK',:imp], ['ORA',:inx], ['???',:imp], ['???',:imp], #00..03
	['TSB',:zpg], ['ORA',:zpg], ['ASL',:zpg], ['???',:imp], #04..07
	['PHP',:imp], ['ORA',:imm], ['ASL',:acc], ['???',:imp], #08..0b
	['TSB',:abs], ['ORA',:abs], ['ASL',:abs], ['???',:imp], #0c..0f
	['BPL',:rel], ['ORA',:iny], ['ORA',:inz], ['???',:imp], #10..13
	['TRB',:zpg], ['ORA',:zpx], ['ASL',:zpx], ['???',:imp], #14..17
	['CLC',:imp], ['ORA',:aby], ['INC',:acc], ['???',:imp], #18..1B
	['INC',:abs], ['ORA',:abx], ['ASL',:abx], ['???',:imp], #1c..1f
	['JSR',:abs], ['AND',:inx], ['???',:imp], ['???',:imp], #20..23
	['BIT',:zpg], ['AND',:zpg], ['ROL',:zpg], ['???',:imp], #24..27
	['PLP',:imp], ['AND',:imm], ['ROL',:acc], ['???',:imp], #28..2b
	['BIT',:abs], ['AND',:abs], ['ROL',:abs], ['???',:imp], #2c..2f
	['BMI',:rel], ['AND',:iny], ['AND',:inz], ['???',:imp], #30..33
	['BIT',:zpx], ['AND',:zpx], ['ROL',:zpx], ['???',:imp], #34..37
	['SEC',:imp], ['AND',:aby], ['DEC',:acc], ['???',:imp], #38..3b
	['BIT',:inx], ['AND',:abx], ['ROL',:abx], ['???',:imp], #3c..3f
	['RTI',:imp], ['EOR',:inx], ['???',:imp], ['???',:imp], #40..43
	['???',:imp], ['EOR',:zpg], ['LSR',:zpg], ['???',:imp], #44..47
	['PHA',:imp], ['EOR',:imm], ['LSR',:acc], ['???',:imp], #48..4b
	['JMP',:abs], ['EOR',:abs], ['LSR',:abs], ['???',:imp], #4c..4f
	['BVC',:rel], ['EOR',:iny], ['EOR',:inz], ['???',:imp], #50..53
	['???',:imp], ['EOR',:zpx], ['LSR',:zpx], ['???',:imp], #54..57
	['CLI',:imp], ['EOR',:aby], ['PHY',:imp], ['???',:imp], #58..5b
	['???',:imp], ['EOR',:abx], ['LSR',:abx], ['???',:imp], #5c..5f
	['RTS',:imp], ['ADC',:inx], ['???',:imp], ['???',:imp], #60..63
	['STZ',:zpg], ['ADC',:zpg], ['ROR',:zpg], ['???',:imp], #64..67
	['PLA',:imp], ['ADC',:imm], ['ROR',:acc], ['???',:imp], #68..6b
	['JMP',:ind], ['ADC',:abs], ['ROR',:abs], ['???',:imp], #6c..6f
	['BVS',:rel], ['ADC',:iny], ['ADC',:inz], ['???',:imp], #70..73
	['STZ',:zpx], ['ADC',:zpx], ['ROR',:zpx], ['???',:imp], #74..77
	['SEI',:imp], ['ADC',:aby], ['PLY',:imp], ['???',:imp], #78..7b
	['JMP',:inx], ['ADC',:abx], ['ROR',:abx], ['???',:imp], #7c..7f
	['BRA',:rel], ['STA',:inx], ['???',:imp], ['???',:imp], #80..83
	['STY',:zpg], ['STA',:zpg], ['STX',:zpg], ['???',:imp], #84..87
	['DEY',:imp], ['BIT',:imm], ['TXA',:imp], ['???',:imp], #88..8b
	['STY',:abs], ['STA',:abs], ['STX',:abs], ['???',:imp], #8c..8f
	['BCC',:rel], ['STA',:iny], ['STA',:inz], ['???',:imp], #90..93
	['STY',:zpx], ['STA',:zpx], ['STX',:zpy], ['???',:imp], #94..97
	['TYA',:imp], ['STA',:aby], ['TXS',:imp], ['???',:imp], #98..9b
	['STZ',:abs], ['STA',:abx], ['STZ',:abx], ['???',:imp], #9c..9f
	['LDY',:imm], ['LDA',:inx], ['LDX',:imm], ['???',:imp], #a0..a3
	['LDY',:zpg], ['LDA',:zpg], ['LDX',:zpg], ['???',:imp], #a4..a7
	['TAY',:imp], ['LDA',:imm], ['TAX',:imp], ['???',:imp], #a8..ab
	['LDY',:abs], ['LDA',:abs], ['LDX',:abs], ['???',:imp], #ab..af
	['BCS',:rel], ['LDA',:iny], ['LDA',:inz], ['???',:imp], #b0..b3
	['LDY',:zpx], ['LDA',:zpx], ['LDX',:zpy], ['???',:imp], #b4..b7
	['CLV',:imp], ['LDA',:aby], ['TSX',:imp], ['???',:imp], #b8..bb
	['LDY',:abx], ['LDA',:abx], ['LDX',:aby], ['???',:imp], #bc..bf
	['CPY',:imm], ['CMP',:inx], ['???',:imp], ['???',:imp], #c0..c3
	['CPY',:zpg], ['CMP',:zpg], ['DEC',:zpg], ['???',:imp], #c4..c7
	['INY',:imp], ['CMP',:imm], ['DEX',:imp], ['???',:imp], #c8..cb
	['CPY',:abs], ['CMP',:abs], ['DEC',:abs], ['???',:imp], #cc..cf
	['BNE',:rel], ['CMP',:iny], ['CMP',:inz], ['???',:imp], #d0..d3
	['???',:imp], ['CMP',:zpx], ['DEC',:zpx], ['???',:imp], #d4..d7
	['CLD',:imp], ['CMP',:aby], ['PHX',:imp], ['???',:imp], #d8..db
	['???',:imp], ['CMP',:abx], ['DEC',:abx], ['???',:imp], #db..df
	['CPX',:imm], ['SBC',:inx], ['???',:imp], ['???',:imp], #e0..e3
	['CPX',:zpg], ['SBC',:zpg], ['INC',:zpg], ['???',:imp], #e4..e7
	['INX',:imp], ['SBC',:imm], ['NOP',:imp], ['???',:imp], #e8..eb
	['CPX',:abs], ['SBC',:abs], ['INC',:abs], ['???',:imp], #ec..ef
	['BEQ',:rel], ['SBC',:iny], ['SBC',:ind], ['???',:imp], #f0..f3
	['???',:imp], ['SBC',:zpx], ['INC',:zpx], ['???',:imp], #f4..f7
	['SED',:imp], ['SBC',:aby], ['PLX',:imp], ['???',:imp], #f8..fb
	['???',:imp], ['SBC',:abx], ['INC',:abx], ['???',:imp]  #fc..ff
]


OPCODE_SIZE={
	:imp,1,
	:acc,1,
	:imm,2,
	:abs,3,
	:abx,3,
	:aby,3,
	:zpg,2,
	:zpx,2,
	:zpy,2,
	:ind,3,
	:inx,2,
	:iny,2,
	:inz,2,
	:rel,2
} 
	
end
	require 'yaml'  unless defined? YAML 
	@@annotations=YAML::load(File.open(File.dirname(__FILE__)+"/a2_symbols.yaml"))

	#map of memory locations and annotations
	#e.g. {0xFF3A=>"BELL - writes a ^G to stdout"}
	def D65.annotations
		@@annotations
	end


	def D65.disassemble(buffer,start_address=0)
	
		index=0
		s=""
		while index<buffer.length
			byte=buffer[index]
			current_address=start_address+index
			opcode_name=OPCODES[byte][0]
			operand_type=OPCODES[byte][1]
			next_byte=(index<buffer.length-1?buffer[index+1]:0)
			next_word=(index<buffer.length-2?buffer[index+1]+buffer[index+2]*256:0)
			operand_format,operand_address= case operand_type
				when :imp then ['','']
				when :acc then ["A",'']
				when :imm then ["\#$%02X",next_byte]
				when :abs then ["$%04X",next_word]
				when :abx then ["$%04X,X",next_word]
				when :aby then ["$%04X,Y",next_word]
				when :zpg then ["$%02X",next_byte]
				when :zpx then ["$%02X,X",next_byte]
				when :zpy then ["$%02X,Y",next_byte]
				when :ind then ["($%04X)",next_word]
				when :inx then ["($%04X),X",next_word]
				when :iny then ["($%04X),Y",next_word]
				when :inz then ["($%02X),Y",next_byte]
				when :rel then ["$%04X",(current_address+next_byte.chr.unpack("c")[0]+2)%0x10000]
				else 
					abort("unknown symbol #{operand_type}")
			end
			operand = sprintf(operand_format,operand_address)
			opcode_size=OPCODE_SIZE[operand_type]
			instruction_bytes=case opcode_size
				when 1 then sprintf("%02X      ",byte)
				when 2 then sprintf("%02X %02X   ",byte,next_byte)
				when 3 then sprintf("%02X %02X %02X",byte,next_byte,next_word>>8)
			end

			
			s<<sprintf("%04X:  %s %s %s  ; ",current_address,instruction_bytes,opcode_name,operand.ljust(10))
			annotation=annotations[operand_address]
			if (annotation && (operand_type!=:imm)) then
				s<<"  "+annotation.to_s
			end
			s<< "\n"
			index+=opcode_size
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
