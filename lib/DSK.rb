$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

#
# For manipulating DSK files, as created by ADT (http://adt.berlios.de) and ADTPRo (http://adtpro.sourceforge.net)
# used by many Apple 2 emulators.
#
class DSK

	DSK_FILE_LENGTH=143360
	attr_accessor (:file_bytes)
	# does this DSK have a standard Apple DOS 3.3 VTOC?
	def	is_dos33?
		# VTOC is at offset 0x11000
		# bytes 1/2/3 are a track number, sector number and DOS version number
		# see if these are reasonable values

		(@file_bytes[0x11001]<=34) && (@file_bytes[0x11002]<=15) && (@file_bytes[0x11003]==3)
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
		file_bytes=File.new(filename,"rb").read
		if (file_bytes.length!=DSK_FILE_LENGTH) then
			abort("#{filename} is not a valid DSK format file")
		end
		dsk=DSK.new(file_bytes)		
		if (dsk.is_dos33?) 
			require 'DOSDisk'
			dsk=DOSDisk.new(file_bytes)
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

	#print to stdout a formatted hex dump of a single 256 byte sector
	def dump_sector(track,sector)

		start_byte=track*16*256+sector*256
		s=@file_bytes[start_byte..start_byte+255]

		print_hline
		printf("TRACK: $%02X SECTOR $%02X\ OFFSET $%04X\n",track,sector,start_byte)
		printf "\t"

		(0..15).each {|x| printf("%02X ",x) }
		puts
		print_hline
		(0..15).each {|line_number|
			 lhs=""
			 rhs=""
			 start_byte=line_number*16
			 line=s[start_byte..start_byte+15]
			 line.each_byte {|byte|
				  lhs+= sprintf("%02X ", byte)
				  rhs+= (byte%128).chr.sub(/[\x00-\x1f]/,'.')
		 	}
			 printf("%02X\t%s %s\n",start_byte,lhs,rhs)
		}

	end

	#print to stdout a formatted hex dump of all sectors on all tracks
	def dump_disk
	
		(0..34).each {|track|
			(0..15).each {|sector|
				dump_sector(track,sector)
			}
		}
	end
	
private

	def print_hline
		puts "-"*79
	end


end