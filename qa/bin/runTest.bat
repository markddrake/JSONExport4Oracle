# Run from YADAMU_HOME
@set YADAMU_TASK=%1
@set YADAMU_HOME=%CD%
@set YADAMU_QA_HOME=%YADAMU_HOME%\qa
@set "YADAMU_LOG_PATH="
set YADAMU_LOG_ROOT=%YADAMU_HOME%\log
call %YADAMU_QA_HOME%\bin\initializeLogging.bat %YADAMU_TASK%
if not defined NODE_NO_WARNINGS set NODE_NO_WARNINGS=1
#if exist  %YADAMU_HOME%\log\%YADAMU_TASK%.log rmdir /s /q %YADMAU_OUTPUT_FOLDER%\JSON
node %YADAMU_HOME%\app\YADAMU_QA\common\node\test.js CONFIG=%YADAMU_QA_HOME%\regression\%YADAMU_TASK%.json EXCEPTION_FOLDER=%YADAMU_LOG_PATH% 2>&1 >%YADAMU_LOG_PATH%\%YADAMU_TASK%.log

