#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'D64'

class TestSimpleDisks <Test::Unit::TestCase

def test_simple_d64

  d64=0
	[
	"Appelzine_01.D64",
	"Manhood_2_Triad.d64",
	"Phantom_BBS.D64",
	"Sprite_Magic_V2.D64",
	"The_Gothicmon_V1.4.D64",
	"Toolpack_2.D64",
	"Tool_Collection_1.D64",
	"TSSV3.d64",
	"XMAS89A.D64",
	].each do |filename|

		d64name=File.dirname(__FILE__)+"//"+filename
		d64=D64.read(d64name)
		assert_equal(35,d64.track_count,"#{filename} should have 35 tracks")
#		puts d64.disk_info
#		puts d64.directory_listing
	end
#	puts d64.hex_dump
#	puts d64.dump_track(18)
	
end

end