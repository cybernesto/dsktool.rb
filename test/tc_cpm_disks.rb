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
    puts dsk.dump_catalog
    assert(dsk.files.length>0,"#{dskname} should have at least one file")
		doc_file=dsk.files["STAR.DOC"]
		assert(doc_file!=nil,"#{dskname} should have a file called STAR.DOC")
    assert_equal(256,dsk.files["RDTEST.COM"].to_s.length, "RDTEST.COM should be 256 bytes long")
    
    test_file=CPMFile.new("TESTFILE.TXT","Is this mike on?")
    assert(test_file!=dsk.files["STAR.DOC"],"comparison between files doesn't have false positive")
    dsk.add_file(test_file)
    doc_file=dsk.files["STAR.DOC"]
		assert(doc_file!=nil,"#{dskname} should still have a file called STAR.DOC")
    assert(dsk.files[test_file.full_filename]!=nil,"#{dskname} should have a file called #{test_file.full_filename}")
    assert_equal(test_file,dsk.files[test_file.full_filename])

    test_file=CPMFile.new("BIGFILE.TXT","Is this mike on?"+"x"*38000)
    dsk.add_file(test_file)
    dsk.save_as("cpm_write_test.dsk")   #save for later examination
    assert(dsk.files[test_file.full_filename]!=nil,"#{dskname} should have a file called #{test_file.full_filename}")
    assert_equal(test_file.contents.length,dsk.files[test_file.full_filename].contents.length)
    
    #test we can add the same file multiple times without raising an exception
    100.times do
      dsk.add_file(test_file)
    end		
    
	end

end
