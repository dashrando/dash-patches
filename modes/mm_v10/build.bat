@echo off

set ASAR=..\..\tools\asar.exe --fix-checksum=off
set BIP=..\..\tools\bip.exe
set CODE=..\..\code
set FLIPS=..\..\tools\flips.exe
set VANILLA=..\..\tools\SuperMetroid.sfc

echo.
echo Copying Vanilla ROM
copy ..\..\tools\SuperMetroid.sfc dash_v10.sfc

echo.
echo Applying ASM
%ASAR% %CODE%\starter_charge\starter_charge.asm dash_v10.sfc
%ASAR% %CODE%\gravity_heat\gravity_heat.asm dash_v10.sfc
%ASAR% %CODE%\suit_damage\suit_damage.asm dash_v10.sfc
%ASAR% %CODE%\special_blocks\special_blocks.asm dash_v10.sfc

echo.
echo Adding Special Blocks
%BIP% -n %VANILLA% %CODE%\special_blocks\add_special_blocks.ips dash_v10.sfc

echo.
echo Creating IPS
%FLIPS% --create --ips %VANILLA% dash_v10.sfc dash_v10.ips