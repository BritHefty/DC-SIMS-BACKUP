::SIMS Automated backup 3.0
::Purpose to create all necessary backup files 
::		- Daily full backup
::		- Daily Emergency Backup
::		- Weekly History Backup on Mondays.
::--Also Copies files to the three seperate locations necessary for 
::  confidence in backup solution
::--Copies EMG backup to SIMS-Server for distribution.
::--Moving to RC
::
::-------------------------------------------------------------------------------
::                                 NOTES
::-------------------------------------------------------------------------------
:: 12/24/2013 - Finalized to a working script, does Monday History backups
::            - Added Documentation to steps to define what is being done in each
::              section.
:: 08/22/2016 - Synching with GITHub need to update auth strings before using

:TO-DO 
::Not mess this up.

:BEGIN 
	@ECHO off
	SETLOCAL

:TimeDate 
::Properly pull time and date for backup file names adjust time to 24 hour time.
	FOR /f "tokens=2-4 delims=/ " %%a IN ('DATE /T') DO (
	SET _mon=%%a
	SET _day=%%b
	SET _year=%%c
	)
	FOR /f "tokens=1-3 delims=: " %%a IN ('TIME /t') DO (
	SET _hour=%%a
	SET _min=%%b
	SET _ampm=%%c
	)
	IF [%_ampm%]==[PM] (
		IF NOT [%_hour%]==[12] SET /a _HOUR=%_hour%+12
		)
	SET _fname_bu=SIMS-%_year%%_mon%%_day%-%_hour%%_min%.zip
	SET _fname_emg=EMG-%_year%%_mon%%_day%-%_hour%%_min%.zip
	SET _fname_log=\\dcfs\working\files\logs\backups\%_year%\%_mon%.csv
	FOR /f %%a IN ('wmic PATH win32_localtime get dayofweek /format:list ^| findstr "="') DO (SET %%a)
	SET _fname_his=MON-%_year%%_mon%%_day%.zip
	
	SET _zip=\\dcfs\working\tools\7za.exe
	SET _source=\\192.168.2.151\data\simsii
	
:TMPDIR 
::remove temp directory if it currently exists.  Any existing files will be removed
::these files should have been copied out of this folder when this script was previously run
	SET _tmp_dir=C:\SIMS-BU-TMP
	IF EXIST %_tmp_dir% (
		RD /S /Q %_tmp_dir%
		)
::Re-Creating the temp directory and setting the environment variable.
	MKDIR %_tmp_dir%


:NetAuth 
::Authorizing to required network resources 
::Using IP address' to prevent conflicts with existing connections.
	NET USE \\192.168.2.151\ipc$ /user:
	NET USE \\192.168.2.11\ipc$ /user:
	NET USE \\192.168.2.58\ipc$ /user:

:Logging1 
::Checking if the directory of the log file exists, if not creating it.
	IF NOT EXIST \\dcfs\working\files\logs\backups\%_year% (
		MKDIR \\dcfs\working\files\logs\backups\%_year%
		)
::Checking if the log file exists, if not establishes the header row for a csv file creating the log file
::This method insures that the log file is created in the correct format to open the csv in editors
	IF NOT EXIST %_fname_log% (
		ECHO.DATE^,TIME^,PC^,DBU^,EBU^,HIS>%_fname_log%
		)
::Start the log entry variable which will be written to the log file at the end of the script.
	SET _log_entry=%_mon%^/%_day%^/%_year%^,%_hour%^:%_min%^,%computername%

:Daily_BU 
::Creates a daily backup full database
	%_zip% a -tzip -x!%_source%\REC-LOCK.DAT -x!%_source%\TRAFFIC.DAT %_tmp_dir%\%_fname_bu% %_source%\*.dat %_source%\*.map %_source%\*.win %_source%\*.srt %_source%\*.ix1 %_source%\sims.* %_source%\events.* %_source%\english.*
	SET _log_entry=%_log_entry%^,%errorlevel%

:EMG_BU 
::Creates an emergency database backup that gets distributed to each workstation.
	%_zip% a -tzip -x!%_source%\TRF-*.DAT -x!%_source%\REC-LOCK.DAT -x!%_source%\??-??-??.his -x!%_source%\??-??-??.idx %_tmp_dir%\%_fname_emg% %_source%\*.dat %_source%\*.idx %_source%\*.map %_source%\*.ix1 %_source%\*.win %_source%\*.srt %_source%\english.* %_source%\events.*
	SET _log_entry=%_log_entry%^,%errorlevel%

:HIST_BU 
::Creates a history backup of only the previous weeks history only if run on a monday
::Checking day of week from the WMI command in TimeDate section
	IF NOT [%dayofweek%]==[1] GOTO COPY_BU
::Calls another script to figure out what the previous date is
	CALL \\dcfs\working\scripts\get-prev-day.bat 1
::Variable _prev_date populated by get-prev-day.bat to properly handle which filenames to look for in the working directory.
	%_zip% a -tzip %_tmp_dir%\%_fname_hist% %_source%\%_prev_date%.HIS %_source%\%_prev_date%.IDX
	SET _log_entry=%_log_entry%^,%errorlevel%

:COPY_BU 
::To SIMS USB HD
	IF EXIST \\192.168.2.11\F$ (
		COPY %_tmp_dir%\%_fname_bu% "\\192.168.2.11\f$\simszip\%_fname_bu%"
		COPY %_tmp_dir%\%_fname_emg% "\\192.168.2.11\f$\simsemergency backups\%_fname_emg%"
		IF EXIST %_tmp_dir%\%_fname_his% COPY %_tmp_dir%\%_fname_his% "\\192.168.2.11\f$\simshistory\%_fname_his%"
		)
::To SIMS Removable (UL offsite backup)
	IF EXIST \\192.168.2.11\P$ (
		COPY %_tmp_dir%\%_fname_bu% "\\192.168.2.11\P$\simszip\%_fname_bu%"
		COPY %_tmp_dir%\%_fname_emg% "\\192.168.2.11\P$\simsemerg\%_fname_emg%"
		IF EXIST %_tmp_dir%\%_fname_his% COPY %_tmp_dir%\%_fname_his% "\\192.168.2.11\p$\simshistory\%_fname_his%
		)
::To FW-CS
	COPY %_tmp_dir%\%_fname_bu% "\\192.168.2.58\E$\SIMS\simszip\%_fname_bu%"
	COPY %_tmp_dir%\%_fname_emg% "\\192.168.2.58\E$\SIMS\simsemerg\%_fname_emg%"
	IF EXIST %_tmp_dir%\%_fname_his% COPY %_tmp_dir%\%_fname_his% "\\192.168.2.58\E$\sims\simshistory\%_fname_his%
	
::To \\SIMS-Server\data\simsii\simsemg\
	COPY %_tmp_dir%\%_fname_emg% "\\192.168.2.151\data\simsii\simsemg\%_fname_emg%"

:Deploy_EMG_BU 
::Calling emergency backup restore. to deploy the emergency backup to the workstations that need it.
	CALL \\dcfs\working\scripts\wsauth.bat
	\\dcfs\working\tools\psexec @\\dcfs\working\files\wslist.txt \\dcfs\working\scripts\emgrestore.bat %_fname_emg%
	CALL \\dcfs\working\scripts\wsauth.bat deauth

:Logging2 
::Writes log entry in csv format to the log file
	ECHO.%_log_entry% >>%_fname_log%
	
:Cleanup 
::Removes the temp directory and all files within
	RD /S /Q %_tmp_dir%
::Deletes the emg backup file from the temporary storage on sims-server
	DEL /Q "%_source%\simsemg\%_fname_emg%"
::Terminates network connections as they are no longer needed.
	NET USE \\192.168.2.151\ipc$ /delete
	NET USE \\192.168.2.11\ipc$ /delete
	NET USE \\192.168.2.58\ipc$ /delete
	ENDLOCAL