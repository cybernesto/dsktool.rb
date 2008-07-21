$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'open-uri'

#
# generic File System Image, as used by vintage computer emulators.
#
class FSImage

	DSK_IMAGE_EXTENSIONS=[".dsk",".po",".do",".hdv",".nib"]
  CBM_IMAGE_EXTENSIONS=[".d64"]
	
	attr_accessor :file_bytes,:track_count,:source_filename

  def target_system
      :unknown
  end
    
	def file_system
		:unknown
	end

  #what track does counting end at?
  def end_track
    track_count-1+start_track
  end

  
#add_file takes a *File object (of a type compatible with the underlying file system) and adds it to the in-memory image of this DSK
#this should be overridden in each  *Disk type that has write support enabled
  def add_file(new_file)
    raise "add files to #{file_system} file system not yet supported"
  end

#make_file creates a *File object (of a type compatible with the underlying file system) from filename, contents and options required
#for the underlying file system. The file is NOT added to the in-memory image of this DSK (call add_file to do that)
  def make_file(filename,contents,file_options={})
    raise "creating files for #{file_system} file system not yet supported"
  end

  def delete_file(filename)
    raise "deleting from #{file_system} file system not yet supported"
  end
  
  def free_sector_list
    raise "listing free sectors on #{file_system} file system not yet supported"
  end
	  
  #write out DSK to file
  def save_as(filename)
    if !(filename=~/\.gz$/).nil? then
			require 'zlib'
      f=Zlib::GzipWriter.new(open(filename,"wb"))
    else
      f=open(filename,"wb")
    end    
    f<<@file_bytes
    f.close
  end
			

  #create a new DSK initialised with specified filesystem
  def FSImage.create_new(filesystem)
     
    filesystem=:dos33 if filesystem==:dos 
    
    case filesystem 
      when :none
        return DSK.new()
     when :cpm
        require 'CPMDisk'
        return CPMDisk.new("\xe5"*DSK_FILE_LENGTH,:physical)
      when :nadol
        return DSK.read(File.dirname(__FILE__)+"/nadol_blank.po.gz")
      when :dos33 
        return DSK.read(File.dirname(__FILE__)+"/dos33_blank.dsk.gz")
    else 
        raise "initialisation of #{filesystem} file system not currently supported"
    end
  end

  def FSImage.read(filename)
    require 'DSK'
    require 'CBMImage'
    return DSK.read(filename) if DSK.is_dsk_file?(filename)
    return CBMImage.read(filename) if CBMImage.is_cbm_file?(filename)
    raise "#{filename} is not a recognised file system image}"    
	end
	
  def FSImage.is_fsimage_file?(filename)
    require 'DSK'
    require 'CBMImage'
    DSK.is_dsk_file?(filename) || CBMImage.is_cbm_file?(filename)
	end
	
	def files
		@files
	end

  #return a formatted hex dump of a single 256 byte sector
	def dump_sector(track,sector)
    require 'DumpUtilities'
		s=hline
		s<<sprintf("TRACK: $%02X SECTOR $%02X\n",track,sector)
		sector_data=get_sector(track,sector)
		s<< DumpUtilities.hex_dump(sector_data)
		s
	end

#return a formatted hex dump of all sectors in a track
  def dump_track(track)
    s=""
      0.upto(sectors_in_track[track]-1) do |sector|
				s<<dump_sector(track,sector)
			end
    s
	end

def hex_dump
		s=""
		1.upto(track_count) {|track| s<<dump_track(track)}
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
