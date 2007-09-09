#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestProDOSDisks <Test::Unit::TestCase
	
	def test_other_dsk_types
		dsk=DSK.new()
		assert(dsk.file_system!=:prodos,"empty DSK should not be PRODOS format")

		dskname=File.dirname(__FILE__)+"//dos33_with_adt.dsk"
		dsk=DSK.read(dskname)
		assert(dsk.file_system!=:prodos,"#{dskname} should not be ProDOS format")

		dskname=File.dirname(__FILE__)+"//nadol.dsk"
		dsk=DSK.read(dskname)
		assert(dsk.file_system!=:prodos,"#{dskname} should not be ProDOS format")

	end
	def test_simple_prodos_disk

		dskname=File.dirname(__FILE__)+"//dosmaster.po"
		dsk=DSK.read(dskname)
		assert_equal(:prodos,dsk.file_system,"#{dskname} should have ProDOS file system")
		assert_equal(:physical,dsk.sector_order,"#{dskname} should have ProDOS order")
		assert_equal("NEW.DISK",dsk.volume_name)

		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		bas_file=dsk.files["STARTUP"]
		assert(bas_file!=nil,"#{dskname} should have a file called STARTUP")
		assert_equal("10 PRINT CHR$ (4)\"PR#3\"",bas_file.to_s[0..22],"STARTUP should detokenise")
	end

	def test_dos_interleave_prodos_disks

		dskname=File.dirname(__FILE__)+"//ADTPRO-1.0.1.DSK"
		dsk=DSK.read(dskname)
		assert_equal(:prodos,dsk.file_system,"#{dskname} should have ProDOS file system")
		assert_equal(:prodos_from_dos,dsk.sector_order,"#{dskname} should have DOS sector order")
		assert_equal("ADTPRO.1.0.1",dsk.volume_name)

		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		bas_file=dsk.files["STARTUP"]
		assert(bas_file!=nil,"#{dskname} should have a file called STARTUP")
		assert_equal("10 TEXT : NORMAL : HOME",bas_file.to_s[0..22],"STARTUP should detokenise")
		
		dskname=File.dirname(__FILE__)+"//Apple Works V5.0 (1993)(Beagle Bros)(Disks 5 of 6).dsk.gz"
		dsk=DSK.read(dskname)
		assert_equal(:prodos,dsk.file_system,"#{dskname} should have ProDOS file system")
		assert_equal(:prodos_from_dos,dsk.sector_order,"#{dskname} should have DOS sector order")
		assert_equal("MOVE13",dsk.volume_name)

		assert(dsk.files.length>0,"#{dskname} should have at least one file")
#		dsk.dump_catalog
		awp_file=dsk.files["AW.INITS/NARNIA.KNAVES"]
		assert(bas_file!=nil,"#{dskname} should have a file called  AW.INITS/NARNIA.KNAVES")
		assert_equal("This bonus screen blanker",awp_file.to_s[0..24])
		

		
	end

end
