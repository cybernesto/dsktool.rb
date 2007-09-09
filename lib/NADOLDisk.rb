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

#TRACK/SECTOR LIST FORMAT 
# pairs of track/sectors in order. up to 128 entries [assumes that no file can be > 128 sectors]

require 'NADOLFile'

class NADOLDisk < DSK

	def dump_catalog
		files.each_value { |file|		
			puts "#{sprintf('% 6d',file.contents.length)} #{file.filename}"
		}
	end

	def initialize(file_bytes,sector_order)
		super(file_bytes,sector_order)
		self.read_catalog
	end

	def file_system
		:nadol
	end
	
	#reads the catalog, and populate the "files" array with files
	#CATALOG will be at track $00, sector $03 to track $00, sector $09
	#each entry consists of $10 bytes, which are:
	# 00-0B - filename - if file is deleted, first byte will be FF
	# 0C-0D - filesize (low byte first)
	# 0E - track of track sector list sector
	# 0F - sector of track sector list sector
	def read_catalog
		0x300.step(0x9FF,0x10) do |file_descriptive_entry_start|
			file_descriptive_entry=@file_bytes[file_descriptive_entry_start..file_descriptive_entry_start+0x0F]
			break if (file_descriptive_entry[0]==0xFF) # skip deleted files
			filename=""
			file_descriptive_entry[0..11].to_s.each_byte{|b| filename+=(b.%128).chr} #strip off high bit
			filename.sub!(/ *$/,"") #strip off trailing spaces
			full_sectors=file_descriptive_entry[0x0D]
			bytes_in_last_sector=file_descriptive_entry[0x0C]
			file_size=full_sectors*256+bytes_in_last_sector
			if (file_size>0) then
				contents=""					
				ts_list_track_no=file_descriptive_entry[0x0E]
				ts_list_sector_no=file_descriptive_entry[0x0F]
				ts_list=get_sector(ts_list_track_no,ts_list_sector_no)
				entry_number=0
				while entry_number<full_sectors do						
					data_track_no=ts_list[entry_number*2]
					data_sector_no=ts_list[entry_number*2+1]
					contents+=get_sector(data_track_no,data_sector_no)
					entry_number+=1
				end
				if (bytes_in_last_sector>0) then
					data_track_no=ts_list[entry_number*2]
					data_sector_no=ts_list[entry_number*2+1]
					contents+=get_sector(data_track_no,data_sector_no)[0..bytes_in_last_sector-1]
				end	
				if (NADOLTokenisedFile.can_be_nadol_tokenised_file?(contents)) then
					@files[filename]= NADOLTokenisedFile.new(filename,contents)
				else
					@files[filename]= NADOLBinaryFile.new(filename,contents)
				end
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
