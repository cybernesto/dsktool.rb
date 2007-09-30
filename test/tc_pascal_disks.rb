#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestPascalDisks <Test::Unit::TestCase
	
	def test_other_dsk_types
		dsk=DSK.new()
		assert(dsk.file_system!=:pascal,"empty DSK should not be Pascal format")

		dskname=File.dirname(__FILE__)+"//dos33_with_adt.dsk"
		dsk=DSK.read(dskname)
		assert(dsk.file_system!=:pascal,"#{dskname} should not be Pascal format")

		dskname=File.dirname(__FILE__)+"//nadol.dsk"
		dsk=DSK.read(dskname)
		assert(dsk.file_system!=:pascal,"#{dskname} should not be Pascal format")

	end
	def test_simple_pascal_disk

		dskname=File.dirname(__FILE__)+"//Algebra Mentor (19xx)(John C. Miller)(Disk 1 of 7 Side A)(Student Disk 1).dsk.gz"
		dsk=DSK.read(dskname)
		assert_equal(:pascal,dsk.file_system,"#{dskname} should have Pascal file system")
		assert_equal("A1011",dsk.volume_name)

		assert(dsk.files.length>0,"#{dskname} should have at least one file")
	end


end
