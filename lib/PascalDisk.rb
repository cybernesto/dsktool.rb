$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# Disk image with Pascal File System
#catalog  will be at block 2.
#each entry consists of $1A bytes, which are:
#VOLUME HEADER
#	00..01 FIRST BLOCK (word)	
#	02..03 LAST BLOCK+1 (word)
#	04 	FILE TYPE (byte) =  untypedfile,xdskfile,codefile,textfile,infofile,datafile,graffile,fotofile,securdir
#	05 	FILLER
#	06	VOLUME NAME LENGTH (1 byte)
#	07..0D	VOLUME NAME (17 bytes)
#	0E..0F 	VOLUME SIZE (WORD)
#	10 	NUMBER OF FILES (BYTE)
#	11..1A	FILLER
#
#FILES
#	00..01 	FIRST BLOCK (word)	
#	02..03 	LAST BLOCK+1 (word)
#	04 	FILE TYPE (byte) =  untypedfile,xdskfile,codefile,textfile,infofile,datafile,graffile,fotofile,securdir
#	05 	STATUS (byte)
#	06	FILENAME LENGTH (1 byte)
#	07..16	FILENAME (15 bytes)
#	17..18 	BYTES IN LAST BLOCK (word)
#	19..1A	FILE ACCESS DATE 

require 'PascalFile'
class PascalDisk < DSK
	attr_accessor :volume_name

	def dump_catalog
		s=""
		files.each { |file|		
			s<< "#{sprintf('% 6d',file.contents.length)}\t #{file.file_type}\t#{file.filename}\n"
		}
		s
	end


	def initialize(file_bytes,sector_order)    
		super(file_bytes,sector_order)
		self.read_catalog
	end

	def file_system
		:pascal
	end
	
	#reads the catalog, and populate the "files" array with files
	def read_catalog
        catalog=get_block(2)
        #we've read the first block in the catalog, now read the rest
        catalog_size=catalog[2]
        3.upto(catalog_size-1) do |i|
          catalog<<get_block(i)
        end
#	06	VOLUME NAME LENGTH (1 byte)
#	07..0D	VOLUME NAME (17 bytes)
#	0E..0F 	VOLUME SIZE (WORD)
#	10 	NUMBER OF FILES (BYTE)
        volume_name_length=catalog[6]
        self.volume_name=catalog[7..6+volume_name_length]
        files_in_volume=catalog[0x10]
        #read in all the files
        
#	00..01 	FIRST BLOCK (word)	
#	02..03 	LAST BLOCK+1 (word)
#	04 	FILE TYPE (byte) =  untypedfile,xdskfile,codefile,textfile,infofile,datafile,graffile,fotofile,securdir
#	05 	STATUS (byte)
#	06	FILENAME LENGTH (1 byte)
#	07..15	FILENAME (15 bytes)
#	16..17 	BYTES IN LAST BLOCK (word)
#	18.1A	FILE ACCESS DATE
        1.upto(files_in_volume) do |file_no|
          file_record=catalog[file_no*0x1a..(file_no*0x1a+0x19)]
          first_block=file_record[0]+file_record[1]*0x100
          first_block_in_next_file=file_record[2]+file_record[3]*0x100
          last_block=first_block_in_next_file-1
          file_type=file_record[4]
          file_name_length=file_record[6]
          file_name=file_record[7..6+file_name_length]
          bytes_in_last_block=file_record[0x16]+file_record[0x17]*0x100
          file_contents=""
          first_block.upto(last_block) do |block_no|
            this_block=get_block(block_no)
            if block_no==last_block then
              file_contents<<this_block[0..bytes_in_last_block-1]
            else
              file_contents<<this_block 
            end
          files<<PascalFile.new(file_name,file_contents,file_type)
        end        
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
