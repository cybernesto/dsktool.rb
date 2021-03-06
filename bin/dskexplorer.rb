#!/usr/bin/ruby
# dskexplorer.rb
#
# == Synopsis
# A web-based DSK and D64 file explorer
#
# == Usage
# dskexplorer.rb [switches] 
#
#  -h | --help               display this message
#  -p | --port PORT_NUMBER   port number to listen on (default is 6502)
#  -r | --root ROOT_DIR      root directory to explore from (default is current directory)
#  -v | --version            show version number
#
# Examples
#     dskexplorer.rb -r http://www.apple2.org.za/mirrors/
#     dskexplorer.rb -r c:\downloads\apple2\ -p 8080


#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)

require 'optparse'
require 'rdoc_patch' #RDoc::usage patched to work under gem executables
	require 'hpricot'
	require 'open-uri'

dskexplorer_VERSION="0.2.0"
IS_WEBSITE_REGEX=/^http[s]?:/
IS_FTP_SITE_REGEX=/^ftp:/
@listening_port=6502
@@root_directory="."
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage_from_file(__FILE__)}
opts.on("-v","--version") do
	puts File.basename($0)+" "+dskexplorer_VERSION
	exit
end
opts.on("-p","--port PORT_NUMBER",Integer) {|val| @listening_port=val%0xFFFF}
opts.on("-r","--root ROOT_DIR",String) {|val| @@root_directory=val}

filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
@@root_directory=File.expand_path(@@root_directory) unless (@@root_directory=~IS_WEBSITE_REGEX || @@root_directory=~IS_FTP_SITE_REGEX)
require 'webrick'
require 'FSImage'
include WEBrick

@@uri_cache={}
@@fsimage_cache={}
def get_uri_from_cache(uri)
	if @@uri_cache[uri].nil? then
		@@uri_cache[uri]=open(uri).read
	end
	@@uri_cache[uri]
end

def get_fsimage_from_cache(uri)
	if @@fsimage_cache[uri].nil? then
		@@fsimage_cache[uri]=FSImage.read(uri)
	end
	@@fsimage_cache[uri]
end

def common_header
"
	<html>
	<body>
<B>DSK/D64 Explorer</b><br>
"
end
def common_footer
"
<p><i>this is alpha software - please send feedback using the <a href=http://rubyforge.org/tracker/?group_id=3844> dsktool.rb forum</a><p>
"
end

def root_dir_is_website?
	@@root_directory=~IS_WEBSITE_REGEX ?true : false
end

def root_dir_is_ftp_site?
	@@root_directory=~IS_FTP_SITE_REGEX ?true : false
end

def make_absolute_path(relative_path)
	if root_dir_is_website? then
		@@root_directory+uri_encode(relative_path)
	else
		@@root_directory+relative_path
	end	
end
def html_escape(s)	s.gsub("&","&amp;").gsub("<","&lt;")end
def uri_encode(s)
	#standard URI.escape appears to miss some important characters
	require 'uri'
	URI.escape(s).gsub("[","%5b").gsub("]","%5d").gsub(";","%3B")
end
def get_directories_and_files(relative_path)
	directories=[]
	fsimage_files=[]
	absolute_path=make_absolute_path(relative_path)
	if root_dir_is_website? then
		html=get_uri_from_cache(absolute_path)
		doc=Hpricot(html)
		doc.search("a[@href]").each do |a|
			href=URI.unescape(a.attributes["href"])
			if (href=~/\w\/$/) 
				if !(href=~/^\//) then 	#directories end with a /, but skip absolute paths
					directories<<(href)
				end
			elsif FSImage.is_fsimage_file?(href) then
				fsimage_files<<(href)
			end
		end
  elsif root_dir_is_ftp_site? then
    require 'net/ftp'
    require 'uri'    
    ftp_uri=URI.parse(absolute_path)
    ftp=Net::FTP.new(ftp_uri.host)
    ftp.login(ftp_uri.user.nil? ? 'anonymous': ftp_uri.user,ftp_uri.password)
    ftp.nlst(ftp_uri.path).each do |f|
      #yes this is a horrible hack - assume that filenames with a . are files, if no dot then assume it's a directory
      if f=~/\./ then
        fsimage_files<<f if (FSImage.is_fsimage_file?(f))
      else
        directories<<f
      end
    end
    ftp.quit
	else 
		if File.exist?(absolute_path) && (File.stat(absolute_path).directory?) then
			dir=Dir.new(absolute_path)
			dir.each do |f| 
				directories<<f if (f[0].chr!=".") && (File.stat(absolute_path+"/"+f).directory?)
				fsimage_files<<f if (FSImage.is_fsimage_file?(f))
			end
		end
	end
	[directories,fsimage_files]
end

def make_navigation_path(relative_path)
	path_parts=relative_path.split("/")
	#make the cookie-crumb-trail 
	partial_path=""
	s="<a href=/dir/>#{@@root_directory}</a>"
	path_parts.each do |p|
		if p.length>0 then
			partial_path+="/#{p}"			
			if FSImage.is_fsimage_file?(partial_path) then				
				s<<"/<a href=/catalog#{uri_encode(partial_path)}>#{p}</a>"
			else
				s<<"/<a href=/dir#{uri_encode(partial_path)}>#{p}</a>"
			end
		end
	end
	s
end

  def show_files_and_directories(relative_path)
	    
	s=""
	#show the contents of the current directory
	directories,fsimage_files=get_directories_and_files(relative_path)

	#list out the directories	
	s<<"<ul>"
	#s<<"<li>[dir] <a href=/#{uri_encode('/dir/'+File.dirname(relative_path))}>..</a>\n"
	directories.sort.each do |d|
		s<<"<li>[dir] <a href=/dir/#{uri_encode(relative_path)}/#{uri_encode(d)}>#{d}</a>\n"
	end
	
	#list out the image files		
	fsimage_files.sort.each do |f|		 
		s<<"<li>[fsimage] <a href=/catalog/#{uri_encode(relative_path)}/#{uri_encode(f)}>#{f}</a> [ <a href=#{uri_encode(@@root_directory+relative_path+'/'+f)}>download</a> ]\n"
	end
	s<<"</ul>"

	s
end
def make_catalog(relative_path)
	s="<p>"
	begin
		absolute_path=make_absolute_path(relative_path)
		fsimage=get_fsimage_from_cache(absolute_path)
		s<<"<br>file system: #{fsimage.file_system}<br>tracks: #{fsimage.track_count}<br>"
    s<<"sector order: #{fsimage.sector_order}<br>"if (fsimage.respond_to?(:sector_order))

		if (fsimage.respond_to?(:files)) then
			s<<"<table>\n<th>TYPE</th><th>SIZE (BYTES)</th><th>NAME</th></tr>\n"
			0.upto(fsimage.files.length-1) do |filenumber|
        f=fsimage.files[filenumber]
				display_url="/showfile/#{uri_encode(relative_path)}?filenumber=#{filenumber}"
				if f.respond_to?(:file_type) then 
					s<<"<td>#{f.file_type}</td>"
				else 
					s<<"<td></td>"
				end
				s<<"<td>#{sprintf('%03d',f.contents.length)}</td>"				
        s<<"<td>#{f.full_filename}</td>"
				s<<"<td><a href=#{display_url}&mode=hex>hex dump</a></td>"
				if f.can_be_picture? then
					s<<"<td><a href=#{display_url}&mode=png>picture</a></td>"
        elsif f.can_be_midi? then
					s<<"<td><a href=#{display_url}&mode=midi>midi</a></td>"
        elsif f.respond_to?(:can_be_basic?) && f.can_be_basic?
					s<<"<td><a href=#{display_url}&mode=text>list basic</a></td>"
				elsif f.respond_to?(:disassembly)
					s<<"<td><a href=#{display_url}&mode=list>disassembly</a></td>"
				else 					
					s<<"<td><a href=#{display_url}&mode=text>text</a></td>"
				end				
				s<<"</tr>\n"
			end
			s<<"</table>"
		else
			s<<"<i>not a recognised format</i>"
		end
		s<<"<p><a href=/showsector/#{uri_encode(relative_path)}>View Sectors</a>"
	rescue Exception => exception
		s<<"<i>ERROR:#{exception}</i>"
	end
	s
end
def show_sector(relative_path,track,sector)
		
		absolute_path=make_absolute_path(relative_path)
		fsimage=get_fsimage_from_cache(absolute_path)
    track=fsimage.start_track.to_s if track.nil?
		sector="0" if sector.nil?
		track=("0"+track).to_i
		sector=("0"+sector).to_i
    
		uri="/showsector/#{uri_encode(relative_path)}"
		s=""		
		s<<"<table><tr><th colspan=16>TRACK</th></tr>"
		s<<"<tr>"
		0.upto(fsimage.track_count-1) do |track_no|
 			if track_no==track then
				s<<"<td><b>$#{sprintf('%02X',track)}</b></td>"
			else
				s<<"<td><a href=#{uri}?track=#{track_no}&sector=0>$#{sprintf('%02X',track_no)}</a></td>"
			end
			if track_no>0 && track_no%0x10==0 then
				s<<"</tr></tr>"
			end
		end
		s<<"</tr>"
		s<<"</table>"
		s<<"<table><tr><th colspan=16>SECTOR</th></tr>"
		s<<"<tr>"
		0.upto(0x0F) do |sector_no|
 			if sector_no==sector then
				s<<"<td><b>$#{sprintf('%02X',sector)}</b></td>"
			else
				s<<"<td><a href=#{uri}?track=#{track}&sector=#{sector_no}>$#{sprintf('%02X',sector_no)}</a></td>"

			end
		end
		s<<"</tr>"
		s<<"</table>"
		s<<"<pre>\n"
		s<<html_escape(fsimage.dump_sector(track,sector))
		s<<"</pre>\n"
		s<<"<p>"
		s<<"<pre>\n"
		s<<html_escape(fsimage.disassemble_sector(track,sector))
		s<<"</pre>\n"		
end

def show_file(relative_path,filenumber,display_mode)
	absolute_path=make_absolute_path(relative_path)
	fsimage=get_fsimage_from_cache(absolute_path)
	file=fsimage.files[filenumber]
	if file.nil? then
		s="<i>file number #{filenumber} not found</i>"
	else 
    s="<p><b>#{file.full_filename}</b><pr>\n"
		s<<"<hl><pre>"
		if display_mode=="hex" then
			s<<html_escape(file.hex_dump)
    elsif display_mode=="list" && file.respond_to?(:disassembly) then
      s<<html_escape(file.disassembly)
		elsif display_mode=="midi" && file.respond_to?(:to_midi) then
			midi_url="/midi/#{uri_encode(relative_path)}?filename=#{uri_encode(filename)}"
			s<<"\n<embed src='#{midi_url}' 'autostart='true' autoplay='true' loop='true' >\n"
      s<<"\n<a href='#{midi_url}'>download midi</a>"
		elsif display_mode=="png" && file.respond_to?(:to_png) then
			png_url="/png/#{uri_encode(relative_path)}?filename=#{uri_encode(filename)}"
			s<<"<IMG SRC=#{png_url} HEIGHT=384 WIDTH=560>"
		else 
			s<<html_escape(file.to_s)
		end
		s<<"\n</pre><hl>"
	end
	s
end

class DirectoryServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=URI.unescape(req.path).sub(/^\/dir/,"")
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path)+show_files_and_directories(relative_path)+common_footer
	end
end

class CatalogServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=URI.unescape(req.path).sub(/^\/catalog/,"")
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path)+make_catalog(relative_path)+common_footer
	end
end

class ShowFileServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=URI.unescape(req.path).sub(/^\/showfile/,"")
		filenumber=URI.unescape(req.query['filenumber']).to_i
		display_mode=req.query['mode']
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path)+show_file(relative_path,filenumber,display_mode)+common_footer
	end
end

class ShowPNGServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=URI.unescape(req.path).sub(/^\/png/,"")
		filenumber=URI.unescape(req.query['filenumber']).to_i
		pallete_mode=req.query['pallete_mode']
		pallete_mode=:"#{pallete_mode}" unless pallete_mode.nil? #convert string to symbol
		absolute_path=make_absolute_path(relative_path)
		fsimage=get_fsimage_from_cache(absolute_path)
		file=fsimage.files[filenumber]
		res['Content-Type']="image/png"
		res.body=file.to_png(pallete_mode)
	end
end

class ShowMIDIServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=URI.unescape(req.path).sub(/^\/midi/,"")
		filenumber=URI.unescape(req.query['filenumber']).to_i
		absolute_path=make_absolute_path(relative_path)
		fsimage=get_fsimage_from_cache(absolute_path)
		file=fsimage.files[filenumber]
		res['Content-Type']="audio/midi"
		res.body=file.to_midi
	end
end

class ShowSectorServlet < HTTPServlet::AbstractServlet
	def do_GET(req,res)
		relative_path=URI.unescape(req.path).sub(/^\/showsector/,"")
		track=req.query['track']
		sector=req.query['sector']
		res['Content-Type']="text/html"
		res.body=common_header+make_navigation_path(relative_path)+show_sector(relative_path,track,sector)+common_footer
	end
end


s=HTTPServer.new(
	:Port=>@listening_port
)
trap("INT") {s.shutdown}

s.mount("/dir",DirectoryServlet)
s.mount("/catalog",CatalogServlet)
s.mount("/showfile",ShowFileServlet)
s.mount("/showsector",ShowSectorServlet)
s.mount("/png",ShowPNGServlet)
s.mount("/midi",ShowMIDIServlet)
#default page - for now, just redirect to the default dir page
s.mount("/",DirectoryServlet)

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
