cd \winvox\fontes
call comp ediponte
cd \winvox\fontes
call comp pontevox
cd \winvox\fontes
call apague ediponte
call apague pontevox
cd \winvox
copy fontes\ediponte\psftp.exe c:\winvox
zip ediponte.zip ediponte.exe pontevox.exe psftp.exe fontes\pontevox\*.* fontes\ediponte\*.* som\pontevox\*.* som\ediponte\*.* manual\ediponte.txt pontevox.atu
cd \winvox\fontes\ediponte
