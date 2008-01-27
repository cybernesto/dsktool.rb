#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'D65'
require 'DSK'

class TestDisassembly <Test::Unit::TestCase

	def test_simple
		assert(/RTS/.match(D65.disassemble("\x60")),"disassembly of 0x60 should be RTS")

	end

end