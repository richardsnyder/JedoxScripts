@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

SET JAVACMD="java.exe"
IF NOT EXIST "%JAVA_HOME%\bin\java.exe" goto setlib
SET JAVACMD="%JAVA_HOME%\bin\java.exe"

:setlib
IF EXIST "..\lib" SET LIB="..\lib"
IF EXIST "lib" SET LIB="lib"
for %%i in (%0) do cd /d %%~dpi
set JCP=
for %%i in (%LIB%\*.jar) do set JCP=!JCP!;%%i

%JAVACMD% -Xmx1024m -cp %JCP% com.jedox.etl.client.RemoteClient %*
:end