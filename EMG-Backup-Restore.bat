@echo off
setlocal
:: 2013-11-05 - Added IEtabupdate to emergency restore
:: 2016-08-22 - Syncing with GIT Hub, need to update authorization strings before using
echo.What is the name of the backup you want to restore^?
set /p _FN=
NET USE \\dcfs\ipc$ /user:
call \\dcfs\working\scripts\wsauth.bat
\\dcfs\working\tools\psexec @c:\wslist.txt \\dcinas\working\scripts\emgrestore.bat %_FN%
call \\dcfs\working\scripts\wsauth.bat deauth
call \\dcfs\working\scripts\ietabupdate.bat 02
endlocal