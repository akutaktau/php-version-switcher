@echo off
setlocal enabledelayedexpansion

:: Define base paths for PHP installations and Apache configuration
set "PHP_BASE_PATH=C:/Dev/php"
set "APACHE_CONF=C:\Dev\Apache24\conf\httpd.conf"
set "APACHE_BIN=C:\Dev\Apache24\bin\httpd.exe"

:: Define supported PHP versions
set "PHP_VERSIONS=7.4 8.0 8.1 8.2 8.3"

:: Ensure a PHP version is provided as an argument
if "%1"=="" (
    echo Please specify a PHP version to switch to, e.g., switchphp 8.3.
    goto :end
)

:: Validate the provided PHP version
set "TARGET_PHP_VERSION="
for %%v in (%PHP_VERSIONS%) do (
    if "%%v"=="%1" set "TARGET_PHP_VERSION=%%v"
)

:: If the provided version is invalid, display an error message and exit
if "%TARGET_PHP_VERSION%"=="" (
    echo Invalid PHP version specified. Available versions are: %PHP_VERSIONS%.
    goto :end
)

:: Set the PHP path based on the selected version
set "PHP_PATH=%PHP_BASE_PATH%/php%TARGET_PHP_VERSION%"

:: Determine the correct SAPI filename and module name based on the PHP version
set "SAPI_DLL="
set "MODULE_NAME="
if "%TARGET_PHP_VERSION:~0,1%"=="7" (
    set "SAPI_DLL=php7apache2_4.dll"
    set "MODULE_NAME=php7_module"
) else if "%TARGET_PHP_VERSION:~0,1%"=="8" (
    set "SAPI_DLL=php8apache2_4.dll"
    set "MODULE_NAME=php_module"
)

:: Verify if the SAPI DLL file exists in the specified PHP path
if not exist "%PHP_PATH%\%SAPI_DLL%" (
    echo The file %PHP_PATH%\%SAPI_DLL% does not exist. Please check your PHP installation.
    goto :end
)

:: Update the system PATH for CLI (current session)
echo Updating PATH for CLI...
set "PATH=%PHP_PATH%;%PATH%"
setx PATH "%PHP_PATH%;%PATH%" /M
if errorlevel 1 (
    echo Failed to update system PATH. Ensure you have administrative privileges.
    goto :end
)

:: Update the Apache configuration to use the specified PHP version
echo Updating Apache configuration...
call :update_apache_php "%PHP_PATH%" "%SAPI_DLL%" "%MODULE_NAME%"

:: Validate the updated Apache configuration
echo Validating Apache configuration...
"%APACHE_BIN%" -t
if errorlevel 1 (
    echo Apache configuration is invalid. Please check the configuration file for errors.
    goto :end
)

:: Restart Apache to apply the new configuration
echo Restarting Apache...
net stop Apache2.4 >nul
net start Apache2.4 >nul
if errorlevel 1 (
    echo Failed to restart Apache. Please check the error log for details.
    goto :end
)

:: Display success message
echo Successfully switched to PHP %TARGET_PHP_VERSION%.
php -v
goto :end

:: Function to update the Apache configuration file
:update_apache_php
setlocal
set "PHP_PATH=%~1"
set "SAPI_DLL=%~2"
set "MODULE_NAME=%~3"
set "TEMP_CONF=%APACHE_CONF%.tmp"
set "PHP_MODULE_LINE=LoadModule %MODULE_NAME% %PHP_PATH%/%SAPI_DLL%"
set "PHP_INIDIR_LINE=PHPIniDir %PHP_PATH%/"
set "ADDHANDLER_LINE=AddHandler application/x-httpd-php .php"

echo Updating Apache configuration with:
echo PHP_PATH: %PHP_PATH%
echo SAPI_DLL: %SAPI_DLL%
echo MODULE_NAME: %MODULE_NAME%
echo TEMP_CONF: %TEMP_CONF%
echo PHP_MODULE_LINE: %PHP_MODULE_LINE%
echo PHP_INIDIR_LINE: %PHP_INIDIR_LINE%
echo ADDHANDLER_LINE: %ADDHANDLER_LINE%

:: Create a temporary Apache configuration file by modifying necessary lines
echo Creating temporary Apache configuration file...
(for /f "tokens=*" %%a in (%APACHE_CONF%) do (
    set "line=%%a"
    if "!line:LoadModule php_module=!"=="!line!" (
        if "!line:LoadModule php7_module=!"=="!line!" (
            if "!line:PHPIniDir=!"=="!line!" (
                echo !line!>>"%TEMP_CONF%"
            )
        )
    )
)) > nul

:: Add the new PHP module line
echo %PHP_MODULE_LINE% >>"%TEMP_CONF%"
echo %PHP_INIDIR_LINE% >>"%TEMP_CONF%"

:: Check if AddHandler line is present
findstr /i /c:"%ADDHANDLER_LINE%" %APACHE_CONF% >nul
if errorlevel 1 (
    echo Adding AddHandler line to Apache configuration file...
    echo %ADDHANDLER_LINE% >>"%TEMP_CONF%"
)

:: Replace the original Apache configuration with the updated one
echo Replacing original Apache configuration with the updated one...
move /y "%TEMP_CONF%" "%APACHE_CONF%" >nul
if errorlevel 1 (
    echo Failed to replace the Apache configuration file.
    goto :endlocal
)

echo Apache configuration updated successfully.
endlocal
goto :eof

:end
endlocal