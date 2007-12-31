#!/usr/bin/env ruby

# dsktool.rb
#
# == Synopsis
#
# Manipulate DSK format files (as used by Apple 2 emulators)
#
# == Usage
#
# dsktool.rb [switches] <filename.dsk>
#  -a | --add FILENAME       (*) add file
#  -b | --base BASE          use BASE as address to load Binary File
#                            this will add 2 bytes to the start of file
#                            BASE should be a hex number 
#                            (can be prefixed with $, 0x, or nothing)
#  -B | --bootcode FILENAME  FILENAME gets written to track 0, sector 0
#                            FILENAME should be compiled to run at $0801
#                            FILENAME can be up to 4Kb in size.
#  -c | --catalog            display catalog
#  -d | --dump FILENAME      hex dump
#  -D | --diskdump           hex dump of entire disk
#  -L | --delete FILENAME    (*) delete named file
#  -e | --extract FILENAME   extract file by name (either to stdout, 
#                            or file specified by --output)
#  -h | --help               display this message
#  -I | --init FILESYSTEM    initialise the disk with the specified filesytem
#                            DSK will be created if it doesn't exist.
#                            FILESYSTEM can be : prodos,dos33,nadol,pascal,none
#  -l | --list FILENAME      monitor style listing (disassembles 65C02 opcodes)
#  -o | --output FILENAME    specify name to save extracted file as
#  -r | --raw                don't convert files to ASCII
#  -S | --showtrace          show full stack trace on any error
#  -t | --filetype FILETYPE  file type for file being added.
#                            Can be a single letter (A/I/B/T) or number.
#                            Default for DOS 3.3 is 0x00 (Text)
#  -T | --tokenise           (*) tokenise input file before adding
#  -v | --version            show version number
#  -x | --explode            extract all files 
#
#   (*) options marked with an asterisk are only available for
#       file systems that have READ/WRITE support.
#    
#	Currently supported filesystems:
#		Apple Pascal         (read only)
#		DOS 3.3              (READ/WRITE)
#		NADOL                (READ/WRITE)
#		ProDOS 8             (read only)
#
#	Supports 16 sector DSK images 
#	files with extension .gz will be read & written using gzip
#	input files can be URLs
#
# examples:
#	dsktool.rb -c http://jamtronix.com/dsks/apshai.dsk.gz
#	dsktool.rb --list fid -o fid.lst DOS3MASTR.dsk
#	dsktool.rb --extract "COLOR DEMOSOFT" DOS3MASTR.dsk
#	dsktool.rb -e HELLO -o HELLO.bas DOS3MASTR.dsk
#	dsktool.rb -x DOS3MASTR.dsk.gz -o /tmp/DOS3MASTR/
#	dsktool.rb --add STARTUP -T nadol.po
#	dsktool.rb --add c:\src\dosdemo\a.out -t B -b $2000 dosdemo.dsk
#	dsktool.rb --init dos33 new_dos_disk.dsk.gz
#	dsktool.rb --I none -B /tmp/a.out demo1.dsk


DSKTOOL_VERSION="0.4.2"

#make sure the relevant folder with our libraries is in the require path
lib_path=File.expand_path(File.dirname(__FILE__)+"//..//lib")
$:.unshift(lib_path) unless $:.include?(lib_path)
require 'rubygems'
require 'optparse'
require 'rdoc_patch' #RDoc::usage patched to work under gem executables

catalog=false
explode=false
diskdump=false
show_trace=false
add_filename=nil
output_filename=nil
extract_filename=nil
delete_filename=nil
add_file_options={}
init_filesystem=nil
boot_filename=nil

extract_mode=:default
explode_directory=nil
opts=OptionParser.new
opts.on("-h","--help") {RDoc::usage_from_file(__FILE__)}
opts.on("-v","--version") do
		puts File.basename($0)+" "+DSKTOOL_VERSION
	exit
end
opts.on("-r","--raw") {extract_mode=:raw}
opts.on("-c","--catalog") {catalog=true}
opts.on("-D","--diskdump") {diskdump=true}
opts.on("-x","--explode") {explode=true}
opts.on("-l","--list FILENAME",String) do |val| 
	extract_filename=val.upcase
	extract_mode=:list	
end

opts.on("-S","--showtrace") {show_trace=true}

opts.on("-d","--dump FILENAME",String) do |val| 
	extract_filename=val.upcase
	extract_mode=:hex
end
opts.on("-e","--extract FILENAME",String) {|val| extract_filename=val.upcase}
opts.on("-o","--output FILENAME",String) {|val| output_filename=val}
opts.on("-a","--add FILENAME",String) {|val| add_filename=val}
opts.on("-I","--init FILESYSTEM",String) {|val| init_filesystem=val}
opts.on("-B","--bootcode FILENAME",String) {|val| boot_filename=val}
opts.on("-t","--filetype FILETYPE",String) {|val| add_file_options[:filetype]=val}
opts.on("-T","--tokenise") {add_file_options[:tokenise]=true}
opts.on("-L","--delete FILENAME",String) {|val| delete_filename=val}
opts.on("-b","--base BASE",String) {|val| add_file_options[:base]=val}

filename=opts.parse(ARGV)[0] rescue RDoc::usage_from_file(__FILE__,'Usage')
RDoc::usage_from_file(__FILE__,'Usage') if (filename.nil?)

	
require 'DSK'

begin #to wrap a rescue clause

  begin
   
  if !init_filesystem.nil? then
    dsk=DSK.create_new(:"#{init_filesystem}")
    dsk.save_as(filename)
  end


  dsk=DSK.read(filename)
  rescue 
    #if we run dsktool.rb in a batch or shell file iterating over a bunch of dsk files, we may not know what file	
    #has the error
  STDERR << "error while parsing #{filename}\n"
  raise
  end

  output_file= case
    when (output_filename.nil?) || (explode) then STDOUT
    else File.open(output_filename,"wb")
  end

  if (dsk.respond_to?(:volume_name)) then    
    puts "volume name:\t#{dsk.volume_name}"
  end 
  if (diskdump) then
    puts dsk.hex_dump
  end

  if !boot_filename.nil? then
    dsk.set_boot_track(File.open(boot_filename,"rb").read)
    dsk.save_as(filename)
  end

  if (!delete_filename.nil?) then
    if dsk.files[delete_filename].nil? then
      puts "#{delete_filename.upcase} not found in #{filename}"
    else
      puts "deleting #{delete_filename}"
      dsk.delete_file(delete_filename)
      dsk.save_as(filename)
    end
  end

  if (!add_filename.nil?) then
    filecontents=File.open(add_filename,"rb").read
    new_file=dsk.make_file(File.basename(add_filename).upcase,filecontents,add_file_options)
    dsk.add_file(new_file)
    dsk.save_as(filename)
  end

  if(catalog) then	
    puts "#{filename}\nsector order:\t#{dsk.sector_order}\nfilesystem:\t#{dsk.file_system}"
  
    if (dsk.respond_to?(:dump_catalog)) then    
      puts dsk.dump_catalog
    else
      puts "#{filename} does not have a recognised file system"
    end
  end

  if(explode) then
    output_dir=output_filename.nil??File.basename(filename,".*"):output_filename
    if !(File.exists?(output_dir)) then
      Dir.mkdir(output_dir)	
    end
        
    dsk.files.each_value do |f|
      if (extract_mode==:raw) then
        output_filename=output_dir+"/"+f.filename+".raw"
        File.open(output_filename,"wb") <<f.contents
      else
        output_filename=output_dir+"/"+f.filename+f.file_extension
        File.open(output_filename,"wb") <<f
      end
    end
  end


  if (!extract_filename.nil?) then
    file=dsk.files[extract_filename]
    if file.nil? then
      puts "'#{extract_filename}' not found in #{filename}"
    else
      output_file<< case extract_mode
        when :raw then file.contents
        when :hex then file.hex_dump
        when :list then 	
          if file.respond_to?(:disassembly)
            file.disassembly
          else
            puts "'#{extract_filename}' is not a binary file"
            exit
          end
        else	file.to_s 
      end
    end
  end
rescue
  puts $!
  raise if show_trace
end
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
