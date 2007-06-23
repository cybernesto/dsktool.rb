#!/usr/bin/ruby
# dskserver.rb
#
# == Synopsis
# A web-based DSK file explorer
#
# == Usage
# dskserver.rb [switches] 
#
#  -h | --help               display this message
#  -p | --port PORT_NUMBER   port number to listen on (default is 6052)
#  -r | --root ROOT_DIR      root directory to explore from (default is current directory)
#  -v | --version            show version number

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
opts.on("-r","--root ROOT_DIR",String) {|val| @@root_directory=val}

filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
	
require 'webrick'
require 'cgi'
require 'DSK'
include WEBrick

def common_header
"
	<html>
	<body>
<B>DSK Server</b><br>
"
end
def common_footer
"
"
end

def root_dir_is_website?
	require 'hpricot'
	require 'open-uri'
	@@root_directory=~/^http[s]?:/?true : false
end
def get_directories_and_files(relative_path)
	directories=[]
	dsk_files=[]
	if root_dir_is_website? then
		html=open(@@root_directory+relative_path).read
		doc=Hpricot(html)
		doc.search("a[@href]").each do |a|
			href=CGI.unescape(a.attributes["href"])
			if (href=~/\w\/$/) then #directories end with a /
				directories<<File.basename(href)
			elsif DSK.is_dsk_file?(href) then
				dsk_files<<File.basename(href)
			end
		end
	else 
		if File.exist?(absolute_path) && (File.stat(absolute_path).directory?) then
			absolute_path=@@root_directory+relative_path
			dir=Dir.new(absolute_path)
			dir.each do |f| 
				directories<<f if (f[0].chr!=".") && (File.stat(absolute_path+"/"+f).directory?)
				dsk_files<<f if (DSK.is_dsk_file?(f))
			end
		end
	end
	[directories,dsk_files]
end

def make_navigation_path(relative_path,filename=nil)
	path_parts=relative_path.split("/")
	#make the cookie-crumb-trail 
	partial_path=""
	s="<a href=/dir/>#{@@root_directory}</a>"
	path_parts.each do |p|
		if p.length>0 then
			partial_path+="/#{p}"			
			if DSK.is_dsk_file?(partial_path) then
				s+=" / <a href=/catalog#{CGI.escape(partial_path)}> #{p}</a>"
			else
				s+=" / <a href=/dir#{CGI.escape(partial_path)}> #{p}</a>"
			end
		end
	end
	
	if !filename.nil? then
		s+=" / <a href=/showfile/#{CGI.escape(relative_path)+'?filename='+CGI.escape(filename)}>#{filename}</a>"
	end

	
	#show the contents of the current directory
	directories,dsk_files=get_directories_and_files(relative_path)

	#list out the directories
	
	s+="<ul>"
	s+="<li>[dir] <a href=/#{CGI.escape('/dir/'+File.dirname(relative_path))}>..</a>\n"
	directories.sort.each do |d|
		s+="<li>[dir] <a href=/#{CGI.escape('/dir/'+relative_path+'/'+d)}>#{d}</a>\n"
	end
	
	#list out the DSK files		
	dsk_files.sort.each do |f|
		s+="<li>[dsk] <a href=/#{CGI.escape('/catalog/'+relative_path+'/'+f)}>#{f}</a>\n"
	end
	s+="</ul>"

	s
end
def make_catalog(relative_path)
	s="<p>"
	begin
		absolute_path=@@root_directory+relative_path
		dsk=DSK.read(absolute_path)
		
		if (dsk.is_dos33?) then
			s+="<table>\n<th>TYPE</th><th>SECTORS</th><th>NAME</th></tr>\n"
			dsk.files.each_value do |f|
				s+="<td>#{f.file_type}</td><td>#{sprintf('%03d',f.sector_count)}</td><td><a href=/showfile/#{CGI.escape(relative_path)+'?filename='+CGI.escape(f.filename)}>#{f.filename}</a></td></tr>\n"
			end
			s+="</table>"
		else
			s+="<i>not DOS 3.3 format</i>"
		end
	rescue Exception => exception
		s+="<i>ERROR:#{exception}</i>"
	end
	s
	
	
	
	
end
def show_file(relative_path,filename)
	absolute_path=@@root_directory+relative_path
	dsk=DSK.read(absolute_path)
	file=dsk.files[filename]
	if file.nil? then
		s="<i>#{filename} not found</i>"
	else 
		s="<hl><pre>#{file.file_type=='B'?file.disassembly : file.to_s}\n</pre><hl>"
	end
	s
end

class DirectoryServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=CGI.unescape(req.path).sub(/^\/dir/,"")
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path)+common_footer
	end
end

class CatalogServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=CGI.unescape(req.path).sub(/^\/catalog/,"")
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path)+make_catalog(relative_path)+common_footer
	end
end

class ShowFileServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=CGI.unescape(req.path).sub(/^\/showfile/,"")
		filename=CGI.unescape(req.query['filename'])
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path,filename)+show_file(relative_path,filename)+common_footer
	end
end

s=HTTPServer.new(
	:Port=>@listening_port
)
trap("INT") {s.shutdown}

s.mount("/dir",DirectoryServlet)
s.mount("/catalog",CatalogServlet)
s.mount("/showfile",ShowFileServlet)

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
