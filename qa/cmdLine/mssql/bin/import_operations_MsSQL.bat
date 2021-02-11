set SRC=%~1
set SCHEMA_VERSION=%~2
set VER=%~3
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=Northwind%SCHEMA_VERSION%         FILE=%SRC%\Northwind%VER%.json        TO_USER=dbo             MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% 
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FILE=%SRC%\Sales%VER%.json            TO_USER=Sales           MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% 
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FILE=%SRC%\Person%VER%.json           TO_USER=Person          MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% 
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FILE=%SRC%\Production%VER%.json       TO_USER=Production      MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% 
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FILE=%SRC%\Purchasing%VER%.json       TO_USER=Purchasing      MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% 
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FILE=%SRC%\HumanResources%VER%.json   TO_USER=HumanResources  MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% 
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorksDW%SCHEMA_VERSION%  FILE=%SRC%\AdventureWorksDW%VER%.json TO_USER=dbo             MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG%