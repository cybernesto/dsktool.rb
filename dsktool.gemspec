require 'rubygems'
spec=Gem::Specification.new do |s|
	s.name="dsktool"
	s.version=(`ruby bin/dsktool.rb -v`).match('(\d)+.(\d)+.(\d)+')[0]
	s.author="Jonno Downes"
	s.email="dsktoool@jamtronix.com"
	s.homepage="http://dsktool.rubyforge.org"
	s.platform=Gem::Platform::RUBY
	s.summary="a command line tool + libraries for manipulating DSK format images as used by Apple 2 emulators" 
	candidates=Dir.glob("{bin,doc,lib,test}/**/*")
	s.files=candidates.delete_if do |item|
		item.include?(".svn") || item.include?("rdoc")

	end
	s.require_path="lib"
	s.test_file="test/ts_test_all.rb"
	s.has_rdoc=true
	s.bindir = "bin"
	s.executables = ["dsktool.rb"]

end
if $0 == __FILE__
	Gem::manage_gems
	Gem::Builder.new(spec).build
end	