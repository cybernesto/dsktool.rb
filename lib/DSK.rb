$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'open-uri'

#
# For manipulating DSK files, as created by ADT (http://adt.berlios.de) and ADTPRo (http://adtpro.sourceforge.net)
# used by many Apple 2 emulators.
#
class DSK

	FILE_SYSTEMS=[:prodos,:dos33,:nadol,:pascal,:unknown]
	SECTOR_ORDERS=[:physical,:prodos_from_dos]
	DSK_IMAGE_EXTENSIONS=[".dsk",".po",".do",".hdv"]
	INTERLEAVES={
		:physical=>   [0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F],
		:prodos_from_dos=>[0x00,0x0E,0x0D,0x0C,0x0B,0x0A,0x09,0x08,0x07,0x06,0x05,0x04,0x03,0x02,0x01,0x0F]
	}
  
	#does this filename have a suitable extension?
	def DSK.is_dsk_file?(filename)
		extension=File.extname(File.basename(filename,".gz")).downcase
		DSK_IMAGE_EXTENSIONS.include?(extension)
	end
	DSK_FILE_LENGTH=143360
	attr_accessor :file_bytes,:sector_order,:track_count

	def file_system
		:unknown
	end
  
	# does this DSK have a standard Apple DOS 3.3 VTOC?
	def	is_dos33?(sector_order)
		#currently ignores sector order
		# VTOC is at offset 0x11000
		# bytes 1 & 2 are a track number, sector number and DOS version number
    # byte 27  is maximum number of track/sector pairs which will fit in one file track/sector list sector (122 for 256 byte sectors)
    # 35    number of sectors per track (16)
		# see if these are reasonable values
    vtoc_sector=get_sector(0x11,0)
		(vtoc_sector[01]<=34) && (vtoc_sector[02]<=15) && (vtoc_sector[0x27]==0x7A) && (vtoc_sector[0x35]==0x10)
	end

	def	is_nadol?(sector_order)
		#currently ignores sector order
		# track $00, sector $02 , bytes $11 - "NADOL"
		(@file_bytes[0x00211..0x00215]=="NADOL")
	end

	def	is_prodos?(sector_order)
		#block $02 - bytes $00/$01 are both $00, byte $04 is $F?, 
		#bytes $29-$2A = sectors ( 0x118 on a 35 track 5.25" disk)
		first_sector_in_block_2=INTERLEAVES[sector_order][4]
		first_sector_in_block_2=get_sector(0,4,sector_order)
		(first_sector_in_block_2[0..1]=="\x00\x00") && (first_sector_in_block_2[4]>=0xF0) && (first_sector_in_block_2[0x29]+first_sector_in_block_2[0x2a]*0x100==track_count*8)
	end

  def is_pascal?(sector_order)
	 #block $02 - bytes $00..$01 are both $00, byte $06 is < 8 and 
		#bytes $0E-$0F = sectors ( 0x118 on a 35 track 5.25" disk)
		first_sector_in_block_2=INTERLEAVES[sector_order][4]
		first_sector_in_block_2=get_sector(0,4,sector_order)
		(first_sector_in_block_2[0..1]=="\x00\x00") && (first_sector_in_block_2[6]<=7) && (first_sector_in_block_2[0x0E]+first_sector_in_block_2[0x0F]*0x100==track_count*8)
		end
  
	#create a new DSK structure (in memory, not on disk)
	def initialize(file_bytes="\0"*DSK_FILE_LENGTH,sector_order=:physical)
		#file must be a multiple of (16 sectors * 256 bytes) = 4096
		#some dsks on Asimov appear to have an extra byte at the end so allow for 1 extra byte
		if (file_bytes.length%4096>1) then
			raise "DSK files must be #{DSK_FILE_LENGTH} bytes long (was #{file_bytes.length} bytes)"
		end
		@file_bytes=file_bytes
		@files={}
		@sector_order=sector_order
		@track_count=file_bytes.length/4096
	end
	
	#read in an existing DSK file (must exist)
	def DSK.read(filename)
		#is the file extension .gz?
		if !(filename=~/\.gz$/).nil? then
			require 'zlib'
			file_bytes=Zlib::GzipReader.new(open(filename,"rb")).read
		else
			file_bytes=open(filename,"rb").read
		end
		

		dsk=DSK.new(file_bytes)		
		SECTOR_ORDERS.each do |sector_order|
			begin
				candidate_filesystem="unknown"
				if (dsk.is_dos33?(sector_order)) 
					require 'DOSDisk'
					candidate_filesystem="DOS 3.3"
					dsk=DOSDisk.new(file_bytes,sector_order)
					break
				end
				
				if (dsk.is_nadol?(sector_order)) 
					require 'NADOLDisk'
					candidate_filesystem="NADOL"
					dsk=NADOLDisk.new(file_bytes,sector_order)
					break
				end
				
				if (dsk.is_prodos?(sector_order))
					require 'ProDOSDisk'
					candidate_filesystem="ProDOS"
					dsk=ProDOSDisk.new(file_bytes,sector_order)
					break
				end
	      
				if (dsk.is_pascal?(sector_order))
					require 'PascalDisk'
					candidate_filesystem="Pascal"
					dsk=PascalDisk.new(file_bytes,sector_order)
					break
				end

			rescue Exception=>e
				STDERR<<"error while parsing #{filename} as #{candidate_filesystem} (sector order #{sector_order}\n"
				STDERR<<"#{e}\n"
				STDERR<<e.backtrace.join("\n")
			end
		end
		dsk
	end

	def get_sector(track,requested_sector,sector_order=@sector_order)
		raise "bad sector #{requested_sector}" unless requested_sector.between?(0,0x0F)
		raise "bad sector_order #{sector_order}" if INTERLEAVES[sector_order].nil?
		physical_sector=INTERLEAVES[sector_order][requested_sector]
		start_byte=track*16*256+physical_sector*256
		@file_bytes[start_byte..start_byte+255]
	end

	def get_block(block_no)
		track=(block_no / 8).to_i
		first_sector=2*(block_no % 8)
		raise "illegal block no #{block_no}" if track>=self.track_count
		return self.get_sector(track,first_sector)+self.get_sector(track,first_sector+1)
	end

	def files
		@files
	end

	#return a formatted hex dump of a single 256 byte sector
	def dump_sector(track,sector)
    require 'DumpUtilities'
		start_byte=track.to_i*16*256+sector.to_i*256
		s=hline
		s<<sprintf("TRACK: $%02X SECTOR $%02X\ OFFSET $%04X\n",track,sector,start_byte)
		s<< "\t"
		sector_data=get_sector(track,sector)
		s<< DumpUtilities.hex_dump(sector_data)
		s
	end

	#return a formatted hex dump of a single 256 byte sector
	def disassemble_sector(track,sector)
		require 'D65'
		sector_data=get_sector(track,sector)
		if (track==0) && (sector==0) then
			return D65.disassemble(sector_data[1..255],0x801)
		else
			return D65.disassemble(sector_data)
		end
	end

	#return a formatted hex dump of all sectors on all tracks
	def hex_dump
		s=""
		(0..34).each {|track|
			(0..15).each {|sector|
				s<<dump_sector(track,sector)
			}
		}
		s
	end
	
private

	def hline
		"-"*79+"\n"
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
