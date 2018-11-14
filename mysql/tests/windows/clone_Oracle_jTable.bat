@set TNS=%~1
@set DIR=JSON\\%TNS%
@set MODE=DATA_ONLY
@set MDIR=..\\..\\JSON\\%TNS%\\%MODE%
@set ID=1
mkdir %DIR%
call env\connection.bat
mysql -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f <..\sql\JSON_IMPORT.sql >>%TESTSQL%\JSON_IMPORT.log
mysql -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f --init-command="SET @ID=%ID%" <sql\RECREATE_ORACLE_ALL.sql >> %TESTLOG%\RECREATE_SCHEMA.log
call windows\import_Oracle_jTable.bat %MDIR% %ID% ""
call windows\export_Oracle.bat %DIR% %ID% %ID%
@set ID=2
mysql -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f --init-command="SET @ID=%ID%" <sql\RECREATE_ORACLE_ALL.sql >> %TESTLOG%\RECREATE_SCHEMA.log
call windows\import_Oracle_jTable.bat %DIR% %ID% 1
call windows\export_Oracle.bat %DIR% %ID% %ID%
node ..\..\utilities\compareFileSizes %LOGFILE% %MDIR% %DIR%
node ..\..\utilities\compareArrayContent %LOGFILE% %MDIR% %DIR% false