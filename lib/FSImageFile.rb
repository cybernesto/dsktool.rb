$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'open-uri'

require 'DumpUtilities'

#
# generic file on a File System Image, as used by vintage computer emulators.
#
class FSImageFile

	attr_accessor(:filename,:contents) 
	def initialize(filename,contents)
		@filename=filename
		@contents=contents
	end

	def to_s
		@contents
	end
  
  #some filesystems  differentiate between full and partial filenames.
  #e.g. in ProDOS the 'full' filename includes the full path
  #by default, full_filename is the same as filename, but can be overridden
  #for those filesystems that need this
  def full_filename
    @filename
  end
  def ==(other_object)
    if  !other_object.kind_of? DSKFile then
      return false
    end
     if self.filename!=other_object.filename then
       return false
     end
    
    return self.to_s==other_object.to_s
  end
  
	def file_extension
		".bin"
	end
  
	def hex_dump
    DumpUtilities.hex_dump(@contents)
	end

	#default is files can NOT be displayed as a picture
	def can_be_picture?
		false
	end

#default is files can NOT be rendered to a MIDI file
	def can_be_midi?    
		false
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
