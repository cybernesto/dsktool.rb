# first the header
puts <<FIRST_BIT
dskexplorer.rb is a browser based DSK archive exploring tool. It can 
explore both local disk and remote web archives. It is
part of the <a href=http://dsktool.rubyforge.org/>dsktool.rb</a> 
package.
You will need to have <a 
href=http://www.ruby-lang.org/en/downloads/>ruby</a> installed.
<p> To install dskexplorer.rb, you just need to install the dsktool.rb 
rubygem. Depending on your OS, that is done by typing either
 <i>gem install dsktool</i> or  <i>sudo gem install dsktool</i> at a 
command prompt.
<p>
To use, run dskexplorer.rb and specify the location of the archive to 
explore using the '-r' switch. 
<br>For example <i>dskexplorer.rb -r 
http://www.apple2.org.za/mirrors/</i>
<br>Then open a browser, and navigate to <a 
href=http://localhost:6502/>http://localhost:6502/</a>
<p>
<a href="http://www.flickr.com/photos/jonnosan/606885843/"><img 
src="http://farm2.static.flickr.com/1339/606885843_071a45a845_o.png" 
width="491" height="393"/></a>
<p>
<a href="http://www.flickr.com/photos/jonnosan/607043704/" ><img 
src="http://farm2.static.flickr.com/1062/607043704_66da1f862a_o.png" 
width="572" height="415" /></a>
<p>
<a href="http://www.flickr.com/photos/jonnosan/606885613/"><img 
src="http://farm2.static.flickr.com/1026/606885613_0d1f30b620_o.png" 
width="640" height="455"/></a>
<p>
<pre>
FIRST_BIT

#now the usage
puts `ruby ../bin/dskexplorer.rb -h`

#now the last bit
puts <<LAST_BIT
</pre>
Jonno Downes - jonno at <a 
href=http://www.jamtronix.com/>jamtronix.com</a>
LAST_BIT
puts "<br><i>#{Time.now}</i>"
