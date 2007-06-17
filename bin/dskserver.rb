#!/usr/bin/ruby
# dskserver.rb
#
# == Synopsis
# A web-based DSK file explorer
#
# == Usage
# dskserver.rb [switches] 
#
#  -h | --help                 display this message
#  -d | --directory ROOT_DIR   root directory to explore from (default is current directory)
#  -p | --port PORT_NUMBER     port number to listen on (default is 6052)
#  -v | --version              show version number

#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'optparse'
require 'rdoc_patch' #RDoc::usage patched to work under gem executables

DSKSERVER_VERSION="0.1.0"

@listening_port=6502
@@root_directory="."
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage_from_file(__FILE__)}
opts.on("-v","--version") do
	puts File.basename($0)+" "+DSKSERVER_VERSION
	exit
end
opts.on("-p","--port PORT_NUMBER",Integer) {|val| @listening_port=val%0xFFFF}
opts.on("-d","--directory ROOT_DIR",String) {|val| @@root_directory=val}

filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
	
require 'webrick'
require 'cgi'
require 'DSK'
include WEBrick

def common_header
"
	<html><head><title>dskserver.rb</title></head>
	<body><h1>dskserver.rb</h1>

"
end
def common_footer
"
	<p><i>#{Time.now()}</i>
	</body></html>

"
end

def make_navigation(relative_path)
	path_parts=relative_path.split("/")
	#make the cookie-crumb-trail 
	partial_path="/dir/"
	s="<a href=/dir/>[top directory]</a>"
	path_parts.each do |p|
		if p.length>0 then
			partial_path+="#{CGI.escape(p)}/"
			s+=" / <a href=#{partial_path}> #{p}</a>"
		end			
	end
	
	#show the contents of the current directory
	dir=Dir.new(absolute_path)
	directories=[]
	dsk_files=[]
	dir.each do |f| 
		directories<<f if (f[0].chr!=".") && (File.stat(absolute_path+"/"+f).directory?)
		dsk_files<<f if (DSK.is_dsk_file?(f))
	end
	#list out the directories
	s+="<ul>"
	directories.sort.each do |d|
		s+="<li><a href=/#{CGI.escape('/dir/'+relative_path+'/'+d)}>#{d}</a>\n"
	end
	s+="</ul>"
	#list out the DSK files
	s+="<table>"
	dsk_files.sort.each do |f|
		s+="<tr><td>#{f}</td><td><a href=/#{CGI.escape('/catalog/'+relative_path+'/'+f)}>catalog</a></td></tr>\n"
	end
	s+="</table>"

	s

end
class DirectoryServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=CGI.unescape(req.path).sub(/^\/dir/,"")
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path)+common_footer
	end
end

s=HTTPServer.new(
	:Port=>@listening_port
)
trap("INT") {s.shutdown}

s.mount("/dir",DirectoryServlet)

puts "point your browser at http://localhost:#{@listening_port}/"
s.start

# == Author
# Jonno Downes (jonno@jamtronix.com)
#
# == Copyright
# Copyright (c) 2007 Jonno Downes (jonno@jamtronix.com)
#
#Permission is hereby granted, free of charge, to any person obtaining
#a copy of this software and associated documentation files (the
#"Software"), to deal in the Software without restriction, including
#without limitation the rights to use, copy, modify, merge, publish,
#distribute, sublicense, and/or sell copies of the Software, and to
#permit persons to whom the Software is furnished to do so, subject to
#the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
