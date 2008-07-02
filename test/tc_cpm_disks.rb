#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestCPMDisks <Test::Unit::TestCase


	def test_empty_dsk
		dsk=DSK.new()
		assert(dsk.file_system!=:cpm,"empty DSK should not be CPM format")
	end

	def test_simple_cpm_dsk
		dskname=File.dirname(__FILE__)+"//CPM1.DSK"
		dsk=DSK.read(dskname)
		assert_equal(:cpm,dsk.file_system,"#{dskname} should be CPM format")
  
		dskname=File.dirname(__FILE__)+"//CPM1.PO"
		dsk=DSK.read(dskname)
		assert_equal(:cpm,dsk.file_system,"#{dskname} should be CPM format")
  
		dskname=File.dirname(__FILE__)+"//STARCPM.DSK"
		dsk=DSK.read(dskname)
		assert_equal(:cpm,dsk.file_system,"#{dskname} should be CPM format")
    
    assert(dsk.files.length>0,"#{dskname} should have at least one file")
		doc_file=dsk.files["STAR.DOC"]
		assert(doc_file!=nil,"#{dskname} should have a file called STAR.DOC")
    assert_equal(256,dsk.files["RDTEST.COM"].to_s.length, "RDTEST.COM should be 256 bytes long")
    

	end

end
