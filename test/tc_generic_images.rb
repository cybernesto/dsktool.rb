#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'test/unit'
require 'FSImage'

class TestGenericImages <Test::Unit::TestCase

def test_generic_d64
  filename=	"XMAS89A.D64"
  full_filename=File.dirname(__FILE__)+"//"+filename
  fsimage=FSImage.read(full_filename)
  assert(fsimage.kind_of?(CBMImage),"#{filename} should be a CBM image")
end

def test_generic_dsk
  filename=	"music.dsk"
  full_filename=File.dirname(__FILE__)+"//"+filename
  fsimage=FSImage.read(full_filename)
  assert(fsimage.kind_of?(DSK),"#{filename} should be a DSK image")
end
end