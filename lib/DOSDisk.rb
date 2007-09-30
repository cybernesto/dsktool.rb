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

	def dump_catalog
		s=""
	files.keys.sort.each { |file_name|		
			file=files[file_name]	
			s<< "#{file.locked ? '*':' '}#{file.file_type} #{sprintf('%03X',file.sector_count)} #{file.filename}\n"
		}
		s
	end
	
	def file_system
		:dos
	end


	def initialize(file_bytes,sector_order)
		super(file_bytes,sector_order)
		self.read_vtoc
	end
	#reads the VTOC, and populate the "files" array with files

	def read_vtoc
		vtoc_sector=get_sector(17,0)
		catalog_sector=get_sector(vtoc_sector[01],vtoc_sector[02])
		done=false
		while !done
			break if catalog_sector.nil?
			(0..6).each {|file_number|
				file_descriptive_entry_start=11+file_number*35
				file_descriptive_entry=catalog_sector[file_descriptive_entry_start..file_descriptive_entry_start+35]					
				break if (file_descriptive_entry[0]==0xFF) # skip deleted files
				filename=""
				file_descriptive_entry[3..32].to_s.each_byte{|b| filename+=(b.%128).chr}
				filename.sub!(/ *$/,"") #strip off trailing spaces
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
						@files[filename]= case file_type_code
							when 0x00 then TextFile.new(filename,locked,sector_count,contents)
							when 0x01 then SCAsmFile.can_be_scasm_file?(contents)? SCAsmFile.new(filename,locked,sector_count,contents): IntegerBasicFile.new(filename,locked,sector_count,contents)
							when 0x02 then AppleSoftFile.new(filename,locked,sector_count,contents)
							when 0x04 then BinaryFile.new(filename,locked,sector_count,contents)
	#						when 0x08 then "S"	#S type file
	#						when 0x10 then "R"	#RELOCATABLE object module file
	#						when 0x20 then "a"	#??
	#						when 0x40 then "b"	#??
							else DOSFile.new(filename,locked,sector_count,contents,sprintf("$%02X",file_type_code))
						end
					end
				end
			}
			next_track=catalog_sector[1]		
			next_sector=catalog_sector[2]%0x10
			if (next_track==0) &&( next_sector==0) then
				done=true
			else 
				catalog_sector=get_sector(next_track,next_sector)
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
