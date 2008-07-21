$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'DOSFile'

#
# Disk image with a standard Apple DOS 3.3 VTOC at track $11, sector $00
#
#
#VTOC : Volume Table of Contents (from Beneath Apple DOS pp 4-2 & 4-3)
# 00    not used
# 01    track number of first catalog sector
# 02    sector number of first catalog sector
# 03    release number of DOS used to INIT this disk
# 04-05 not used
# 06    Diskette volume number (1-254)
# 07-26 not used
# 27    maximum number of track/sector pairs which will fit in one file track/sector
#	list sector (122 for 256 byte sectors)
# 28-2F not used
# 30    last track where sectors were allocated
# 31    direction of track allocation (+1 or -1)
# 32-33 not used
# 34    number of tracks per diskette (normally 35)
# 35    number of sectors per track (13 or 16)
# 36-37 number of bytes per sector (LO/HI format)
# 38-3B bit map of free sectors in track 0
# 3C-3F bit map of free sectors in track 1
# 40-43 bit map of free sectors in track 2
#	...
# BC-BF bit map of free sectors in track 33
# CO-C3 bit map of free sectors in track 34
# C4-FF bit maps for additional tracks if there are more than 35 tracks per diskette
#
#CATALOG (from Beneath Apple DOS p 4-6)
# 00    Not Used
# 01    track number of next catalog sector
# 02    sector number of next catalog sector
# 03-0A not used
# 0B-2D First file descriptive entry
# 2E-50 Second file descriptive entry
# 51-73 Third file descriptive entry
# 74-96 Fourth file descriptive entry
# 97-B9 Fifth file descriptive entry
# BA-DC Sixth file descriptive entry
# DD-FF Seventh file descriptive entry
#
#FILE DESCRIPTIVE ENTRY (from Beneath Apple DOS p 4-6)
# 00    Track of first track/sector list sector, if this is a deleted file this contains FF
#	and the original track number is copied to the last byte of the file name (BYTE 20)
#	If this byte contains a 00, the entry is assumed to never have been used and is
#	available for use. (This means track 0 can never be used for data even if the DOS image
#	is 'wiped' from the disk)
#
# 01    Sector of first track/sector list sector
# 02    File type and flags:
#	80+file type - file is locked
#	00+file type - file is not locked
#
#	00 - TEXT file
#	01 - INTEGER BASIC file
#	02 - APPLESOFT BASIC file
#	04 - BINARY file
#	08 - S type file
#	10 - RELOCATABLE object module file
#	20 - a type file
#	40 - b type file
#
# 03-20 File Name (30 characters)
# 21-22 Length of file in sectors (LO/HI format)
#
#	
#TRACK/SECTOR LIST FORMAT (from Beneath Apple DOS p 4-6)
# 00	Not used
# 01	Track number of next T/S list of one is needed or zero if no more t/s list
# 02 	Sector number of next T/S list (if one is present)
# 03-04	Not used
# 05-06	Sector offset in file of the first sector described by this list
# 07-oB	Not used
# 0C-0D	Track and sector of first data sector or zeros
# 0E-0F	Track and sector of second data sector or zeros
# 10-FF	Up to 120 more track and sector pairs


class DOSDisk < DSK

  attr_accessor :vtoc_track_no,:vtoc_sector_no  
	def dump_catalog
		s=""
	files.each { |file|		
			s<< "#{file.locked ? '*':' '}#{file.file_type} #{sprintf('%04d',file.contents.length)} #{file.filename}\n"
		}
		s
	end
	
	def file_system
		return :dos if (vtoc_track_no==0x11) && (vtoc_sector_no==0)
    :modified_dos
	end


	def initialize(file_bytes,sector_order,vtoc_track_no=0x11,vtoc_sector_no=0)
		super(file_bytes,sector_order)
    @vtoc_track_no=vtoc_track_no
    @vtoc_sector_no=vtoc_sector_no
		self.read_vtoc
	end
  
  #default file type is TextFile
  #Tokenisation not currently implemented
  def make_file(filename,contents,file_options={})
    raise "Tokenisation not currently supported for DOS files" if (file_options[:tokenise])
    file_type = case file_options[:filetype]
      when nil then 0x00
      when 'T' then 0x00
      when 'I' then 0x01
      when 'A' then 0x02
      when 'B' then 0x04
      else file_options[:filetype].tr("$","").hex
      end
      if file_type==4 && !(file_options[:base].nil?) then
        base=file_options[:base].tr("$","").hex
        s="\0\0\0\0"
        s[0]=base%256
        s[1]=base/256
        s[2]=contents.length%256
        s[3]=contents.length/256
        contents=s+contents
      end
    new_file=DOSFile.new(filename,contents,false,file_type)
  return new_file
end


	#reads the VTOC, and populate the "files" array with files
	def read_vtoc
    @files=FileContainer.new
		vtoc_sector=get_sector(vtoc_track_no,vtoc_sector_no)
		catalog_sector=get_sector(vtoc_sector[01],vtoc_sector[02])
		done=false
		visited_sectors={}
		while !done
			break if catalog_sector.nil?
			(0..6).each {|file_number|
				file_descriptive_entry_start=11+file_number*35
				file_descriptive_entry=catalog_sector[file_descriptive_entry_start,36]					
				break if (file_descriptive_entry[0]==0xFF) # skip deleted files
				filename=""
				file_descriptive_entry[3..32].to_s.each_byte{|b| filename+=(b.%128).chr}
				filename.gsub!(/ *$/,"") #strip off trailing spaces
				filename.tr!("\x00-\x1f","\x40-\x5f") #convert non-printable chars to corresponding uppercase letter
				locked=(file_descriptive_entry[2]>=0x80)
				sector_count=file_descriptive_entry[0x21]+file_descriptive_entry[0x22]*256
		
				file_type_code=file_descriptive_entry[2]%0x80
				
				
				if (sector_count>0) then
					contents=""
					ts_list_track_no=file_descriptive_entry[0]
					ts_list_sector_no=file_descriptive_entry[1]
					while (ts_list_track_no>0) && (ts_list_track_no<=0X22) && (ts_list_sector_no<=0x0f)
						ts_list_sector=get_sector(ts_list_track_no,ts_list_sector_no)
						ts_list_track_no=ts_list_sector[1]
						ts_list_sector_no=ts_list_sector[2]

						0x0C.step(0xff,2) {|i|						
							data_track_no=ts_list_sector[i]
							data_sector_no=ts_list_sector[i+1]
							if (data_track_no>0) && (data_track_no<=0X22) && (data_sector_no<=0x0f) then
								contents+=get_sector(data_track_no,data_sector_no)
							end
						}
					end
					if contents.length>0 then
						@files<< case file_type_code
							when 0x00 then TextFile.new(filename,contents,locked)
							when 0x01 then SCAsmFile.can_be_scasm_file?(contents)? SCAsmFile.new(filename,contents,locked): IntegerBasicFile.new(filename,contents,locked)
							when 0x02 then AppleSoftFile.new(filename,contents,locked)
							when 0x04 then MusiCompFile.can_be_musicomp_file?(filename,contents)? MusiCompFile.new(filename,contents,locked): BinaryFile.new(filename,contents,locked)
	#						when 0x08 then "S"	#S type file
	#						when 0x10 then "R"	#RELOCATABLE object module file
	#						when 0x20 then "a"	#??
	#						when 0x40 then "b"	#??
							else DOSFile.new(filename,contents,locked,file_type_code)
						end
					end
				end
			}
			next_track=catalog_sector[1]		
			next_sector=catalog_sector[2]%0x10
			if (next_track==0) &&( next_sector==0) then
				done=true
			else 
				#check we haven't got into an endless loop
				s="#{next_track}/#{next_sector}"
				if (!visited_sectors[s].nil?) then
					done=true
				end
				visited_sectors[s]=true
				catalog_sector=get_sector(next_track,next_sector)
			end
		end

	end
#iterate through the CATALOG to find either the named file or (if nil is passed in) an empty slot
def find_catalog_slot(filename)
  vtoc_sector=get_sector(vtoc_track_no,vtoc_sector_no)
  catalog_filename=DOSFile.catalog_filename(filename.upcase) unless filename.nil?
  catalog_track_no=vtoc_sector[01]
  catalog_sector_no=vtoc_sector[02]
  
  while (catalog_track_no+catalog_sector_no>0) do
    catalog=get_sector(catalog_track_no,catalog_sector_no)    
    (0..7).each do |slot_no|
      slot_start=slot_no*0x23+0x0B
      if filename.nil? && (catalog[slot_start]==0x00)|| (catalog[slot_start]==0xFF) then        
        return DSKTrackSector.new(catalog_track_no,catalog_sector_no,slot_start)
      end
      if (!filename.nil?) && (catalog[slot_start+0x03..slot_start+0x20]==catalog_filename) then
        return DSKTrackSector.new(catalog_track_no,catalog_sector_no,slot_start)
      end
    end
    catalog_track_no=catalog[01]
    catalog_sector_no=catalog[02]    
  end
  nil
end


#iterate through the sector usage bitmap, return a list of [track,sector] for sectors marked available
def free_sector_list
  end_of_sector_usage_bitmap=(track_count*4+0x38)-1
  sector_usage_bitmap=get_sector(vtoc_track_no,vtoc_sector_no)[0x38..end_of_sector_usage_bitmap]
  free_sectors=[]
  #skip track 0 - even if sectors there are unused, we can't include them in a catalog or track/sector list
    (1..track_count-1).each do |track|
      track_bitmap_lo=sector_usage_bitmap[track*4+1]
      track_bitmap_hi=sector_usage_bitmap[track*4]
      (0..7).each do |sector|
        if ((track_bitmap_lo & (2**(sector)))!=0) then
          free_sectors<<DSKTrackSector.new(track,sector)
        end
        if ((track_bitmap_hi & (2**(sector)))!=0) then
          free_sectors<<DSKTrackSector.new(track,sector+8)
        end        
      end
    end
    free_sectors.sort
end

  
  #given a track and sector, treat it as a track/sector list and return an array containing track/sector pairs
  def get_track_sector_list(ts_list_track_no,ts_list_sector_no)
    ts_list_sector=get_sector(ts_list_track_no,ts_list_sector_no)
    ts_list=[]
    for entry_number in 0..121
      data_track_no=ts_list_sector[entry_number*2+0x0C]
      data_sector_no=ts_list_sector[entry_number*2+0x0D]
      if( (data_track_no!=0 || data_sector_no!=0)  && data_track_no<track_count && data_sector_no<=0x0f) then
        ts_list<<DSKTrackSector.new(data_track_no,data_sector_no)
      end
    end
    ts_list
  end

  def delete_file(filename)
    this_files_catalog_slot=find_catalog_slot(filename)    
    #if file not in catalog, do nothing
    return if this_files_catalog_slot.nil? 
    file_descriptive_entry=get_sector(this_files_catalog_slot.track_no,this_files_catalog_slot.sector_no)[this_files_catalog_slot.offset..this_files_catalog_slot.offset+0x22]
    
    #mark sector as free in sector usage list
    sector_usage_bitmap_sector=get_sector(vtoc_track_no,vtoc_sector_no)
    sectors_to_mark_available=get_track_sector_list(file_descriptive_entry[0x00],file_descriptive_entry[0x01])
    sectors_to_mark_available<<DSKTrackSector.new(file_descriptive_entry[0x01],file_descriptive_entry[0x00])      
    
    sectors_to_mark_available.each do |ts|
      offset_of_byte_containing_this_sector=0x38+(ts.track_no*4)
      if ts.sector_no<8 then 
        offset_of_byte_containing_this_sector+=1
      end
      byte_containing_this_sector=sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]   
      byte_containing_this_sector=byte_containing_this_sector|(2**(ts.sector_no%8))
      sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]=byte_containing_this_sector
    end
    set_sector(vtoc_track_no,vtoc_sector_no,sector_usage_bitmap_sector)
    
    #mark slot as available in catalog
    catalog_sector=get_sector(this_files_catalog_slot.track_no,this_files_catalog_slot.sector_no)
    catalog_sector[this_files_catalog_slot.offset+0x20]=catalog_sector[this_files_catalog_slot.offset] #save the current "first track no" in last byte of filename
    catalog_sector[this_files_catalog_slot.offset]=0xFF
    set_sector(this_files_catalog_slot.track_no,this_files_catalog_slot.sector_no,catalog_sector)
  end


  def set_sector(track,sector,contents)
  super(track,sector,contents)  
  
  #now mark sector as used in sector usage list  
  if ((track!=vtoc_track_no) || (sector!=vtoc_sector_no)) then #don't bother marking the VTOC sectors used
    sector_usage_bitmap_sector=get_sector(vtoc_track_no,vtoc_sector_no)  
    offset_of_byte_containing_this_sector=0x38+(track*4)
    if sector<8 then 
        offset_of_byte_containing_this_sector+=1
    end
    byte_containing_this_sector=sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]
    byte_containing_this_sector=byte_containing_this_sector&(0xff-(2**(sector%8)))
    sector_usage_bitmap_sector[offset_of_byte_containing_this_sector]=byte_containing_this_sector
    set_sector(vtoc_track_no,vtoc_sector_no,sector_usage_bitmap_sector)
  end
end


def add_file(file)
    raise "only DOSFiles may be added to DOS format disks!" unless file.kind_of?(DOSFile)
    
    #if this file exists, delete it first
    delete_file(file.filename) unless files[file.filename].nil?
    catalog_slot=find_catalog_slot(nil)
    raise "CATALOG IS FULL!" if catalog_slot.nil?
    free_sectors=free_sector_list
    sectors_needed=1+file.length_in_sectors
    raise "not enough free space - #{sectors_needed} sectors needed, #{free_sector_list.length} available " unless sectors_needed<=free_sectors.length

  #TODO - allow files of more than 122 sectors
  raise "only files up to 122 sectors currently supported " if sectors_needed>122

#TRACK/SECTOR LIST FORMAT (from Beneath Apple DOS p 4-6)
  # 00	Not used
  # 01	Track number of next T/S list of one is needed or zero if no more t/s list
  # 02 	Sector number of next T/S list (if one is present)
  # 03-04	Not used
  # 05-06	Sector offset in file of the first sector described by this list
  # 07-oB	Not used
  # 0C-0D	Track and sector of first data sector or zeros
  # 0E-0F	Track and sector of second data sector or zeros
  # 10-FF	Up to 120 more track and sector pairs
  track_sector_list="\0"*256
  track_sector_list_sector=free_sectors[0]
  
  (0..sectors_needed-2).each do |sector_in_file|
    sector_to_use=free_sectors[sector_in_file+1]
    track_sector_list[(sector_in_file*2)+0x0C]=sector_to_use.track_no
    track_sector_list[(sector_in_file*2)+0X0D]=sector_to_use.sector_no
    sector_contents=file.contents[(sector_in_file*256),256] || ""
    set_sector(sector_to_use.track_no,sector_to_use.sector_no,sector_contents)
  end
  #write the track/sector list
  set_sector(track_sector_list_sector.track_no,track_sector_list_sector.sector_no,track_sector_list)

  #update the catalog file descriptive entry
  #FILE DESCRIPTIVE ENTRY (from Beneath Apple DOS p 4-6)
  # 00    Track of first track/sector list sector, if this is a deleted file this contains FF
  #	and the original track number is copied to the last byte of the file name (BYTE 20)
  #	If this byte contains a 00, the entry is assumed to never have been used and is
  #	available for use. (This means track 0 can never be used for data even if the DOS image
  #	is 'wiped' from the disk)
  #
  # 01    Sector of first track/sector list sector
  # 02    File type and flags:
  #	80+file type - file is locked
  #	00+file type - file is not locked
  #
  #	00 - TEXT file
  #	01 - INTEGER BASIC file
  #	02 - APPLESOFT BASIC file
  #	04 - BINARY file
  #	08 - S type file
  #	10 - RELOCATABLE object module file
  #	20 - a type file
  #	40 - b type file
  #
  # 03-20 File Name (30 characters)
  # 21-22 Length of file in sectors (LO/HI format)

  catalog_sector=get_sector(catalog_slot.track_no,catalog_slot.sector_no)
  file_descriptive_entry="\0"*0x23
  file_descriptive_entry[0]=track_sector_list_sector.track_no
  file_descriptive_entry[1]=track_sector_list_sector.sector_no
  file_descriptive_entry[2]=file.file_type_byte
  file_descriptive_entry[3..0x20]=file.catalog_filename
  file_descriptive_entry[0x21]=(sectors_needed-1)%256
  file_descriptive_entry[0x22]=(sectors_needed-1)/256

  catalog_sector[catalog_slot.offset..catalog_slot.offset+0x22]=file_descriptive_entry
  
  set_sector(catalog_slot.track_no,catalog_slot.sector_no,catalog_sector)
  
  raise "catalog not updated correctly!" if find_catalog_slot(file.filename).nil?
  #reread the catalog to populate the files list
  read_vtoc

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
