Notes:
dsktool.rb is a ruby commandline tool + library for working with DSK files (as used with Apple ][ emulators).

This release adds CP/M file system support - the full list of file systems supported is:
CP/M (read/write)
DOS 3.3 (read/write)
NADOL (read/write)
ProDOS (read only)
Pascal (read only)

In addition, the following file formats are interpreted:
AppleSoft BASIC (converted to ASCII text)
BIN files can be disassembled
AWP (AppleWorks Word Processor) (converted to ASCII text)
Integer BASIC (converted to ASCII text)
HIRES Graphics (converted to PNG)
MBASIC/GBASIC (converted to ASCII text)
NADOL (converted to ASCII text)
S-C Assembler (converted to ASCII text)

The package also comes with 'dskexplorer.rb' which is a browser based tool for exploring either local or remote dsk collections

PLATFORM SPECIFIC NOTES
-----------------------

UBUNTU:
	The default 'apt-get' based installation of rubygems does not add the gems 'bin' directory to the search path.
	in order to be able to run 'dsktool.rb', you will need to add this path by hand.

	to do this, open up ~/.bashrc, and at the bottom of the file add
	
	export PATH=$PATH:/var/lib/gems/1.8/bin

	Then save .bashrc, and restart your terminal window.




Author: Jonno Downes (jonno@jamtronix.com)
