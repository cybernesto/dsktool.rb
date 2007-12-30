ruby index.rb>index.html
ruby dskexplorer_web.rb --help >dskexplorer.html
pscp *.html jonnosan@rubyforge.org:/var/www/gforge-projects/dsktool
pscp -r ../doc jonnosan@rubyforge.org:/var/www/gforge-projects/dsktool


