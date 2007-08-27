# first the header
puts <<FIRST_BIT
<h2><a href=http://dsktool.rubyforge.org/>dsktool.rb</a></h2>
dsktool.rb is a command line tool + libraries (all in ruby) for manipulating DSK format images used by Apple 2 emulators. 
Currently only DOS 3.3 and NADOL filesystems are supported. 
<p>
As of version 0.1.6, the dsktool package also includes <a href=dskexplorer.html>dskexplorer.rb</a>,
a browser based DSK archive exploring tool that can explore both local disk and remote web archives.
<pre>
FIRST_BIT
#now the usage
puts `ruby ..\\dsktool\\bin\\dsktool.rb -v`
puts `ruby ..\\dsktool\\bin\\dsktool.rb`

#now the last bit
puts <<LAST_BIT
</pre>
<ul>
<li><a href=http://dsktool.rubyforge.org/doc>RDoc Documentation</a>
<li><a href=http://rubyforge.org/pm/task.php?group_id=3844&group_project_id=6130>Task List</a>
<li><a href=http://rubyforge.org/projects/dsktool>RubyForge project page</a>
<li><a href=http://rubyforge.org/frs/?group_id=3844>Download</a>
</ul>
Jonno Downes - jonno at <a href=http://www.jamtronix.com/>jamtronix.com</a>
LAST_BIT
puts "<br><i>#{Time.now}</i>"