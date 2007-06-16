#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'DSK'

class TestDOSDisks <Test::Unit::TestCase
	def test_bad_dsks
		assert_raise(RuntimeError,"short file should throw an error") {dsk=DSK.new("0"*100)}
		assert_raise(Errno::ENOENT,"non existant file should throw an error") {dsk=DSK.read("NonExistantFileName.not")}
	end


	def test_empty_dsk
		dsk=DSK.new()
		assert(!dsk.is_dos33?,"empty DSK should not be DOS 3.3 format")
	end

	def test_simple_dos_dsk
		dskname=File.dirname(__FILE__)+"//dos33_with_adt.dsk"
		dsk=DSK.read(dskname)
		assert(dsk.is_dos33?,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		
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

		
		integer_file=dsk.files["APPLESOFT"]
		assert(integer_file!=nil,"#{dskname} should have a file called APPLESOFT")
		assert(integer_file.instance_of?(IntegerBasicFile),"HELLO should be an IntegetBasic file")
		assert(integer_file.to_s.length>0,"APPLESOFT should have non-zero length")
		assert(integer_file.to_s[0..5]=="10 REM","APPLESOFT should start '10 REM'")		
	end

	def test_scasm_file
		dskname=File.dirname(__FILE__)+"//AAL_1.DSK"
		dsk=DSK.read(dskname)
		assert(dsk.is_dos33?,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		
		asm_file=dsk.files["MORSE CODE"]
		assert(asm_file!=nil,"#{dskname} should have a file called MORSE CODE")
		assert(asm_file.instance_of?(SCAsmFile),"MORSE CODE should be an SCasm file")
		assert(asm_file.to_s.length>0,"MORSE CODE should have non-zero length")
		assert(!(asm_file.to_s=~/930\W*.LIST OFF/).nil?,"MORSE CODE should start '930        .LIST OFF'")
	end

	def test_compressed_dos_dsk
		dskname=File.dirname(__FILE__)+"//vaults_of_zurich.dsk.gz"
		dsk=DSK.read(dskname)
		assert(dsk.is_dos33?,"#{dskname} should be DOS 3.3 format")
		assert(dsk.files.length>0,"#{dskname} should have at least one file")
		
		hello_file=dsk.files["HELLO"]
		assert(hello_file!=nil,"#{dskname} should have a file called HELLO")
		assert(hello_file.instance_of?(AppleSoftFile),"HELLO should be an AppleSoft file")
	end	
end