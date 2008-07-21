$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

#Image used in CBM emulators

require 'FSImage'
class CBMImage <FSImage
  
 #does this filename have a suitable extension?
	def CBMImage.is_cbm_file?(filename)
		extension=File.extname(File.basename(filename,".gz")).downcase
		FSImage::CBM_IMAGE_EXTENSIONS.include?(extension)
	end
   
  #convert PETSCII to ASCII
  #algorithm taken from VICE http://www.viceteam.org/

  def CBMImage.p2a(i)
    s=""
    i.each_byte do |b|
      if (b==0xa) || (b==0x0d)
        s+="\n"
      elsif (b==0x40) || (b==0x60)
        s+=b.chr
      elsif (b==0xA0) || (b==0xE0) #shifted space
        s+=" "
      else 
        case (b & 0XE0)
          when 0x40,0x60 then s+=(b^0x20).chr
          when 0xc0 then s+=(b^0x80).chr
          else
            #s+=((b>0x20) ? b.chr:".")
            s+=b.chr
        end
      end
    end
  s
  
  end
    
  #for the moment, only D64 files are supported
	def CBMImage.read(filename)
    require 'D64'
    D64.read(filename)
  end
  
  #CBM images start with track 1   
  def start_track
    1
  end
  
  def target_system
      :cbm
  end

  #return a formatted hex dump of a single 256 byte sector
	def disassemble_sector(track,sector)
		require 'D65'
		sector_data=get_sector(track,sector)
    return D65.disassemble(sector_data)
	end

end



# == Author
# Jonno Downes (jonno@jamtronix.com)
#
# == Copyright
# Copyright (c) 200873490- Jonno Downes (jonno@jamtronix.com)
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
