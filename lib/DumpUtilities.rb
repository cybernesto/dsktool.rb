class DumpUtilities
  
  def DumpUtilities.hex_dump(buffer)
   	s=""
		(0..(buffer.length/16)).each {|line_number|
			 lhs=""
			 rhs=""
			 start_byte=line_number*16
			 line=buffer[start_byte..start_byte+15]
			if line.length>0 then
				 line.each_byte {|byte|
					  lhs+= sprintf("%02X ", byte)
					  rhs+= (64+byte%64).chr.sub(/[\x00-\x1f]/,'.')
			 	}
				lhs+=" "*(16-line.length)*3
				s+=sprintf("%02X\t%s %s\n",start_byte,lhs,rhs)
			end
		}
		s
  end
  
  def DumpUtilities.font_dump(buffer)
  #treat buffer as a set 8 bit wide characters
  s=""
  buffer.each_byte do |byte| 
      s<<sprintf("%08b\n",byte).tr("1","#").tr("0"," ")
  end
  s
  end
end