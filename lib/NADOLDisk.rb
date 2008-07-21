$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

# Disk image in NADOL format
#
#CATALOG will be at track $00, sector $03 to track $00, sector $09
#each entry consists of $10 bytes, which are:
# 00-0B - filename - if file is deleted, first byte will be FF
# 0C-0D - filesize (low byte first)
# 0E - track of track sector list sector
# 0F - sector of track sector list sector
#
#TRACK/SECTOR LIST FORMAT 
# pairs of track/sectors in order. up to 128 entries [assumes that no file can be > 128 sectors]
#
#SECTOR USAGE BITMAP
#is at Track $00, Sector $2, from bytes $20 .. $65
#bitmap is of form:
#
# ----hi bit--
# |             |
# 01234567 89ABCDEF
#  ^^^^^^      ^^^^^^^
#   low byte    hi byte

require 'NADOLFile'

class NADOLDisk < DSK

	def dump_catalog
		s=""
		files.each { |file|		
			s<< "#{sprintf('% 6d',file.contents.length)} #{file.filename}\n"
		}
		s
	end

	def initialize(file_bytes,sector_order)
		super(file_bytes,sector_order)
		self.read_catalog
	end

	def file_system
		:nadol
	end


def set_sector(track,sector,contents)
  super(track,sector,contents)  
  
  #now mark sector as used in sector usage list
  #don't bother marking the 'system' sectors used
  if ((track>0) || (sector>9)) then
    sector_usage_bitmap_sector=get_sector(0,2)  
    offset_of_byte_containing_this_sector=0x20+(track*2)+(sector/8)
    byte_containing_this_sector=sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]
    byte_containing_this_sector=byte_containing_this_sector|(2**(7-(sector%8)))
    sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]=byte_containing_this_sector
    set_sector(0,2,sector_usage_bitmap_sector)
  end
end


#iterate through the CATALOG to find either the named file or (if nil is passed in) an empty slot
def find_catalog_slot(filename)
  track=0
  sector=3
  catalog_filename=NADOLFile.catalog_filename(filename.upcase) unless filename.nil?
  while (sector<=9) do
    sector_data=get_sector(track,sector)
    (0..15).each do |slot_no|
      slot_start=slot_no*0x10
      if (filename.nil? && (sector_data[slot_start]==0x00)|| (sector_data[slot_start]==0xFF)) then
        return DSKTrackSector.new(track,sector,slot_start)
      end
      if (!filename.nil?) && (sector_data[slot_start..slot_start+0x0B]==catalog_filename) then
        return DSKTrackSector.new(track,sector,slot_start)
      end
    end
    sector+=1
  end
  nil
end

#iterate through the sector usage bitmap, return a list of [track,sector] for sectors marked available
def free_sector_list  
  sector_usage_bitmap=get_sector(0,2)[0x20..0x65]
   free_sectors=[]
    (0..(sector_usage_bitmap.length/2)-1).each do |track|
      track_bitmap_lo=sector_usage_bitmap[track*2]
      track_bitmap_hi=sector_usage_bitmap[1+track*2]
      (0..7).each do |sector|
        if ((track_bitmap_lo & (2**(7-sector)))==0) then
          free_sectors<<DSKTrackSector.new(track,sector)
        end
        if ((track_bitmap_hi & (2**(7-sector)))==0) then
          free_sectors<<DSKTrackSector.new(track,sector+8)
        end        
      end
    end
    free_sectors.sort  
end

def make_file(filename,contents,file_options={})
  if (file_options[:tokenise]) then
    return NADOLTokenisedFile.new(filename,NADOLTokenisedFile.tokenise(contents))  
  else
    return NADOLFile.new(filename,contents)
  end
end

  def delete_file(filename)
    this_files_catalog_slot=find_catalog_slot(filename)    
    #if file not in catalog, do nothing
    return if this_files_catalog_slot.nil? 
    file_descriptive_entry=get_sector(this_files_catalog_slot.track_no,this_files_catalog_slot.sector_no)[this_files_catalog_slot.offset..this_files_catalog_slot.offset+0x0f]
    
    #mark sector as free in sector usage list
    sector_usage_bitmap_sector=get_sector(0,2)  
    sectors_to_mark_available=get_track_sector_list(file_descriptive_entry[0x0E],file_descriptive_entry[0x0F])
    sectors_to_mark_available<<DSKTrackSector.new(file_descriptive_entry[0x0E],file_descriptive_entry[0x0F])
    sectors_to_mark_available.each do |ts|
      offset_of_byte_containing_this_sector=0x20+(ts.track_no*2)+(ts.sector_no/8)
      byte_containing_this_sector=sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]
      byte_containing_this_sector=byte_containing_this_sector&(0xff-(2**(7-(ts.sector_no%8))))
      sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]=byte_containing_this_sector
    end
    set_sector(0,2,sector_usage_bitmap_sector)
    
    #mark slot as available in catalog
    catalog_sector=get_sector(this_files_catalog_slot.track_no,this_files_catalog_slot.sector_no)
    catalog_sector[this_files_catalog_slot.offset]=0xFF
    set_sector(this_files_catalog_slot.track_no,this_files_catalog_slot.sector_no,catalog_sector)
  end
  
  
  #given a track and sector, treat it as a track/sector list and return an array containing track/sector pairs
  def get_track_sector_list(ts_list_track_no,ts_list_sector_no)
    ts_list_sector=get_sector(ts_list_track_no,ts_list_sector_no)
    ts_list=[]
    for entry_number in 0..0x7f    
      data_track_no=ts_list_sector[entry_number*2]
      data_sector_no=ts_list_sector[entry_number*2+1]
      if( (data_track_no!=0 || data_sector_no!=0)  && data_track_no<track_count && data_sector_no<=0x0f) then
        ts_list<<DSKTrackSector.new(data_track_no,data_sector_no)
      end
    end
    ts_list
  end
  
#add a file to the in-memory image of this DSK 
 def add_file(file)
   raise "only NADOLFiles may be added to NADOL format disks!" unless file.kind_of?(NADOLFile)
   
  delete_file(file.filename) unless files[file.filename].nil?
  catalog_slot=find_catalog_slot(nil)
  raise "CATALOG IS FULL!" if catalog_slot.nil?
  
  free_sectors=free_sector_list
    
  sectors_needed=1+file.length_in_sectors
  raise "not enough free space - #{sectors_needed} sectors needed, #{free_sector_list.length} available " unless sectors_needed<=free_sectors.length
  
  #for each sector in the file, copy it to disk and then record it in the track/sector list
  track_sector_list="\0"*256
  track_sector_list_sector=free_sectors[0]
  (0..sectors_needed-2).each do |sector_in_file|
    sector_to_use=free_sectors[sector_in_file+1]
    track_sector_list[sector_in_file*2]=sector_to_use.track_no
    track_sector_list[(sector_in_file*2)+1]=sector_to_use.sector_no
    sector_contents=file.contents[(sector_in_file*256)..(sector_in_file*256)+255] || ""
    set_sector(sector_to_use.track_no,sector_to_use.sector_no,sector_contents)
  end
  #write the track/sector list
  set_sector(track_sector_list_sector.track_no,track_sector_list_sector.sector_no,track_sector_list)
  
  #update the catalog
  catalog_sector=get_sector(catalog_slot.track_no,catalog_slot.sector_no)
  catalog_sector[catalog_slot.offset..catalog_slot.offset+0x0B]=file.catalog_filename
  catalog_sector[catalog_slot.offset+0x0C]=file.contents.length % 0x100
  catalog_sector[catalog_slot.offset+0x0D]=file.contents.length / 0x100
  catalog_sector[catalog_slot.offset+0x0E]=track_sector_list_sector.track_no
  catalog_sector[catalog_slot.offset+0x0F]=track_sector_list_sector.sector_no
  set_sector(catalog_slot.track_no,catalog_slot.sector_no,catalog_sector)
  
  raise "catalog not updated correctly!" if find_catalog_slot(file.filename).nil?
  #reread the catalog to populate the files list
  read_catalog
 end
 
	#reads the catalog, and populate the "files" array with files
	#CATALOG will be at track $00, sector $03 to track $00, sector $09
	#each entry consists of $10 bytes, which are:
	# 00-0B - filename - if file is deleted, first byte will be FF
	# 0C-0D - filesize (low byte first)
	# 0E - track of track sector list sector
	# 0F - sector of track sector list sector
	def read_catalog
    @files=FileContainer.new
    track=0
    sector=3
    while (sector<=9) do
      sector_data=get_sector(track,sector)
      (0..15).each do |slot_no|
        slot_offset=slot_no*0x10
        file_descriptive_entry=sector_data[slot_offset..slot_offset+0x10]
        if (file_descriptive_entry[0]!=0xFF && file_descriptive_entry[0]!=0x00) then # skip deleted /empty files
          filename=""
          file_descriptive_entry[0..11].to_s.each_byte{|b| filename+=(b.%128).chr} #strip off high bit
          filename.sub!(/ *$/,"") #strip off trailing spaces
          file_size=file_descriptive_entry[0x0D]*256+file_descriptive_entry[0x0C]
          if (file_size>0) then
            contents=""	
            get_track_sector_list(file_descriptive_entry[0x0E],file_descriptive_entry[0x0F]).each do |ts|
              contents<<get_sector(ts.track_no,ts.sector_no)
            end
            contents=contents[0..file_size-1]
            if (NADOLTokenisedFile.can_be_nadol_tokenised_file?(contents)) then
              @files<< NADOLTokenisedFile.new(filename,contents)
            else
              @files<<NADOLBinaryFile.new(filename,contents)
            end
          end
        end
      end
    sector+=1
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
