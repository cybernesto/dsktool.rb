#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestNADOLDisks <Test::Unit::TestCase


	def test_empty_dsk
		dsk=DSK.new()
		assert(!dsk.is_nadol?,"empty DSK should not be NADOL format")
	end

	def test_simple_nadol_dsk
		dskname=File.dirname(__FILE__)+"//nadol.dsk"
		dsk=DSK.read(dskname)
		assert(dsk.is_nadol?,"#{dskname} should be NADOL format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		dsk.dump_catalog
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
		assert_equal("; LORES BRICK-OUT GAME",s[0..21],"BRICK-OUT source should detokenise")
		assert_equal("; @ \"NAIII\"",dsk.files["NAIII"].to_s[0..10],"NAIII source should detokenise")
	end

end
