del dsktool-*.gem
call gem uninstall dsktool
REM call rdoc -d
call rdoc
ruby dsktool.gemspec