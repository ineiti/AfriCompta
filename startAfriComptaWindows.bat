rem To start AfriCompta

set DB=sam
set PATH=%PATH%;Windows
del sqlite3-ruby-1.2.5\lib\sqlite3_api.so
copy Windows\reloader.rb camping-1.5\lib\camping

START /B CMD /C CALL ruby -Icamping-1.5/lib -Iactiverecord-2.3.5/lib -Iactivesupport-2.3.5/lib -Imarkaby-0.5/lib -Isqlite3-ruby-1.2.5/lib camping --database db.%DB% compta.rb
ping -n 5 localhost
start http://localhost:3301
