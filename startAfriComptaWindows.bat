rem To start AfriCompta

set DB=test
set PATH=%PATH%;Windows
del sqlite3-ruby-1.2.5\lib\sqlite3_api.so
copy Windows\reloader.rb camping-1.5\lib\camping
md Backup
md Log

set D=%date:/=.%
set T1=%time: =0%
set T2=%T1::=_%
set T=%D%-%T2:~0,8%
set LOG=Log\ac-%T%.log

Windows\7z a Backup\%DB%-%T%.zip db.%DB%

START /B CMD /C CALL ruby -Icamping-1.5/lib -Iactiverecord-2.3.5/lib -Iactivesupport-2.3.5/lib -Imarkaby-0.5/lib -Isqlite3-ruby-1.2.5/lib camping --database db.%DB% compta.rb > %LOG% 2>&1
ping -n 5 localhost
start http://localhost:3301
