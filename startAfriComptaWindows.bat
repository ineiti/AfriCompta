rem To start AfriCompta

set DB=sam
set PATH=%PATH%;Windows
del sqlite3-ruby-1.2.5\lib\sqlite3_api.so
copy Windows\reloader.rb camping-1.5\lib\camping
md Backup
md Log

for /f "delims=" %%a in ('wmic OS Get localdatetime  ^| find "."') do set "dt=%%a"
set "YYYY=%dt:~0,4%"
set "MM=%dt:~4,2%"
set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%"
set "Min=%dt:~10,2%"
set "Sec=%dt:~12,2%"
set T=%YYYY%-%MM%-%DD%_%HH%.%Min%.%Sec%
set LOG=Log\ac-%T%.log

Windows\7z a Backup\%DB%-%T%.zip db.%DB%

START /B CMD /C CALL ruby -Icamping-1.5/lib -Iactiverecord-2.3.5/lib -Iactivesupport-2.3.5/lib -Imarkaby-0.5/lib -Isqlite3-1.3.9/lib camping --database db.%DB% compta.rb > %LOG% 2>&1
ping -n 5 localhost
if EXIST FirefoxPortable\ GOTO FF
start http://localhost:3301
GOTO END
:FF
FirefoxPortable\FirefoxPortable.exe http://localhost:3301
:END
