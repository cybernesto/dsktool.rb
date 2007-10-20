#Apple II Hi-Res Graphics routines
$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'rubygems'
require_gem 'png', '= 1.0.0'
require 'png'
#need to add a new method to PNG to get at the raw bytes as the png library only writes to disk
class PNG
	def raw_bytes
		bytes=""
		bytes<< [137, 80, 78, 71, 13, 10, 26, 10].pack("C*") # PNG signature
		bytes<< PNG.chunk('IHDR',
			[ @height, @width, @bits, 6, 0, 0, 0 ].pack("N2C5"))
		# 0 == filter type code "none"
		data = @data.map { |row| [0] + row.map { |p| p.values } }.flatten
		bytes<< PNG.chunk('IDAT', Zlib::Deflate.deflate(data.pack("C*"), 9))
		bytes<< PNG.chunk('IEND', '')
		bytes
	end
end

class HGR

PALLETE_MODES=[:white,:green,:amber,:colour]
PALLETE={
	:white=>PNG::Color::White,
	:green=>PNG::Color.new(0x00, 0x99, 0x00, 0xFF),
	:amber=>PNG::Color::Orange
}

#colours cribbed from http://groups.google.com.au/group/comp.sys.apple2/browse_thread/thread/b9aa36ead6935c42/faa0f4df3e89060f
HGR_BLACK=PNG::Color::Black			#color=0,4
HGR_GREEN=PNG::Color.new(0x2F,0xB8,0x1F,0xFF)	#color=1
HGR_VIOLET=PNG::Color.new(0xC8,0x47,0xE4,0xFF)	#color=2
HGR_WHITE=PNG::Color::White			#color=3,7
HGR_ORANGE=PNG::Color.new(0xC7,0x70,0x28,0xFF)	#color=5
HGR_BLUE=PNG::Color.new(0x30,0x8F,0xE3,0xFF)	#color=6

HGR_COLS=40*7
HGR_ROWS=8*8*3
SCALE=2

#per Apple // Reference Manual for //e chapter 2, pages 22-35
#also TechNote - Apple IIe #3 Double High-Resolution Graphics - http://web.pdx.edu/~heiss/technotes/aiie/tn.aiie.03.html
#HGR screen consists of 3 bands of 8 rows of 8 scanlines
#for each absolute scanline, what is the offset into screen ram that the 40 bytes for this scanline is stored?

@@scanline_offsets=Array.new(HGR_ROWS)

0.upto(2) do |band|
		0.upto(7) do |row|						
			0.upto(7) do |relative_scanline|
				band_ram_offset=band*40
				band_scanline_offset=band*64
				scanline_ram_offset=relative_scanline*1024
				scanline_scanline_offset=relative_scanline
				row_ram_offset=128*row
				row_scanline_offset=8*row
				scanline_offset=band_scanline_offset+scanline_scanline_offset+row_scanline_offset
				ram_offset=band_ram_offset+scanline_ram_offset+row_ram_offset								
				@@scanline_offsets[scanline_offset]=ram_offset
		end
	end
end


0.upto(HGR_ROWS-1) do |scanline|
	puts "no offset defined for scanline #{scanline}" if @@scanline_offsets[scanline].nil?
end
	#HGR screen is 8192 bytes stored at either $2000 (page 1) or $4000 (page 2)
	def HGR.can_be_hgr_screen?(buffer,memory_location=nil)
		if ((memory_location.nil?) || (memory_location==0) || (memory_location==0x2000) || (memory_location==0x4000)) then
		#because only 120 out of every 128 bytes are shown, the last 8 bytes are not needed
		#in order to save a sector under dos 3.3 it was common to only store 8192=8184 (0x1FF8) bytes
		#sometimes an extra sector was included by mistake
			if (buffer.length>=8184 && buffer.length<=8192)
				return true
			end
		end
		false
	end

private
	def HGR.set_pixel(canvas,x,y,colour)
		0.upto(SCALE-1) do |row|
			0.upto(SCALE-1) do |col|
				canvas[x*SCALE+col, y*SCALE+row]= colour
			end
		end
	end

public
	def HGR.buffer_to_png(buffer,pallete_mode=:amber)
		canvas = PNG::Canvas.new HGR_COLS*SCALE, HGR_ROWS*SCALE, PNG::Color::Black
		0.upto(HGR_ROWS-1) do |y|
			last_bit_set=false
			0.upto(39) do |x_byte|
				offset=@@scanline_offsets[y]+x_byte
				current_byte=buffer[offset]				
				current_byte=0 if current_byte.nil? #if we overrun the buffer then assume it's black
				0.upto(6) do |x_bit|
					x=x_byte*7+x_bit
					bit_set=((current_byte & (2**x_bit))>0)
					if (bit_set) then
						if pallete_mode==:colour then
							if (last_bit_set) then 
								#adjacent pixels should both be white
								set_pixel(canvas,x-1,y,HGR_WHITE) 
								set_pixel(canvas,x,y,HGR_WHITE)
							else
								if current_byte>=0x80 then
									pallete=[HGR_BLUE,HGR_ORANGE]
								else
									pallete=[HGR_VIOLET,HGR_GREEN]
								end
								this_pixel_colour=pallete[x%2]
								set_pixel(canvas,x,y,this_pixel_colour)
							end
						else
							this_pixel_colour=PALLETE[pallete_mode]
							this_pixel_colour=PALLETE.values[0] if this_pixel_colour.nil?
							set_pixel(canvas,x,y,this_pixel_colour)
						end
					end
					last_bit_set=bit_set
				end
			end
		end
		png = PNG.new canvas
		png.raw_bytes
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
