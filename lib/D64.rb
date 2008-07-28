$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'open-uri'

require 'CBMImage'
require 'CBMFile'
require 'FileContainer'
#
# For manipulating D64 files, as used by many C64 emulators.
#
# References: 
#     http://www.unusedino.de/ec64/technical/formats/d64.html
#     http://www.baltissen.org/newhtm/1541c.htm
#     http://www.scribd.com/doc/40438/The-Commodore-1541-Disk-Drive-Users-Guide
#
# Block Allocation Map (Track 18, Sector 0)
# BYTES     CONTENTS
# 00..01      Track and Sector of first Directory Block (should be 18,1)
# 02           drive fromat - ASCII Charactor A means '4040' format
# 03           0 (null flag for future DOS use)
# 04..8F      bit map of available blocks for tracks 1..35
# 90..A1      disk name padded with shifted spaces
# A2..A3     disk ID
# A4          unused
# A5          DOS Version
# A6          DOS Format Type
# A7..FF     unused
class D64 <CBMImage

 attr_accessor :file_bytes,:track_count,:source_filename,:disk_name,:disk_id,:drive_format,:dos_version,:format_type,:files
  D64_IMAGE_EXTENSIONS=[".d64"]
  D64_FILE_LENGTH=174848
  BYTES_PER_SECTOR=256
  DIRECTORY_ENTRY_SIZE=0x20
  FILE_TYPES=["DEL","SEQ","PRG","USR","REL","??5","??6","??7"]
  @@sectors_in_track=[]
  @@offset_of_track=[]
  1.upto(17) {|t| @@sectors_in_track[t]=21}
  18.upto(24) {|t| @@sectors_in_track[t]=19}
  25.upto(30) {|t| @@sectors_in_track[t]=18}
  31.upto(40) {|t| @@sectors_in_track[t]=17}
  @@offset_of_track[1]=0
  1.upto(39) {|t| @@offset_of_track[t+1]=@@offset_of_track[t]+(@@sectors_in_track[t]*BYTES_PER_SECTOR)}
  def sectors_in_track
    @@sectors_in_track
  end
  
  def D64.offset_of_track
    @@offset_of_track
  end
  
  def file_system
    :cbm_dos
  end
  
  def initialize(file_bytes="\0"*D64_FILE_LENGTH)
    1.upto(@@offset_of_track.length-1) do |t|
       @track_count=t if file_bytes.length>@@offset_of_track[t]
    end
    @file_bytes=file_bytes
    bam_sector=get_sector(18,0)
    @drive_format=bam_sector[0x02].chr
    @disk_name=bam_sector[0x90..0xA1]
    @disk_id=bam_sector[0xA2..0xA3]
    @dos_version=bam_sector[0xA5].chr
    @format_type=bam_sector[0xA6].chr
    @files=FileContainer.new
    read_directory
  end
  
    
  def disk_info
    "NAME:\t\t#{CBMImage.p2a(disk_name)}\nID:\t\t#{CBMImage.p2a(@disk_id)}\nDRIVE FORMAT:\t#{@drive_format}\nTRACK COUNT:\t#{track_count}\nDOS VERSION:\t#{dos_version}\nFORMAT TYPE:\t#{format_type}\nFILES:\n"
  end
   
  def dump_catalog
    s=""
    files.each do |file|
      s<<file.directory_entry
      s<<"\n"
    end
    s
  end
#directory sectors are laid out as:
#OFFSET   CONTENTS
#00..01       Track/sector of next directory sector (first entry only)
#02            File Type
#03..04       Track/Sector of first sector of file
#05..14       16 character filename
#15..16       Track/Sector location of first side-sector block (REL file only)
#17            REL file record length (REL file only, max. value 254)
#18-1D       Unused (except with GEOS disks)
#1E-1F        File size in sectors, low/high byte  order  ($1E+$1F*256).                 
  def read_directory
      dir_track_no=18
      dir_sector_no=1      
      until dir_track_no==0 || dir_track_no> end_track do 
        directory_sector=get_sector(dir_track_no,dir_sector_no)        
        dir_track_no=directory_sector[0]
        dir_sector_no=directory_sector[1]
        0.upto(7) do |entry_number|            
            directory_entry=directory_sector[DIRECTORY_ENTRY_SIZE*entry_number,DIRECTORY_ENTRY_SIZE]
            file_name=CBMImage.p2a(directory_entry[0x05..0x14]).strip
            file_type=FILE_TYPES[directory_entry[0x02]%8]
            file_track_no=directory_entry[0x03]
            file_sector_no=directory_entry[0x04]
            file_contents=""
            until file_track_no==0 || file_track_no> end_track do
              file_sector=get_sector(file_track_no,file_sector_no)
              file_track_no=file_sector[0]
              file_sector_no=file_sector[1]
              file_contents+=file_sector[2..255]
            end
            
            files<<CBMFile.new(file_name,file_contents,file_type)
        end
      end
  end
	
			
  #read in an existing D64 file (must exist)
	def D64.read(filename)
		#is the file extension .gz?
		if !(filename=~/\.gz$/).nil? then
			require 'zlib'
			file_bytes=Zlib::GzipReader.new(open(filename,"rb")).read
		else
			file_bytes=open(filename,"rb").read
		end
    d64=D64.new(file_bytes)
    d64.source_filename=filename		
		d64
	end

	def get_sector(track_no,sector_no)
    raise "bad track #{track_no}" unless track_no.between?(1,track_count)
		raise "bad sector #{sector_no}" unless sector_no.between?(0,@@sectors_in_track[track_no]-1)
		start_byte=@@offset_of_track[track_no]+(BYTES_PER_SECTOR*(sector_no))    
		@file_bytes[start_byte,BYTES_PER_SECTOR]
	end
  
end




# == Author
# Jonno Downes (jonno@jamtronix.com)
#
# == Copyright
# Copyright (c) 2008 Jonno Downes (jonno@jamtronix.com)
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
