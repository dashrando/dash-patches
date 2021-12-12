@echo off

set ASAR=..\..\tools\asar.exe --fix-checksum=off
set BIP=..\..\tools\bip.exe
set CODE=..\..\code
set FLIPS=..\..\tools\flips.exe
set VANILLA=..\..\tools\SuperMetroid.sfc

echo.
echo Copying Vanilla ROM
copy ..\..\tools\SuperMetroid.sfc dash-credits.sfc

echo.
echo Applying ASM
%ASAR% credits.asm dash-credits.sfc
@REM %ASAR% test_credits.asm dash-credits.sfc

echo.
echo Creating IPS
%FLIPS% --create --ips %VANILLA% dash-credits.sfc dash-credits.ips