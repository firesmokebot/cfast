@echo off
set reduced=%1
if [%reduced%] == [] (
  set reduced=0
)

:: -------------------------------------------------------------
::                         set environment
:: -------------------------------------------------------------

set size=64
set compile_platform=intel64

:: set number of OpenMP threads

set OMP_NUM_THREADS=1

:: -------------------------------------------------------------
::                         set repository names
:: -------------------------------------------------------------

set fdsbasename=fds
set cfastbasename=cfast

:: -------------------------------------------------------------
::                         setup environment
:: -------------------------------------------------------------

set CURDIR=%CD%

if not exist output mkdir output

set OUTDIR=%CURDIR%\output

erase %OUTDIR%\*.txt 1> Nul 2>&1

set svnroot=%userprofile%\%cfastbasename%
set FDSroot=%userprofile%\%fdsbasename%

set errorlog=%OUTDIR%\stage_errors.txt
set warninglog=%OUTDIR%\stage_warnings.txt
set errorwarninglog=%OUTDIR%\stage_errorswarnings.txt
set infofile=%OUTDIR%\stage_info.txt
set revisionfile=%OUTDIR%\revision.txt
set stagestatus=%OUTDIR%\stage_status.log

set fromsummarydir=%svnroot%Docs\CFAST_Summary
set tosummarydir="%SMOKEBOT_SUMMARY_DIR%"

set haveerrors=0
set havewarnings=0
set haveCC=1

set gettimeexe=%FDSroot%\Utilities\get_time\intel_win_64\get_time.exe
set runbatchexe=%FDSroot%\SMV\source\runbatch\intel_win_64\runbatch.exe

date /t > %OUTDIR%\starttime.txt
set /p startdate=<%OUTDIR%\starttime.txt
time /t > %OUTDIR%\starttime.txt
set /p starttime=<%OUTDIR%\starttime.txt

call "%FDSroot%\Utilities\Scripts\setup_intel_compilers.bat" 1> Nul 2>&1

:: -------------------------------------------------------------
::                           stage 0
:: -------------------------------------------------------------

echo Stage 0 - Preliminaries

:: check if compilers are present

echo. > %errorlog%
echo. > %warninglog%
echo. > %stagestatus%

call :is_file_installed %gettimeexe%|| exit /b 1
echo             found get_time

call :GET_TIME
set TIME_beg=%current_time%

call :GET_TIME
set PRELIM_beg=%current_time% 


ifort 1> %OUTDIR%\stage0a.txt 2>&1
type %OUTDIR%\stage0a.txt | find /i /c "not recognized" > %OUTDIR%\stage_count0a.txt
set /p nothaveFORTRAN=<%OUTDIR%\stage_count0a.txt
if %nothaveFORTRAN% == 1 (
  echo "***Fatal error: Fortran compiler not present"
  echo "***Fatal error: Fortran compiler not present" > %errorlog%
  echo "cfastbot run aborted"
  call :output_abort_message
  exit /b 1
)
echo             found Fortran

call :is_file_installed pdflatex|| exit /b 1
echo             found pdflatex

call :is_file_installed grep|| exit /b 1
echo             found grep

:: update cfast repository

echo             updating cfast repository
cd %svnroot%
svn update  1> %OUTDIR%\stage0.txt 2>&1

call :GET_TIME
set PRELIM_end=%current_time%
call :GET_DURATION PRELIM %PRELIM_beg% %PRELIM_end%
set DIFF_PRELIM=%duration%

:: -------------------------------------------------------------
::                           stage 1
:: -------------------------------------------------------------

call :GET_TIME
set BUILDFDS_beg=%current_time% 
echo Stage 1 - Building CFAST
if %reduced% == 1 goto skip_cfast_debug

echo             debug

cd %svnroot%\CFAST\intel_win_%size%_db
erase *.obj *.mod *.exe *.pdb *.optrpt 1> %OUTDIR%\stage1a.txt 2>&1
make VPATH="../Source:../Include" INCLUDE="../Include" -f ..\makefile intel_win_%size%_db 1>> %OUTDIR%\stage1a.txt 2>&1


call :does_file_exist cfast6_win_%size%_db.exe %OUTDIR%\stage1a.txt|| exit /b 1

call :find_cfast_warnings "warning" %OUTDIR%\stage1a.txt "Stage 1a"

:skip_cfast_debug

echo             release

cd %svnroot%\CFAST\intel_win_%size%
erase *.obj *.mod *.exe *.pdb *.optrpt 1> %OUTDIR%\stage1b.txt 2>&1
make VPATH="../Source:../Include" INCLUDE="../Include"  -f ..\makefile intel_win_%size% 1>> %OUTDIR%\stage1b.txt 2>&1

call :does_file_exist cfast6_win_%size%.exe %OUTDIR%\stage1b.txt|| exit /b 1
call :find_cfast_warnings "warning" %OUTDIR%\stage1b.txt "Stage 1b"

call :GET_TIME
set BUILDFDS_end=%current_time%
call :GET_DURATION BUILDFDS %BUILDFDS_beg% %BUILDFDS_end%
set DIFF_BUILDFDS=%duration%


:: -------------------------------------------------------------
::                           stage 2
:: -------------------------------------------------------------


:: -------------------------------------------------------------
::                           stage 3
:: -------------------------------------------------------------


:: -------------------------------------------------------------
::                           stage 4
:: -------------------------------------------------------------

call :GET_TIME
set RUNVV_beg=%current_time% 


if %reduced% == 1 goto skip_cfast_debug_vv

echo Stage 4 - Running validation cases
echo             debug mode

cd %svnroot%\Validation\scripts
set SCRIPT_DIR=%CD%
set SH2BAT="%SCRIPT_DIR%\sh2bat.exe"

cd %CD%\..
set BASEDIR=%CD%
set BACKGROUNDDIR=%SVNROOT%\Validation\scripts\
cd "%BACKGROUNDDIR%"
set BACKGROUNDEXE="%CD%"\background.exe
set bg=%BACKGROUNDEXE% -u 85 -d 1

cd %SVNROOT%\CFAST\intel_win_%size%
set CFASTEXE=%CD%\cfast6_win_64_%size%

cd "%SCRIPT_DIR%"

set CFAST=%bg% %CFASTEXE%
set RUNCFAST=call "%SVNROOT%\Validation\scripts\runcfast_win32.bat"
set RUNCFAST2=call "%SVNROOT%\Validation\scripts\runcfast2_win32.bat"


echo creating CFAST case list from CFAST_Cases.sh
%SH2BAT% CFAST_Cases.sh CFAST_Cases.bat > %OUTDIR%\stage4a.txt 2>&1

call CFAST_Cases.bat

echo Waiting for all CFAST runs to finish
:loop1
tasklist | find /i /c "CFAST" > temp.out
set /p numexe=<temp.out
echo Number of cases running - %numexe%
if %numexe% == 0 goto finished
Timeout /t 30 >nul 
goto loop1

pause

call :find_smokeview_warnings "error" %OUTDIR%\stage4a.txt "Stage 4a_1"
call :find_smokeview_warnings "forrtl: severe" %OUTDIR%\stage4a.txt "Stage 4a_2"

:skip_cfast_debug

echo             release mode

cd %FDSroot%\Verification\scripts
call Run_SMV_cases %size% 0 0 1> %OUTDIR%\stage4b.txt 2>&1

call :find_smokeview_warnings "error" %OUTDIR%\stage4b.txt "Stage 4b_1"
call :find_smokeview_warnings "forrtl: severe" %OUTDIR%\stage4b.txt "Stage 4b_2"

call :GET_TIME
set RUNVV_end=%current_time% 
call :GET_DURATION RUNVV %RUNVV_beg% %RUNVV_end%
set DIFF_RUNVV=%duration%

:: -------------------------------------------------------------
::                           stage 5
:: -------------------------------------------------------------

call :GET_TIME
set MAKEPICS_beg=%current_time% 
echo Stage 5 - Making Smokeview pictures

cd %FDSroot%\Verification\scripts
call MAKE_SMV_pictures %size% 1> %OUTDIR%\stage5.txt 2>&1

call :find_smokeview_warnings "error" %OUTDIR%\stage5.txt "Stage 5"

call :GET_TIME
set MAKEPICS_end=%current_time% 
call :GET_DURATION MAKEPICS %MAKEPICS_beg% %MAKEPICS_end%
set DIFF_MAKEPICS=%duration%

:: -------------------------------------------------------------
::                           stage 6
:: -------------------------------------------------------------

call :GET_TIME
set MAKEGUIDES_beg=%current_time% 
echo Stage 6 - Building Smokeview guides

echo             Technical Reference
call :build_guide SMV_Technical_Reference_Guide %FDSroot%\Manuals\SMV_Technical_Reference_Guide 1>> %OUTDIR%\stage6.txt 2>&1

echo             Verification
call :build_guide SMV_Verification_Guide %FDSroot%\Manuals\SMV_Verification_Guide 1>> %OUTDIR%\stage6.txt 2>&1

echo             User
call :build_guide SMV_User_Guide %FDSroot%\Manuals\SMV_User_Guide 1>> %OUTDIR%\stage6.txt 2>&1

echo             Geom Notes
call :build_guide geom_notes %FDSroot%\Manuals\FDS_User_Guide 1>> %OUTDIR%\stage6.txt 2>&1

call :GET_TIME
set MAKEGUIDES_end=%current_time%
call :GET_DURATION MAKEGUIDES %MAKEGUIDES_beg% %MAKEGUIDES_end%
set DIFF_MAKEGUIDES=%duration%

call :GET_TIME
set TIME_end=%current_time% 
call :GET_DURATION TOTALTIME %TIME_beg% %TIME_end%
set DIFF_TIME=%duration%

:: -------------------------------------------------------------
::                           wrap up
:: -------------------------------------------------------------

date /t > %OUTDIR%\stoptime.txt
set /p stopdate=<%OUTDIR%\stoptime.txt
time /t > %OUTDIR%\stoptime.txt
set /p stoptime=<%OUTDIR%\stoptime.txt

echo. > %infofile%
echo . ----------------------------- >> %infofile%
echo .         host: %COMPUTERNAME% >> %infofile%
echo .        start: %startdate% %starttime% >> %infofile%
echo .         stop: %stopdate% %stoptime%  >> %infofile%
echo .    run cases: %DIFF_RUNVV% >> %infofile%
echo .make pictures: %DIFF_MAKEPICS% >> %infofile%
echo .        total: %DIFF_TIME% >> %infofile%
echo . ----------------------------- >> %infofile%

if NOT exist %tosummarydir% goto skip_copyfiles
  echo summary   (local): file://%userprofile%/FDS-SMV/Manuals/SMV_Summary/index.html >> %infofile%
  echo summary (windows): https://googledrive.com/host/0B-W-dkXwdHWNUElBbWpYQTBUejQ/index.html >> %infofile%
  echo summary   (linux): https://googledrive.com/host/0B-W-dkXwdHWNN3N2eG92X2taRFk/index.html >> %infofile%
  copy %fromsummarydir%\index*.html %tosummarydir%  1> Nul 2>&1
  copy %fromsummarydir%\images\*.png %tosummarydir%\images 1> Nul 2>&1
  copy %fromsummarydir%\images2\*.png %tosummarydir%\images2 1> Nul 2>&1
:skip_copyfiles
  

cd %CURDIR%

if exist %emailexe% (
  if %havewarnings% == 0 (
    if %haveerrors% == 0 (
      call %email% %mailToSMV% "smokebot build success on %COMPUTERNAME%! %revision%" %infofile%
    ) else (
      echo "start: %startdate% %starttime% " > %infofile%
      echo " stop: %stopdate% %stoptime% " >> %infofile%
      echo. >> %infofile%
      type %errorlog% >> %infofile%
      call %email% %mailToSMV% "smokebot build failure on %COMPUTERNAME%! %revision%" %infofile%
    )
  ) else (
    if %haveerrors% == 0 (
      echo "start: %startdate% %starttime% " > %infofile%
      echo " stop: %stopdate% %stoptime% " >> %infofile%
      echo. >> %infofile%
      type %warninglog% >> %infofile%
      %email% %mailToSMV% "smokebot build success with warnings on %COMPUTERNAME% %revision%" %infofile%
    ) else (
      echo "start: %startdate% %starttime% " > %infofile%
      echo " stop: %stopdate% %stoptime% " >> %infofile%
      echo. >> %infofile%
      type %errorlog% >> %infofile%
      echo. >> %infofile%
      type %warninglog% >> %infofile%
      call %email% %mailToSMV% "smokebot build failure on %COMPUTERNAME%! %revision%" %infofile%
    )
  )
)

echo cfastbot_win completed
cd %CURDIR%
pause
exit

:output_abort_message
  echo "***Fatal error: cfastbot build failure on %COMPUTERNAME% %revision%"
exit /b

:: -------------------------------------------------------------
:GET_TIME
:: -------------------------------------------------------------

%gettimeexe% > time.txt
set /p current_time=<time.txt
exit /b 0

:: -------------------------------------------------------------
:GET_DURATION
:: -------------------------------------------------------------
set /a difftime=%3 - %2
set /a diff_h= %difftime%/3600
set /a diff_m= (%difftime% %% 3600 )/60
set /a diff_s= %difftime% %% 60
if %difftime% GEQ 3600 set duration= %diff_h%h %diff_m%m %diff_s%s
if %difftime% LSS 3600 if %difftime% GEQ 60 set duration= %diff_m%m %diff_s%s
if %difftime% LSS 3600 if %difftime% LSS 60 set duration= %diff_s%s
echo %1: %duration% >> %stagestatus%
exit /b 0

:: -------------------------------------------------------------
:is_file_installed
:: -------------------------------------------------------------

  set program=%1
  %program% -help 1>> %OUTDIR%\stage_exist.txt 2>&1
  type %OUTDIR%\stage_exist.txt | find /i /c "not recognized" > %OUTDIR%\stage_count.txt
  set /p nothave=<%OUTDIR%\stage_count.txt
  if %nothave% == 1 (
    echo "***Fatal error: %program% not present"
    echo "***Fatal error: %program% not present" > %errorlog%
    echo "smokebot run aborted"
    call :output_abort_message
    exit /b 1
  )
  exit /b 0

:: -------------------------------------------------------------
  :does_file_exist
:: -------------------------------------------------------------

set file=%1
set outputfile=%2

if NOT exist %file% (
  echo ***fatal error: problem building %file%. Aborting smokebot
  type %outputfile% >> %errorlog%
  call :output_abort_message
  exit /b 1
)
exit /b 0

:: -------------------------------------------------------------
  :find_smokeview_warnings
:: -------------------------------------------------------------

set search_string=%1
set search_file=%2
set stage=%3

grep -v "commands for target" %search_file% > %OUTDIR%\stage_warning0.txt
grep -i -A 5 -B 5 %search_string% %OUTDIR%\stage_warning0.txt > %OUTDIR%\stage_warning.txt
type %OUTDIR%\stage_warning.txt | find /v /c "kdkwokwdokwd"> %OUTDIR%\stage_nwarning.txt
set /p nwarnings=<%OUTDIR%\stage_nwarning.txt
if %nwarnings% GTR 0 (
  echo %stage% warnings >> %warninglog%
  echo. >> %warninglog%
  type %OUTDIR%\stage_warning.txt >> %warninglog%
  set havewarnings=1
)
exit /b

:: -------------------------------------------------------------
  :find_cfast_warnings
:: -------------------------------------------------------------

set search_string=%1
set search_file=%2
set stage=%3

grep -v "mpif.h" %search_file% > %OUTDIR%\stage_warning0.txt
grep -i -A 5 -B 5 %search_string% %OUTDIR%\stage_warning0.txt  > %OUTDIR%\stage_warning.txt
type %OUTDIR%\stage_warning.txt | find /c ":"> %OUTDIR%\stage_nwarning.txt
set /p nwarnings=<%OUTDIR%\stage_nwarning.txt
if %nwarnings% GTR 0 (
  echo %stage% warnings >> %warninglog%
  echo. >> %warninglog%
  type %OUTDIR%\stage_warning.txt >> %warninglog%
  set havewarnings=1
)
exit /b

:: -------------------------------------------------------------
 :build_guide
:: -------------------------------------------------------------

set guide=%1
set guide_dir=%2

set guideout=%OUTDIR%\stage6_%guide%.txt

cd %guide_dir%

pdflatex -interaction nonstopmode %guide% 1> %guideout% 2>&1
bibtex %guide% 1> %guideout% 2>&1
pdflatex -interaction nonstopmode %guide% 1> %guideout% 2>&1
pdflatex -interaction nonstopmode %guide% 1> %guideout% 2>&1
bibtex %guide% 1>> %guideout% 2>&1

type %guideout% | find "Undefined control" > %OUTDIR%\stage_error.txt
type %guideout% | find "! LaTeX Error:" >> %OUTDIR%\stage_error.txt
type %guideout% | find "Fatal error" >> %OUTDIR%\stage_error.txt
type %guideout% | find "Error:" >> %OUTDIR%\stage_error.txt

type %OUTDIR%\stage_error.txt | find /v /c "JDIJWIDJIQ"> %OUTDIR%\stage_nerrors.txt
set /p nerrors=<%OUTDIR%\stage_nerrors.txt
if %nerrors% GTR 0 (
  echo Errors from Stage 6 - Build %guide% >> %errorlog%
  type %OUTDIR%\stage_error.txt >> %errorlog%
  set haveerrors=1
)

type %guideout% | find "undefined" > %OUTDIR%\stage_warning.txt
type %guideout% | find "multiply"  >> %OUTDIR%\stage_warning.txt

type %OUTDIR%\stage_warning.txt | find /c ":"> %OUTDIR%\nwarnings.txt
set /p nwarnings=<%OUTDIR%\nwarnings.txt
if %nwarnings% GTR 0 (
  echo Warnings from Stage 6 - Build %guide% >> %warninglog%
  type %OUTDIR%\stage_warning.txt >> %warninglog%
  set havewarnings=1
)

copy %guide%.pdf %fromsummarydir%\manuals
copy %guide%.pdf %tosummarydir%\manuals

exit /b

:eof
cd %CURDIR%
pause
exit
