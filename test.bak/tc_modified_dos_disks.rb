#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestModifiedDOSDisks <Test::Unit::TestCase
	
	def test_dsk_image
		dskname=File.dirname(__FILE__)+"//sword.dsk"
		dsk=DSK.read(dskname)
		assert_equal(:modified_dos,dsk.file_system,"#{dskname} should have modified DOS file system")
		assert_equal(0x22,dsk.vtoc_track_no, "{#dskname} should have VTOC at 0x22")  
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
    pic_file=dsk.files["STORDTHRUST.PIC"]
		assert(pic_file.can_be_picture?)
	end

	def test_nib_image
		dskname=File.dirname(__FILE__)+"//SWRDTH1.NIB"
		dsk=DSK.read(dskname)
		assert_equal(:modified_dos,dsk.file_system,"#{dskname} should have modified DOS file system")
		assert_equal(0x22,dsk.vtoc_track_no, "{#dskname} should have VTOC at 0x22")  
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
#    puts dsk.dump_catalog
#    puts dsk.hex_dump
    pic_file=dsk.files["SWORDTHRUST.PIC"]
    assert(!pic_file.nil?,"SWORDTHRUST.PIC filename should be correct")
		assert(pic_file.can_be_picture?)
	end

end
