@echo off

set ASAR=..\..\tools\asar.exe --fix-checksum=off
set BIP=..\..\tools\bip.exe
set CODE=..\..\code
set FLIPS=..\..\tools\flips.exe
set VANILLA=..\..\tools\SuperMetroid.sfc

echo.
echo Copying Vanilla ROM
copy ..\..\tools\SuperMetroid.sfc dash_SGL2020.sfc

echo.
echo Applying ASM
%ASAR% %CODE%\starter_charge\starter_charge.asm dash_SGL2020.sfc
%ASAR% %CODE%\gravity_heat\gravity_heat.asm dash_SGL2020.sfc

echo.
echo Creating IPS
%FLIPS% --create --ips %VANILLA% dash_SGL2020.sfc dash_SGL2020.ips