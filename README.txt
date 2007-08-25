dsktool.rb is a command line tool + libraries (all in ruby) for manipulating DSK format images 
used by Apple 2 emulators. Currently only DOS 3.3 and NADOL file systems are supported. 


PLATFORM SPECIFIC NOTES
-----------------------

UBUNTU:
	The default 'apt-get' based installation of rubygems does not add the gems 'bin' directory to the search path.
	in order to be able to run 'dsktool.rb', you will need to add this path by hand.

	to do this, open up ~/.bashrc, and at the bottom of the file add
	
	export PATH=$PATH:/var/lib/gems/1.8/bin

	Then save .bashrc, and restart your terminal window.




Author: Jonno Downes (jonno@jamtronix.com)
