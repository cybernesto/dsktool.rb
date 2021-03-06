#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestNADOLDisks <Test::Unit::TestCase


	def test_empty_dsk
		dsk=DSK.new()
		assert(dsk.file_system!=:nadol,"empty DSK should not be NADOL format")
    dsk.set_sector(0,0,"*")
    assert_equal(dsk.get_sector(0,0)[0],"*"[0],"set_sector wrote 1st byte OK")
    assert_equal(dsk.get_sector(0,0)[1],0,"set_sector wrote 2nd byte OK")
	end

	def test_simple_nadol_dsk
		dskname=File.dirname(__FILE__)+"//nadol.dsk"
		dsk=DSK.read(dskname)
		assert_equal(:nadol,dsk.file_system,"#{dskname} should be NADOL format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		nadol_file=dsk.files["NADOL"]
		assert(nadol_file!=nil,"#{dskname} should have a file called NADOL")
		assert(nadol_file.to_s.length==16128,"NADOL should be 16128 bytes long")
		assert(nadol_file.respond_to?(:disassembly),"NADOL can be disassembled")
		assert(!NADOLTokenisedFile.can_be_nadol_tokenised_file?(nadol_file.contents),"NADOL should not be NADOL tokenised file")
		brickout_file=dsk.files["BRICKOUT"]
		assert(brickout_file!=nil,"#{dskname} should have a file called BRICKOUT")
		assert(NADOLTokenisedFile.can_be_nadol_tokenised_file?(dsk.files["BRICKOUT"].contents),"BRICKOUT should be NADOL tokenised file")
		assert(nadol_file.respond_to?(:disassembly),"BRICKOUT can't be disassembled")
		s=brickout_file.to_s
		assert(!brickout_file.can_be_picture?,"BRICK-OUT should NOT be viewable as a picture")		
		assert_equal("; LORES BRICK-OUT GAME",s[0..21],"BRICK-OUT source should detokenise")
		assert_equal("; @ \"NAIII\"",dsk.files["NAIII"].to_s[0..10],"NAIII source should detokenise")

    test_file=NADOLFile.new("TESTFILE","Is this mike on?")
    assert(test_file!=dsk.files["LOGO"],"comparison between files doesn't have false positive")
    dsk.add_file(test_file)
    assert(dsk.files[test_file.filename]!=nil,"#{dskname} should have a file called #{test_file.filename}")
    assert_equal(test_file,dsk.files[test_file.filename])

    #try to round_trip a tokenised NADOL file
    copy_of_tokenised_file=dsk.make_file("BBALL2",dsk.files["BOUNCINGBALL"].to_s,{:tokenise=>true})
    assert_equal(dsk.files["BOUNCINGBALL"].to_s,copy_of_tokenised_file.to_s,"NADOL tokenised file should round-trip")
    dsk.add_file(copy_of_tokenised_file)
    
    #test we can write muliple files (this also tests we are correctly tracking sectors as being used)
    test_files=[]
    for i in 0..20
      t=dsk.make_file("TEST#{i}","TEST #{i} "+"*"*i*100)
      test_files<<t
      dsk.add_file(t)
    end    
    puts dsk.dump_catalog
    dsk.save_as("nadol2.po")
    for i in 0..20
      assert_equal(test_files[i],dsk.files[test_files[i].filename])
    end
    
    #make sure we can overwrite the same file (which also tests we are freeing sectors when files are deleted)
    for i in 0..250
      t=dsk.make_file("MULTICOPY","TEST #{i} ")
      dsk.add_file(t)
      assert_equal(t,dsk.files[t.filename])
    end   
    
    #check picture files can be extracted
		pic_file=dsk.files["LOGO"]
		assert(pic_file!=nil,"#{dskname} should have a file called LOGO")
		assert(pic_file.can_be_picture?,"LOGO should be viewable as a picture")
		assert_equal("\211PNG\r\n\032\n",pic_file.to_png[0..7])

	end

end
