$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# Disk image with CPM File System
#catalog  will be on track 2
#CPM DIR looks like this:
#$00        User number, or E5h if it's a free entry 
#$01..0B   Filename + extension: 8+3 characters 
#$0C..0D  Extent number of this entry 
#$0E..0F  Number of 128-byte records used in last alloc. block 
#$10..1F  Allocation map for this directory entry

require 'CPMFile'
class CPMDisk < DSK
	
 SECTORS_IN_BLOCK=[
    [0x00,0x06,0x0C,0x03],  #block 0
    [0x09,0x0F,0x0E,0x05],  #block 1
    [0x0B,0x02,0x08,0x07],  #block 2
    [0x0D,0x04,0x0A,0x01]  #block 3
  ]
  
  def get_block(block_no)
    track_no=(block_no/4)+3
    s=""
    SECTORS_IN_BLOCK[block_no%4].each {|sector_no|s+=get_sector(track_no,sector_no)}
    s
  end
	def dump_catalog
		s=""
		files.keys.sort.each { |file_name|		
			file=files[file_name]	
			s<< sprintf("% 12s % 6d \n",file.full_filename,file.contents.length)
		}
		s
	end

	def initialize(file_bytes,sector_order)    
		super(file_bytes,sector_order)
		self.read_catalog
	end

	def file_system
		:cpm
	end
	
	#reads the directory, and populate the "files" array with files
  #CPM DIR looks like this:
  #$00        User number, or E5h if it's a free entry 
  #$01..0B   Filename + extension: 8+3 characters 
  #$0C..0D  Extent number of this entry 
  #$0E       ???
  #$0F       Number of 128-byte records allocated in this extant
  #$10..1F  Allocation map for this directory entry
	def read_catalog
    catalog=get_block(0)+get_block(1)
    #require 'DumpUtilities'
    #puts DumpUtilities.hex_dump(catalog)
    0.upto(63) do |dir_entry_no|
      #puts dir_entry_no
      dir_entry_start=dir_entry_no*0x20
      dir_entry=catalog[dir_entry_start..dir_entry_start+0x1F]      
      if (dir_entry[0]<0x10) then
        file_name=dir_entry[0x01..0x08].gsub(' ','')
        file_ext=dir_entry[0x09..0x0B].gsub(' ','')
        
        
        if (file_ext=="BAS") then
          file=MBASICFile.new(file_name,'',file_ext)
        else
          file=CPMFile.new(file_name,'',file_ext)
        end
        @files[file.full_filename]=file if @files[file.full_filename].nil?
        s=""
        0x10.upto(0x1f) do |i|
          block=dir_entry[i]
          s+=get_block(block) unless block==0
        end
        
        records_allocated=dir_entry[0x0F]
        @files[file.full_filename].contents+=s[0..(records_allocated*128)-1]
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
