$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'open-uri'

require 'FSImage'
require 'FileContainer'
#
# For manipulating DSK files, as created by ADT (http://adt.berlios.de) and ADTPRo (http://adtpro.sourceforge.net)
# used by many Apple 2 emulators.
#
class DSK < FSImage

	FILE_SYSTEMS=[:prodos,:dos33,:nadol,:cpm,:pascal,:modified_dos,:unknown,:none]
	SECTOR_ORDERS=[:physical,:dos]	
	INTERLEAVES={
		:physical=>   [0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F],
		:dos=>[0x00,0x0E,0x0D,0x0C,0x0B,0x0A,0x09,0x08,0x07,0x06,0x05,0x04,0x03,0x02,0x01,0x0F],
	}
  
	#does this filename have a suitable extension?
	def DSK.is_dsk_file?(filename)
		extension=File.extname(File.basename(filename,".gz")).downcase
		FSImage::DSK_IMAGE_EXTENSIONS.include?(extension)
	end
	DSK_FILE_LENGTH=143360
  NIB_FILE_LENGTH=232960
	attr_accessor :sector_order,:source_filename

  def sectors_in_track
    [16]*track_count
  end
    
  #what track does counting start from? usually 0 (Apple 2) or 1 (CBM)?
  def start_track
    0
  end
  
	def file_system
		:unknown
	end

  def target_system
      :apple_2
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

  def is_modified_dos?(vtoc_track_no,vtoc_sector_no)
    vtoc_sector=get_sector(vtoc_track_no,vtoc_sector_no)
		(vtoc_sector[01]<=34) && (vtoc_sector[02]<=15) && (vtoc_sector[0x27]==0x7A) && (vtoc_sector[0x35]==0x10)
  end
  
	def	is_nadol?(sector_order)
		#currently ignores sector order
		# track $00, sector $02 , bytes $11 - "NADOL"
		(@file_bytes[0x00211..0x00215]=="NADOL")
	end

  def is_cpm?(sector_order) 
    #currently ignores sector order
    #look for a valid looking CPM directory on track 3.
    #go through each sector in order, for each sector, look at every 32nd byte, and see if it is a valid 'user number' (i.e. a number from 00..0F). Stop looking when you see an 'E5'.
    #if an invalid user number is found before an E5, then the disk is NOT a CPM disk
    found_0xE5_byte=false
    [0x0,0x6,0xC,0x3,0x9,0xF,0xE,0x5].each do |sector_no|
      sector=get_sector(3,INTERLEAVES[sector_order][sector_no])
      [0x00,0x20,0x40,0x60,0x80,0xA0,0xC0,0xE0].each do |byte_number|
        if (sector[byte_number]>0x0F && sector[byte_number]!=0xe5 && sector[byte_number]!=0x1F) then
    #      puts "found #{sprintf '%02x',sector[byte_number]} at #{sprintf '%02x', byte_number} sector #{sprintf '%02x', sector_no}"
          return false 
        end
        if (sector[byte_number]==0xe5) then
          found_0xE5_byte=true
        end
      end
    end
    return found_0xE5_byte #if we've only seen 00 bytes, then it's not really a CPM 
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
		@files=FileContainer.new
		@sector_order=sector_order
		@track_count=file_bytes.length/4096
    @source_filename="(unknown)"
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
		
    if (file_bytes.length-NIB_FILE_LENGTH).abs<=1 then
      require 'Nibbles'
      dsk=Nibbles.make_dsk_from_nibbles(file_bytes)
    else
      dsk=DSK.new(file_bytes)
    end
    dsk.source_filename=filename		
		dsk.best_subclass
	end

  #for a generic DSK,return an instance of subclass representing the the best match file system
  def best_subclass
    SECTOR_ORDERS.each do |sector_order|
			begin
				candidate_filesystem="unknown"
				if (self.is_dos33?(sector_order)) 
					require 'DOSDisk'
					candidate_filesystem="DOS 3.3"
					return DOSDisk.new(self.file_bytes,sector_order)
				end
				
				if (self.is_nadol?(sector_order)) 
					require 'NADOLDisk'
					candidate_filesystem="NADOL"
					return NADOLDisk.new(self.file_bytes,sector_order)
				end
				
				if (self.is_prodos?(sector_order))
					require 'ProDOSDisk'
					candidate_filesystem="ProDOS"
					return ProDOSDisk.new(self.file_bytes,sector_order)
				end
	      
				if (self.is_pascal?(sector_order))
					require 'PascalDisk'
					candidate_filesystem="Pascal"
					return PascalDisk.new(self.file_bytes,sector_order)
				end
        
        if (self.is_cpm?(sector_order))
					require 'CPMDisk'
					candidate_filesystem="CP/M"
					return CPMDisk.new(self.file_bytes,sector_order)
				end
			rescue Exception=>e
				STDERR<<"error while parsing #{self.source_filename} as #{candidate_filesystem} (sector order #{sector_order}\n"
				STDERR<<"#{e}\n"
				STDERR<<e.backtrace.join("\n")
			end      
		end
    
    #if none of the above matched, look for a DOS image with a VTOC in the wrong spot
    0.upto(0x22) do |track|
      if (self.is_modified_dos?(track,0)) 
					require 'DOSDisk'
					candidate_filesystem="MODIFIED DOS"
					return DOSDisk.new(self.file_bytes,:physical,track,0)
				end
    end
    #if we didn't find a better match, return self
    self
  end
	
	def get_sector(track,requested_sector,sector_order=@sector_order)
		raise "bad sector #{requested_sector}" unless requested_sector.between?(0,0x0F)
		raise "bad sector_order #{sector_order}" if INTERLEAVES[sector_order].nil?
		physical_sector=INTERLEAVES[sector_order][requested_sector]
		start_byte=track*16*256+physical_sector*256
		@file_bytes[start_byte,256]
	end

 def set_sector(track,sector,contents)
    physical_sector=INTERLEAVES[@sector_order][sector]
    start_byte=track*16*256+physical_sector*256
    (0..255).each do |byte|
      c=(contents[byte] || 0)
      @file_bytes[start_byte+byte]=c  
    end  
end

  #write supplied code to track 0 (from sector 0 to whatever is required)
  #code should run from $0801 and can be up to 4KB (16 sectors) in length
  def set_boot_track(contents)
    sectors_needed=(contents.length / 256)+1
    raise "boot code can't exceed 16 sectors" if sectors_needed>16
    s=sectors_needed.chr+contents
    for sector in 0..sectors_needed-1
      sector_data=s[sector*256,256]
      set_sector(0,sector,sector_data)
    end
  end
  
	def get_block(block_no)
		track=(block_no / 8).to_i
		first_sector=2*(block_no % 8)
		raise "illegal block no #{block_no}" if track>=self.track_count
		return self.get_sector(track,first_sector)+self.get_sector(track,first_sector+1)
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
	
end


class DSKTrackSector
  attr_accessor :track_no,:sector_no,:offset
  def initialize(track_no,sector_no,offset=0x00)
    @track_no=track_no
    @sector_no=sector_no
    @offset=offset
  end
  def to_s 
    sprintf "TRACK $%02X SECTOR $%02X OFFSET $02X",track_no,sector_no,offset
  end
  
  def <=>(other)
    return -1 unless other.kind_of?DSKTrackSector
    return track_no<=>other.track_no unless track_no==other.track_no
    return sector_no<=>other.sector_no unless sector_no==other.sector_no
    return offset<=>other.offset
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
