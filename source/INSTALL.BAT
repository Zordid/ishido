@echo off
if "%1"=="" goto error
if "%2"=="" goto error
if not exist %1nul goto error
echo ISHIDO für Windows Installation
echo ===============================
echo.
echo Wollen Sie Ishido wirklich auf Laufwerk %1 im Verzeichnis 
echo %2 installieren ?
echo Wenn nicht, dann brechen Sie jetzt mit Ctrl-C ab !
pause
echo.
if exist %2\nul goto ok1
echo Verzeichnis %2 existiert nicht !
echo Wenn Sie nicht abbrechen, wird es jetzt eingerichtet !
pause
echo.
md %2
:ok1
echo Kopiere INSTALL.DAT nach %2\INSTALL.DAT...
echo.
copy install.dat %2
if exist %2\INSTALL.DAT goto ok2
echo Fehler beim Kopieren !
goto ende
:ok2
%1
cd %2
ren install.dat install.exe
install -e -y
if exist ishido.exe goto ok3
echo Fehler beim Entpacken !
goto ende
:ok3
del install.exe
echo Alles klar !
echo Sie müssen Ishido nur noch in einer Programmgruppe des Programm-
echo Managers unterbringen !
goto ende
:error
echo Syntax: INSTALL [Laufwerk:] [Laufwerk:\Verzeichnis]
echo Zum Beispiel:
echo    INSTALL C: C:\GAMES\ISHIDO
:ende 
