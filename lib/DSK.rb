$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'open-uri'

#
# For manipulating DSK files, as created by ADT (http://adt.berlios.de) and ADTPRo (http://adtpro.sourceforge.net)
# used by many Apple 2 emulators.
#
class DSK

	#does this filename have a suitable extension?
	def DSK.is_dsk_file?(filename)
		!(filename.upcase=~/\.DSK$|\.DSK\.GZ$|\.PO$|\.PO\.GZ$/).nil?
	end
	DSK_FILE_LENGTH=143360
	attr_accessor (:file_bytes)
	# does this DSK have a standard Apple DOS 3.3 VTOC?
	def	is_dos33?
		# VTOC is at offset 0x11000
		# bytes 1/2/3 are a track number, sector number and DOS version number
		# see if these are reasonable values

		(@file_bytes[0x11001]<=34) && (@file_bytes[0x11002]<=15) && (@file_bytes[0x11003]==3)
	end

	def	is_nadol?
		# track $00, sector $02 , bytes $11 - "NADOL"
		(@file_bytes[0x00211..0x00215]=="NADOL")
	end


	#create a new DSK structure (in memory, not on disk)
	def initialize(file_bytes="\0"*DSK_FILE_LENGTH)	
		if (file_bytes.length!=DSK_FILE_LENGTH) then
			raise "DSK files must be #{DSK_FILE_LENGTH} bytes long (was #{file_bytes.length} bytes)"
		end
		@file_bytes=file_bytes
		@files={}
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
		if (file_bytes.length!=DSK_FILE_LENGTH) then
			abort("#{filename} is not a valid DSK format file")
		end
		
		dsk=DSK.new(file_bytes)		
		if (dsk.is_dos33?) 
			require 'DOSDisk'
			dsk=DOSDisk.new(file_bytes)
		end
		
		if (dsk.is_nadol?) 
			require 'NADOLDisk'
			dsk=NADOLDisk.new(file_bytes)
		end

		dsk
	end

	def get_sector(track,sector)
		start_byte=track*16*256+sector*256
		@file_bytes[start_byte..start_byte+255]
	end

	def files
		@files
	end

	#return a formatted hex dump of a single 256 byte sector
	def dump_sector(track,sector)
		start_byte=track.to_i*16*256+sector.to_i*256
		s=hline
		s<<sprintf("TRACK: $%02X SECTOR $%02X\ OFFSET $%04X\n",track,sector,start_byte)
		s<< "\t"
		sector_data=get_sector(track,sector)
		(0..15).each {|x| s<<sprintf("%02X ",x) }
		s<<"\n"
		s<<hline
		(0..15).each {|line_number|
			 lhs=""
			 rhs=""
			 start_byte=line_number*16
			 line=sector_data[start_byte..start_byte+15]
			 line.each_byte {|byte|
				  lhs<< sprintf("%02X ", byte)
				  rhs<< (byte%128).chr.sub(/[\x00-\x1f]/,'.')
		 	}
			s<<sprintf("%02X\t%s %s\n",start_byte,lhs,rhs)
		}
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
	def dump_disk
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
