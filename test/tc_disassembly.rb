require 'test/unit'
require '../lib/D65'
require '../lib/DSK'

class TestDisassembly <Test::Unit::TestCase

	def test_simple
		assert(/RTS/.match(D65.disassemble("\x60")),"disassembly of 0x60 should be RTS")

	end

end