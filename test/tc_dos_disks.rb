#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestDOSDisks <Test::Unit::TestCase


	def test_file_names
		assert(DSK.is_dsk_file?("file.dsk"))
		assert(DSK.is_dsk_file?("file.DSK"))
		assert(DSK.is_dsk_file?("file.dsk.gz"))
		assert(DSK.is_dsk_file?("file.po"))
		assert(DSK.is_dsk_file?("file.po.gz"))
    assert(DSK.is_dsk_file?("file.do"))
    assert(DSK.is_dsk_file?("file.DO.gz"))
		assert(!DSK.is_dsk_file?("file.dsk.zip"))

	end
	def test_bad_dsks
		assert_raise(RuntimeError,"short file should throw an error") {dsk=DSK.new("0"*100)}
		assert_raise(Errno::ENOENT,"non existant file should throw an error") {dsk=DSK.read("NonExistantFileName.not")}
	end

  def test_write_to_dsk
    dsk=DSK.create_new(:dos33)
    test_file=TextFile.new("TESTFILE","Is this mike on?")
    dsk.add_file(test_file)
    assert(dsk.files[test_file.filename]!=nil,"dsk should have a file called #{test_file.filename}")
    assert_equal(test_file,dsk.files[test_file.filename])
    
    #test we can write muliple files (this also tests we are correctly tracking sectors as being used)
    test_files=[]
    for i in 0..20
      t=dsk.make_file("TEST#{i}","TEST #{i} "+"*"*i*100)
      test_files<<t
      dsk.add_file(t)
    end    
    
    for i in 0..20
      assert_equal(test_files[i],dsk.files[test_files[i].filename])
    end
    
    #test we can make other file types
    [
      TextFile,
      BinaryFile,
      AppleSoftFile
    ].each do |file_class|
      test_file=file_class.new("TEST_"+file_class.to_s.upcase,"\FF"*256)
      dsk.add_file(test_file)
      assert_equal(test_file,dsk.files[test_file.filename])
    end
    
    
    #make sure we can overwrite the same file (which also tests we are freeing sectors when files are deleted)
    for i in 0..250
      t=dsk.make_file("MULTICOPY","TEST #{i} ")      
      dsk.add_file(t)      
      assert_equal(t,dsk.files[t.filename])
    end     
    
    #check none of the above has clobbered our original 20 test files
    for i in 0..20
      assert_equal(test_files[i],dsk.files[test_files[i].filename])
    end
  
  #save disk for later examination
  dsk.save_as("dos_write_test.dsk")

  end
  
  def test_free_sector_list
    dskname=File.dirname(__FILE__)+"//white_11a.dsk"
    dsk=DSK.read(dskname)
		assert_equal(:dos,dsk.file_system,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
    assert(!dsk.free_sector_list.nil?,"should have at least 1 free sector")
  end
	def test_dump_sector
		dskname=File.dirname(__FILE__)+"//AAL_1.DSK"
		dsk=DSK.read(dskname)
		assert_equal(dsk.dump_sector(0,0).length,dsk.dump_sector(0,2).length,"sector dumps should be consistent length")
	end

	def test_empty_dsk
		dsk=DSK.new()
		assert(dsk.file_system!=:dos,"empty DSK should not be DOS 3.3 format")
	end

	def test_open_url_to_compressed_dsk
		dskname="http://www.apple2.org.za/mirrors/ftp.apple.asimov.net/images/games/adventure/vaults_of_zurich.dsk.gz"
		dsk=DSK.read(dskname)
		assert_equal(:dos,dsk.file_system,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		
		hello_file=dsk.files["HELLO"]
		assert(hello_file!=nil,"#{dskname} should have a file called HELLO")
		assert(hello_file.instance_of?(AppleSoftFile),"HELLO should be an AppleSoft file")
	end

	def test_simple_dos_dsk
		dskname=File.dirname(__FILE__)+"//dos33_with_adt.dsk"
		dsk=DSK.read(dskname)
		assert_equal(:dos,dsk.file_system,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")

    assert(!dsk.find_catalog_slot("HELLO").nil?,"should find catalog slot for HELLO")
    
		hello_file=dsk.files["HELLO"]
    
		assert(hello_file!=nil,"#{dskname} should have a file called HELLO")
		assert(hello_file.instance_of?(AppleSoftFile),"HELLO should be an AppleSoft file")
		assert(hello_file.to_s.length>0,"HELLO should have non-zero length")
		assert(hello_file.to_s[0..5]=="10 REM","HELLO should start '10 REM'")

		binary_file=dsk.files["MUFFIN"]
		assert(binary_file!=nil,"#{dskname} should have a file called MUFFIN")
		assert(binary_file.instance_of?(BinaryFile),"HELLO should be an Binary file")
		assert(binary_file.to_s.length>0,"MUFFIN should have non-zero length")		
		assert(binary_file.disassembly.length>0,"MUFFIN disassembly should have non-zero length")
		assert(binary_file.disassembly[0..4]=="0803:","MUFFIN disassembly should start at $803")
		assert(!binary_file.can_be_picture?,"MUFFIN should NOT be viewable as a picture")

		
		integer_file=dsk.files["APPLESOFT"]
		assert(integer_file!=nil,"#{dskname} should have a file called APPLESOFT")
		assert(integer_file.instance_of?(IntegerBasicFile),"HELLO should be an IntegetBasic file")
		assert(integer_file.to_s.length>0,"APPLESOFT should have non-zero length")
		assert(integer_file.to_s[0..5]=="10 REM","APPLESOFT should start '10 REM'")		
		assert(!integer_file.can_be_picture?,"APPLESOFT should NOT be viewable as a picture")

	end

def test_musiccomp_file
		dskname=File.dirname(__FILE__)+"//music.dsk"
		dsk=DSK.read(dskname)
		assert_equal(:dos,dsk.file_system,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")		
		file=dsk.files["ENTERTAINER ;MUSIC"]
		assert(file!=nil,"#{dskname} should have a file called ENTERTAINER ;MUSIC")
		assert(file.instance_of?(MusiCompFile),"ENTERTAINER ;MUSIC should be a MusiComp file")
		assert(!file.can_be_picture?,"ENTERTAINER ;MUSIC should NOT be viewable as a picture")
		assert(file.to_s.length>0,"ENTERTAINER ;MUSIC should have non-zero length")
		assert_equal("MThd",file.to_s[0,4],"ENTERTAINER ;MUSIC should start with a MIDI header (MThd)")
end
	

	def test_scasm_file
		dskname=File.dirname(__FILE__)+"//AAL_1.DSK"
		dsk=DSK.read(dskname)
		assert_equal(:dos,dsk.file_system,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")		
		asm_file=dsk.files["MORSE CODE"]
		assert(asm_file!=nil,"#{dskname} should have a file called MORSE CODE")
		assert(asm_file.instance_of?(SCAsmFile),"MORSE CODE should be an SCasm file")
		assert(!asm_file.can_be_picture?,"MORSE CODE should NOT be viewable as a picture")
		assert(asm_file.to_s.length>0,"MORSE CODE should have non-zero length")
		assert(!(asm_file.to_s=~/930\W*.LIST OFF/).nil?,"MORSE CODE should start '930        .LIST OFF'")

	end
	
	def test_40_track_file
		dskname=File.dirname(__FILE__)+"//white_03b.dsk"
		dsk=DSK.read(dskname)
		assert_equal(:dos,dsk.file_system,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		assert_equal(40,dsk.track_count,"#{dskname} should have 40 tracks")

		pic_file=dsk.files["RIP.PIC"]
		assert(pic_file!=nil,"#{dskname} should have a file called RIP.PIC")
		assert(pic_file.instance_of?(BinaryFile),"RIP.PIC should be a binary file")
		assert(pic_file.can_be_picture?,"RIP.PIC should be viewable as a picture")
		assert_equal("\211PNG\r\n\032\n",pic_file.to_png[0..7])
	end
  
end
