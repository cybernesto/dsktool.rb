$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'ProDOSFile'
# Disk image in ProDOS format
# for now, assumes 'ProDOS order'
class ProDOSDisk < DSK
	attr_accessor :volume_name
	
	#what is the last block on this disk?
	def last_block
		(self.track_count*8)-1
	end
	def dump_catalog
		s=""
		files.each { |file|
			s<< "#{sprintf('% 6d',file.contents.length)}\t #{file.file_type} : $#{sprintf '%X',file.aux_type}\t#{file.full_filename}\n"
		}
		s
	end

	def initialize(file_bytes,sector_order)
		super(file_bytes,sector_order)
		self.read_catalog
	end

	def file_system
		:prodos
	end


	#concatenate all the blocks in the volume directory
	#Volume Directory format is: (from "Beneath Apple ProDOS pp 4-10 - 4-12)
	# FOR VOLUMES
	# $00	 	STORAGE_TYPE/NAME_LENGTH
	# $01-$0F	FILE_NAME 
	# $10		RESERVED
	# $11-$12	RESERVED
	# $13-$14	RESERVED
	# $15-$17	RESERVED
	# $18-$1B	CREATION
	# $1C		VERSION
	# $1D		MIN_VERSION
	# $1E		ACCESS
	# $1F		ENTRY_LENGTH
	# $20		ENTRIES_PER_BLOCK
	# $21-$22	FILE_COUNT
	# $23-$24	BIT_MAP_POINTER
	# $25-$26	TOTAL_BLOCKS
	#
	# FOR FILES
	# $00	 	STORAGE_TYPE/NAME_LENGTH
	# $01-$0F	FILE_NAME 
	# $10		FILE_TYPE
	# $11-$12	KEY_POINTER
	# $13-$14	BLOCKS_USED
	# $15-$17	EOF
	# $18-$1B	CREATION
	# $1C		VERSION
	# $1D		MIN_VERSION
	# $1E		ACCESS
	# $1F-$20	AUX_TYPE
	# $21-$24	LAST_MOD
	# $25-$26	HEADER_POINTER

	def dump_block(block_no)
		s=hline
		s<<sprintf("BLOCK %03d\n",block_no)
		s<< "\t"
		block_data=get_block(block_no)
		(0..15).each {|x| s<<sprintf("%02X ",x) }
		s<<"\n"
		s<<hline
		(0..31).each {|line_number|
			 lhs=""
			 rhs=""
			 start_byte=line_number*16
			 line=block_data[start_byte..start_byte+15]
			 line.each_byte {|byte|
				  lhs<< sprintf("%02X ", byte)
				  rhs<< (byte%128).chr.sub(/[\x00-\x1f]/,'.')
		 	}
			s<<sprintf("%03X\t%s %s\n",start_byte,lhs,rhs)
		}
		s
	end

	def read_catalog(starting_block=2,dir_path="")
		next_block_no=starting_block
		while (next_block_no!=0)
			block=get_block(next_block_no)
			offset=4
			while (offset<(0x200-0x27))
				directory_entry=block[offset..offset+0x27]
				storage_type=directory_entry[0]>>4
				name_length=directory_entry[0]%0x10
				name=directory_entry[1..name_length]
				file_type=directory_entry[0x10]
				key_pointer=directory_entry[0x11]+directory_entry[0x12]*0x100
				blocks_used=directory_entry[0x13]+directory_entry[0x14]*0x100
				file_length=directory_entry[0x15]+directory_entry[0x16]*0x100+directory_entry[0x17]*0x10000
				aux_type=directory_entry[0x1f]+directory_entry[0x20]*0x100
        full_filename="#{dir_path}#{name}"
				case storage_type
					when 0x00 then
						#nop
					when 0x01 then  #it's a seedling
						file_contents=get_block(key_pointer)            
						files<<ProDOSFile.new(name,file_contents,file_type,aux_type,full_filename)
					when 0x02 then  #it's a sapling
						block_list=[]
						index_block=get_block(key_pointer)
						0.upto((file_length/0x200)) do |i|
							block_list<<index_block[i]+(index_block[i+0x100]*0x100)
						end
						file_contents=""
						block_list.each do |next_block_no|
							if next_block_no==0 then
								file_contents+="\x00"*0x200
							elsif next_block_no>self.last_block then
								STDERR<<"file #{name} attempted to read bad block # #{next_block_no}\n"
								file_contents+="\x00"*0x200
							else
								file_contents+=get_block(next_block_no)
							end
						end
						file_contents=file_contents[0..file_length-1]            
						files<<ProDOSFile.new(name,file_contents,file_type,aux_type,full_filename)
					when 0x03 then  #it's a tree
						master_index_block=get_block(key_pointer)
						block_list=[]
						number_of_index_entries=1+(file_length/0x200)
						number_of_index_blocks=1+(number_of_index_entries/0x100)
						number_of_index_entries_in_last_block=number_of_index_entries-(number_of_index_blocks-1)*0x100
						0.upto(number_of_index_blocks-1) do |i|
							index_block_no=master_index_block[i]+master_index_block[i+0x100]*0x100
							index_block=get_block(index_block_no)
							if i==number_of_index_blocks-1 then 
								entries_in_this_index_block=number_of_index_entries_in_last_block
							else 
								entries_in_this_index_block=256
							end
							0.upto(entries_in_this_index_block-1) do |j|
								block_list<<index_block[j]+(index_block[j+0x100]*0x100)
							end
						end
						file_contents=""
						block_list.each do |next_block_no|
							if next_block_no==0 then
								file_contents+="\x00"*0x200
							else
								file_contents+=get_block(next_block_no)
							end
						end
						file_contents=file_contents[0..file_length-1]
						files<<ProDOSFile.new(name,file_contents,file_type,aux_type,full_filename)
					when 0x0D then 	#it's a subdirectory pointer
						read_catalog(key_pointer,"#{dir_path}#{name}/")
					when 0x0E then 	#it's a subdirectory header
						#do nothing 
					when 0x0F then 	#it's a volume						
						@volume_name=name 
					else 
#						raise "unknown storage_type #{sprintf '%02X',storage_type}"
						puts "skipping unknown storage_type #{sprintf '%02X',storage_type} for #{dir_path}#{name}"
				end			
				offset+=0x27
			end
			next_block_no=block[2]+block[3]*256
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
