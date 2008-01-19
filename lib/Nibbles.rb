$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'DSK'

class Nibbles
#  DEBUG=true
 DEBUG=false

  #dos interleave table (from Beneath Apple DOS p 3-23)
  INTERLEAVES=[0x00,0x07,0x0E,0x06,0x0D,0x05,0x0C,0x04,0x0B,0x03,0x0A,0x02,0x09,0x01,0x08,0x0F]

  #6-2 translate table (from Beneath Apple DOS p 3-17)
  DATA_TRANSLATE_TABLE=[
  0x96,#00
  0x97,#01
  0x9A,#02
  0x9B,#03
  0x9D,#04
  0x9E,#05
  0x9F,#06
  0xA6,#07
  0xA7,#08
  0xAB,#09
  0xAC,#0A
  0xAD,#0B
  0xAE,#0C
  0xAF,#0D
  0xB2,#0E
  0xB3,#0F
  0xB4,#10
  0xB5,#11
  0xB6,#12
  0xB7,#13
  0xB9,#14
  0xBA,#15
  0xBB,#16
  0xBC,#17
  0xBD,#18
  0xBE,#19
  0xBF,#1A
  0xCB,#1B
  0xCD,#1C
  0xCE,#1D
  0xCF,#1E
  0xD3,#1F
  0xD6,#20
  0xD7,#21
  0xD9,#22
  0xDA,#23
  0xDB,#24
  0xDC,#25
  0xDD,#26
  0xDE,#27
  0xDF,#28
  0xE5,#29
  0xE6,#2A
  0xE7,#2B
  0xE9,#2C
  0xEA,#2D
  0xEB,#2E
  0xEC,#2F
  0xED,#30
  0xEE,#31
  0xEF,#32
  0xF2,#33
  0xF3,#34
  0xF4,#35
  0xF5,#36
  0xF6,#37
  0xF7,#38
  0xF9,#39
  0xFA,#3A
  0xFB,#3B
  0xFC,#3C
  0xFD,#3D
  0xFE,#3E
  0xFF,#3F
  ]

  TRACK_LENGTH=6656

  def Nibbles.decode_4_4(bytes)
    return((bytes[0] << 1) | 1) & bytes[1]
  end

  def Nibbles.make_dsk_from_nibbles(nibbles)
    dsk=DSK.new()
    0.upto(0x22) {|track_no| set_dsk_sectors_for_nibbles_track(nibbles,dsk,track_no)}
    dsk
  end
  
  def Nibbles.get_track(nibbles,track_no)
    nibbles[track_no*TRACK_LENGTH..((track_no+1)*TRACK_LENGTH)-1]
  end

  def Nibbles.set_dsk_sectors_for_nibbles_track(nibbles,dsk,track_no) 
    
    sector_regex=/(\xD5.{8}[^D5]{1,20}\xFF+\xD5[^xD5]{348})/
    track_nibbles=get_track(nibbles,track_no)
    track_nibbles<<=track_nibbles[0..400]#wrap around one full sector
    if DEBUG then
      puts "#start track data"
      track_nibbles.each_byte{|b| printf "%02X",b}    
      puts "# end track data"
    end  
    
    sectors=track_nibbles.split(sector_regex)  
    sector_count=0
    sector_has_been_read=[false]*16
    sectors.each do |sector_nibbles|
    
      if DEBUG then  
        puts "#start sector data"
        sector_nibbles.each_byte{|b| printf "%02X",b}    
        puts "# end sector data"    
      end
      next unless sector_nibbles=~/^\xFF*\xD5/

      address_field,data_field=/\xFF*(\xD5.*)(\xD5.*)/.match(sector_nibbles).captures
      address_field.each_byte{|b| printf "%02X",b}  if DEBUG
      vol_no=decode_4_4(address_field[3..4])
      track_no=decode_4_4(address_field[5..6])
      sector_no=decode_4_4(address_field[7..8])
      next unless sector_no<16
      next if sector_has_been_read[sector_no]
      sector_has_been_read[sector_no]=true
      sector_count+=1
      if DEBUG then
        puts "VOL #{vol_no} TRACK #{track_no} SECTOR #{sector_no}"
        puts "#start data"
        data_field.each_byte{|b| printf "%02X",b}    
        puts "# end data"
    end
      undecoded_data=data_field[3..345]
      decoded_data='\0'*343
      #algorithm taken from http://www.umich.edu/~archive/apple2/misc/hardware/disk.encoding.txt
      checksum=0
      0.upto(341) do |i|
        undecoded_byte=undecoded_data[i]
        decoded_byte=DATA_TRANSLATE_TABLE.index(undecoded_byte)
        raise "invalid nibble #{sprintf '%02X',undecoded_byte} at nibble #{i}, track #{track_no}, sector #{sector_no}" if decoded_byte.nil?
        decoded_byte^=checksum
        if i<86 then
          destination_offset=341-i
        else
          destination_offset=i-86
        end
        decoded_data[destination_offset]=decoded_byte
        checksum=decoded_byte
  #        puts "-- #{i} - #{checksum} #{sprintf '%-3x',destination_offset}"
      end
      
      #raise "invalid checksum #{checksum}" unless  checksum==0
      
      0.upto(255) do |i|
        decoded_data[i]<<=2

        lower_2_bits=decoded_data[341-i%0x56]
        case i/86
          when 0 then
            bit1=lower_2_bits&0x01
            bit0=(lower_2_bits&0x02)>>1
          when 1 then          
            bit1=(lower_2_bits&0x04)>>2
            bit0=(lower_2_bits&0x08)>>3
          when 2 then
            bit1=(lower_2_bits&0x010)>>4
            bit0=(lower_2_bits&0x20)>>5        
        end
        printf "#{i} #{i/86} %08b #{bit0} #{bit1}\n",lower_2_bits if DEBUG
        decoded_data[i]|=bit0
        decoded_data[i]|=bit1<<1      
      end
      logical_sector_no=INTERLEAVES[sector_no]
      puts "mapping physical #{sprintf '%02X',sector_no} to logical #{sprintf '%02X',logical_sector_no}" if DEBUG
      dsk.set_sector(track_no,logical_sector_no,decoded_data[0..255])
      puts dsk.dump_sector(track_no,logical_sector_no) if DEBUG
    end
    raise "expected 16 sectors but found #{sector_count}" unless sector_count==16
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

