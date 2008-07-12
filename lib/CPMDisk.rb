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
	attr_accessor :free_blocks,:free_directory_entries
  RECORD_SIZE=128
  BLOCK_SIZE=1024
  BLOCKS_PER_EXTENT=16
  RECORDS_PER_BLOCK=BLOCK_SIZE/RECORD_SIZE
  RECORDS_PER_EXTENT=RECORDS_PER_BLOCK*BLOCKS_PER_EXTENT
  
 SECTORS_IN_BLOCK=[
    [0x00,0x06,0x0C,0x03],  #block 0
    [0x09,0x0F,0x0E,0x05],  #block 1
    [0x0B,0x02,0x08,0x07],  #block 2
    [0x0D,0x04,0x0A,0x01]  #block 3
  ]
  
  def get_block(block_no)
    track_no= ((block_no/4)+3)%track_count
    s=""
    SECTORS_IN_BLOCK[block_no%4].each {|sector_no|s+=get_sector(track_no,sector_no)}
    s
  end

  def set_block(block_no,contents)
    raise "invalid block #{block_no} - length was #{contents.length}" unless contents.length==BLOCK_SIZE
    track_no=(block_no/4)+3
    0.upto(3) do |i|
      sector_no=SECTORS_IN_BLOCK[block_no%4][i]
      set_sector(track_no,sector_no,contents[(i*256),256])
    end  
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
	
  def make_file(filename,contents,file_options={})
    return CPMFile.new(filename,contents)
  end

  
  def delete_file(full_filename)
    catalog=get_block(0)+get_block(1)
    (partial_filename,file_ext)=CPMFile.split_filename(full_filename)
    0.upto(63) do |dir_entry_no|
      dir_entry_start=dir_entry_no*0x20
      dir_entry=catalog[dir_entry_start..dir_entry_start+0x1F]              
      if (partial_filename==dir_entry[0x01..0x08].gsub(' ','')) && (file_ext==dir_entry[0x09..0x0B].gsub(' ',''))      
        #we found a matching filename, so set the 'user number' field to a 'blank' entry
        catalog[dir_entry_start]=0xE5
      end
    end
    
    set_block(0,catalog[0,BLOCK_SIZE])
    set_block(1,catalog[BLOCK_SIZE,BLOCK_SIZE])
    self.read_catalog
  end  
  
  def add_file(file)
    raise "only CPMFiles may be added to CPM format disks!" unless file.kind_of?(CPMFile)
    delete_file(file.full_filename) #so we can overwrite the file if it already exists  
    
    total_record_count=(file.contents.length/RECORD_SIZE.to_f).ceil
    total_blocks_needed=(total_record_count/RECORDS_PER_BLOCK.to_f).ceil    
    total_extents_needed=(total_blocks_needed/BLOCKS_PER_EXTENT.to_f).ceil
    
    raise "#{total_blocks_needed} free blocks required, only #{free_blocks.length} available" unless total_blocks_needed<=free_blocks.length
    raise "#{total_extents_needed} free directory entries required, only #{free_directory_entries.length} available" unless total_extents_needed<=free_directory_entries.length
    catalog=get_block(0)+get_block(1)
    padded_file_contents=file.contents+(0x1A.chr*BLOCK_SIZE)
    
    0.upto(total_extents_needed-1) do |extent_no|
      records_this_extent=(extent_no==(total_extents_needed-1) ? (total_record_count % RECORDS_PER_EXTENT):RECORDS_PER_EXTENT)
      blocks_this_extent=(records_this_extent/RECORDS_PER_BLOCK.to_f).ceil
      blocks_used=[0]*BLOCKS_PER_EXTENT
      first_record_this_extent=extent_no*RECORDS_PER_EXTENT
      contents_this_extent=padded_file_contents[(first_record_this_extent*RECORD_SIZE),blocks_this_extent*BLOCK_SIZE]
      
      0.upto(blocks_this_extent-1) do |block_no|
          this_block=free_blocks[block_no+(extent_no*BLOCKS_PER_EXTENT)]
          set_block(this_block,contents_this_extent[block_no*BLOCK_SIZE,BLOCK_SIZE])
          blocks_used[block_no]=this_block
      end
      dir_entry_no=free_directory_entries[extent_no]
      dir_entry_start=dir_entry_no*0x20
      dir_entry=[0,file.filename,file.file_type,extent_no,0,0,records_this_extent,blocks_used].flatten.pack("CA8A3C4C16")
      catalog[dir_entry_start..dir_entry_start+0x1F]=dir_entry
    end
    
    set_block(0,catalog[0,BLOCK_SIZE])
    set_block(1,catalog[BLOCK_SIZE,BLOCK_SIZE])
    self.read_catalog

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
    @free_blocks=[]
    @free_directory_entries=[]
    @files={}
    #first two blocks are where the catalog lives
    (2..((track_count-3)*4)-1).each {|block| @free_blocks<<block}
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
          file=MBASICFile.new("#{file_name}.#{file_ext}",'')
        else
          file=CPMFile.new("#{file_name}.#{file_ext}",'')
        end
        if @files[file.full_filename].nil? then
          @files[file.full_filename]=file 
        end
        s=""
        0x10.upto(0x1f) do |i|
          block=dir_entry[i]
          @free_blocks.delete(block)
          s+=get_block(block) unless block==0
        end        
        records_allocated=dir_entry[0x0F]
        @files[file.full_filename].contents+=s[0,(records_allocated*128)]
      else
        @free_directory_entries<<dir_entry_no
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
