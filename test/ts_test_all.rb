$:.unshift(File.dirname(__FILE__)) unless
	$:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'tc_dos_disks'
require 'tc_disassembly'
require 'tc_nadol_disks'
