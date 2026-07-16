@echo off
setlocal enabledelayedexpansion
echo 1 - setup OBS sender (capture this PC and send over LAN)
echo 2 - launch OBS sender (only after setup)
echo 3 - close OBS
echo 4 - setup OBS receiver (run this on the recording PC)
echo 5 - launch OBS receiver (preview only, no disk recording)

set /p choice="Enter 1-5: "
if "%choice%"=="2" goto option2
if "%choice%"=="3" goto option3
if "%choice%"=="4" goto option4
if "%choice%"=="5" goto option5
goto option1

:option1
set "i=0"
echo Searching for connected monitors...
echo.

for /f "usebackq delims=" %%A in (
    `powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPClass -eq 'Monitor' } | Select-Object -ExpandProperty DeviceID"`
) do (
    set /a i+=1
    set "id=%%A"
    if not "!id!"=="" (
        for /f "tokens=* delims= " %%B in ("!id!") do set "id=%%B"
        set "id!i!=!id!%"
    )
)

if %i%==0 (
    echo No monitors found.
    pause
    exit /b
)

for /f "usebackq delims=" %%M in (
    `powershell -NoProfile -Command "(Get-CimInstance Win32_DesktopMonitor | Where-Object { $_.Primary -eq $true }).PNPDeviceID"`
) do set "primary=%%M"

echo Found %i% monitor(s):
echo -----------------------------
set "primary_index="

for /L %%N in (1,1,%i%) do (
    set "mark="
    if /i "!id%%N!"=="!primary!" (
        set "mark= (primary)"
        set "primary_index=%%N"
    )
    echo [%%N] !id%%N!!mark!
)
echo -----------------------------

if defined primary_index (
    echo Default monitor will be #!primary_index! (primary)
    echo.
)

set /p "choice=Enter monitor number to use (Press Enter for default): "

if not defined choice (
    if defined primary_index (
        set "choice=!primary_index!"
    ) else (
        set "choice=1"
    )
)

if %choice% lss 1 set "choice=1"
if %choice% gtr %i% set "choice=1"

set "id=!id%choice%!"
set "id=!id:\=#!"
set "id=!id: =!"
set "MONITOR_ID=\\\?\!id!#{e6f07b5f-ee97-4a90-b076-33f57bf4eaa7}"


for /f "usebackq" %%w in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width"`) do set WIDTH=%%w
for /f "usebackq" %%h in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height"`) do set HEIGHT=%%h

echo Default monitor resolution: %WIDTH%x%HEIGHT%
echo (leave blank for default resolution(just press Enter))
set /p "WIDTH=Enter width: "
set /p "HEIGHT=Enter height: "

set "input=!MONITOR_ID!"

for /f "tokens=1-5 delims=&" %%a in ("!input!") do (
    set "part1=%%a"
    set "part2=%%b"
    set "part3=%%c"
    set "part4=%%d"
    set "part5=%%e"
)

set "lower="
for /l %%i in (0,1,7) do (
    set "char=!part2:~%%i,1!"
    for %%L in (a b c d e f) do (
        if /i "!char!"=="%%L" set "char=%%L"
    )
    set "lower=!lower!!char!"
)

set "MONITOR_ID_lower=!part1!&!lower!&!part3!&!part4!!part5!"

echo !MONITOR_ID_lower!

:skip

taskkill /f /im obs64.exe 2>nul

timeout /t 1 >nul

for /f "usebackq" %%a in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width"`) do set WIDTH=%%a
for /f "usebackq" %%a in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height"`) do set HEIGHT=%%a

echo Screen resolution: %WIDTH%x%HEIGHT%

echo .
echo Enter the LAN IPv4 address of the RECEIVER PC, for example 192.168.0.2

set /p IP_INPUT=Enter ip: 
if "%IP_INPUT%"=="" set "IP_INPUT=192.168.0.2"

echo .
echo FOVFPS example: 120
set /p FOVFPS=Enter fps: 
if "%FOVFPS%"=="" set "FOVFPS=120"


set "sceneFovFile=%APPDATA%\obs-studio\basic\scenes\scene1.json"
set "sceneRecognitionFile=%APPDATA%\obs-studio\basic\scenes\scene2.json"

set "profileDirMain=%APPDATA%\obs-studio\basic\profiles\profile1"
set "profileDirMain2=%APPDATA%\obs-studio\basic\profiles\profile2"

set "basicIniFileMain=%profileDirMain%\basic.ini"
set "basicIniFileMain2=%profileDirMain2%\basic.ini"
set "userInifile=%APPDATA%\obs-studio\user.ini"


if not exist "%profileDirMain%" (
    mkdir "%profileDirMain%"
)

if not exist "%profileDirMain2%" (
    mkdir "%profileDirMain2%"
)

if not exist "%APPDATA%\obs-studio\basic\scenes" (
    mkdir "%APPDATA%\obs-studio\basic\scenes"
)

set /a CropX=(%WIDTH%-1024)/2
set /a CropY=(%HEIGHT%-1024)/2

set /a CropXpart=(%WIDTH%/5)
set /a CropYpart=(%HEIGHT%/2)

set /a CropX2=(%WIDTH% - %CropXpart%)
set /a CropY2=(%HEIGHT% - %CropYpart%)

(
echo [General]
echo Name=profile1
echo.
echo [Video]
echo BaseCX=1024
echo BaseCY=1024
echo OutputCX=1024
echo OutputCY=1024
echo FPSType=2
echo FPSNum=%FOVFPS%
echo FPSDen=1
echo [Output]
echo Mode=Advanced
echo DelayEnable=false
echo Reconnect=true
echo BindIP=default
echo IPFamily=IPv4+IPv6
echo NewSocketLoopEnable=false
echo LowLatencyEnable=true 
echo [AdvOut]
echo ApplyServiceSettings=true
echo UseRescale=false
echo TrackIndex=1
echo VodTrackIndex=2
echo Encoder=obs_x264
echo RecType=FFmpeg
echo RecFormat2=mkv
echo RecUseRescale=false
echo RecTracks=1
echo RecEncoder=none
echo FLVTrack=1
echo FFOutputToFile=false
echo FFVBitrate=4000
echo FFVGOPSize=0
echo FFUseRescale=false
echo FFIgnoreCompat=false
echo RecSplitFileTime=15
echo RecSplitFileSize=2048
echo RecRB=false
echo RecRBTime=20
echo RecRBSize=512
echo AudioEncoder=ffmpeg_aac
echo RecAudioEncoder=ffmpeg_aac
echo RecSplitFileType=Time
echo FFURL=udp://%IP_INPUT%:41263
echo FFFormat=mjpeg
echo FFFormatMimeType=image/jpeg
echo FFVEncoderId=8
echo FFVEncoder=mjpeg
echo FFAEncoderId=0
echo FFAEncoder=
echo FFExtension=mjpg
) > "%basicIniFileMain%"

(
echo [General]
echo Name=profile2
echo.
echo [Video]
echo BaseCX=%CropXpart%
echo BaseCY=%CropYpart%
echo OutputCX=%CropXpart%
echo OutputCY=%CropYpart%
echo FPSType=2
echo FPSNum=5
echo FPSDen=1
echo [Output]
echo Mode=Advanced
echo DelayEnable=false
echo Reconnect=true
echo BindIP=default
echo IPFamily=IPv4+IPv6
echo NewSocketLoopEnable=false
echo LowLatencyEnable=true 
echo [AdvOut]
echo ApplyServiceSettings=true
echo UseRescale=false
echo TrackIndex=1
echo VodTrackIndex=2
echo Encoder=obs_x264
echo RecType=FFmpeg
echo RecFormat2=mkv
echo RecUseRescale=false
echo RecTracks=1
echo RecEncoder=none
echo FLVTrack=1
echo FFOutputToFile=false
echo FFVBitrate=50000
echo FFVGOPSize=0
echo FFUseRescale=false
echo FFIgnoreCompat=false
echo RecSplitFileTime=15
echo RecSplitFileSize=2048
echo RecRB=false
echo RecRBTime=20
echo RecRBSize=512
echo AudioEncoder=ffmpeg_aac
echo RecAudioEncoder=ffmpeg_aac
echo RecSplitFileType=Time
echo FFURL=udp://%IP_INPUT%:41264
echo FFFormat=mjpeg
echo FFFormatMimeType=image/jpeg
echo FFVEncoderId=8
echo FFVEncoder=mjpeg
echo FFAEncoderId=0
echo FFAEncoder=
echo FFExtension=mjpg
) > "%basicIniFileMain2%"

set "fov1=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "fov1="%fov1%""
set "fov2=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "fov2="%fov2%""
set "fov3=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "fov3="%fov3%""
set "fov4=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "fov4="%fov4%""
set "fov5=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "fov5="%fov5%""
set "fov6=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "fov6="%fov6%""

(
echo {
echo     "current_scene": "Scene",
echo     "current_program_scene": "Scene",
echo     "scene_order": [
echo         {
echo             "name": "Scene"
echo         }
echo     ],
echo     "name": "scene1",
echo     "sources": [
echo         {
echo             "prev_ver": 520159234,
echo             "name": "Scene",
echo             "uuid": %fov1%,
echo             "id": "scene",
echo             "versioned_id": "scene",
echo             "settings": {
echo                 "id_counter": 1,
echo                 "custom_size": false,
echo                 "items": [
echo                     {
echo                         "name": "Screencap",
echo                         "source_uuid": %fov2%,
echo                         "visible": true,
echo                         "id": 1,
echo                         "pos": {
echo                             "x": 0.0,
echo                             "y": 0.0
echo                         },
echo                         "bounds": {
echo                             "x": 1024.0,
echo                             "y": 1024.0
echo                         },
echo                         "scale_filter": "disable",
echo                         "blend_method": "default",
echo                         "blend_type": "normal",
echo                         "private_settings": {}
echo                     }
echo                 ]
echo             },
echo             "canvas_uuid": %fov3%,
echo             "private_settings": {}
echo         },
echo         {
echo             "prev_ver": 520159234,
echo             "name": "Screencap",
echo             "uuid": %fov4%,
echo             "id": "monitor_capture",
echo             "versioned_id": "monitor_capture",
echo             "settings": {
echo                "monitor_id": "!MONITOR_ID_lower!"
echo             },
echo             "filters": [
echo                 {
echo                     "prev_ver": 520159234,
echo                     "name": "Crop",
echo                     "uuid": %fov5%,
echo                     "id": "crop_filter",
echo                     "versioned_id": "crop_filter",
echo                     "settings": {
echo                         "left": %CropX%,
echo                         "top": %CropY%,
echo                         "cx": 1024,
echo                         "cy": 1024,
echo                         "right": 100,
echo                         "bottom": 100,
echo                         "relative": false
echo                     }
echo                 }
echo             ]
echo         }
echo     ],
echo     "version": 2
echo }
) > "%sceneFovFile%"


set "rec1=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "rec1="%rec1%""
set "rec2=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "rec2="%rec2%""
set "rec3=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "rec3="%rec3%""
set "rec4=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "rec4="%rec4%""
set "rec5=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "rec5="%rec5%""
set "rec6=%random%%random%-%random%-%random%-%random%-%random%%random%%random%"
set "rec6="%rec6%""

(
echo {
echo     "current_scene": "Scene",
echo     "current_program_scene": "Scene",
echo     "scene_order": [
echo         {
echo             "name": "Scene"
echo         }
echo     ],
echo     "name": "scene2",
echo     "sources": [
echo         {
echo             "prev_ver": 520159234,
echo             "name": "Scene",
echo             "uuid": %rec1%,
echo             "id": "scene",
echo             "versioned_id": "scene",
echo             "settings": {
echo                 "id_counter": 1,
echo                 "custom_size": false,
echo                 "items": [
echo                     {
echo                         "name": "Screencap",
echo                         "source_uuid": %rec2%,
echo                         "visible": true,
echo                         "id": 1,
echo                         "pos": {
echo                             "x": 0.0,
echo                             "y": 0.0
echo                         },
echo                         "bounds": {
echo                             "x": %CropXpart%.0,
echo                             "y": %CropYpart%.0
echo                         },
echo                         "scale_filter": "disable",
echo                         "blend_method": "default",
echo                         "blend_type": "normal",
echo                         "private_settings": {}
echo                     }
echo                 ]
echo             },
echo             "canvas_uuid":  %rec3%,
echo             "private_settings": {}
echo         },
echo         {
echo             "prev_ver": 520159234,
echo             "name": "Screencap",
echo             "uuid": %rec5%,
echo             "id": "monitor_capture",
echo             "versioned_id": "monitor_capture",
echo             "settings": {
echo                "monitor_id": "!MONITOR_ID_lower!"
echo             },
echo			 "filters": [
echo                 {
echo                     "prev_ver": 520159234,
echo                     "name": "Crop",
echo                     "uuid": %rec6%,
echo                     "id": "crop_filter",
echo                     "versioned_id": "crop_filter",
echo                     "settings": {
echo                         "left": %CropX2%,
echo                         "top": %CropY2%,
echo                         "cx": %CropXpart%,
echo                         "cy": %CropYpart%,
echo                         "right": 100,
echo                         "bottom": 100,
echo                         "relative": false
echo                     }
echo                 }
echo             ]
echo         }
echo     ],
echo     "version": 2
echo }
) > "%sceneRecognitionFile%"


goto option2

:option4
set "receiverProfileDir=%APPDATA%\obs-studio\basic\profiles\lan_receiver"
set "receiverCollection=%APPDATA%\obs-studio\basic\scenes\lan_receiver.json"
if not exist "%receiverProfileDir%" mkdir "%receiverProfileDir%"
if not exist "%APPDATA%\obs-studio\basic\scenes" mkdir "%APPDATA%\obs-studio\basic\scenes"
(
echo [General]
echo Name=lan_receiver
echo.
echo [Video]
echo BaseCX=1920
echo BaseCY=1080
echo OutputCX=1920
echo OutputCY=1080
echo FPSType=0
echo FPSCommon=60
echo.
echo [Output]
echo Mode=Simple
echo.
echo [SimpleOutput]
echo RecFormat2=mkv
) > "%receiverProfileDir%\basic.ini"
(
echo {"current_scene":"LAN FOV","current_program_scene":"LAN FOV","name":"lan_receiver","scene_order":[{"name":"LAN FOV"},{"name":"LAN Recognition"}],"sources":[
echo {"name":"LAN FOV","uuid":"a1000000-0000-0000-0000-000000000001","id":"scene","versioned_id":"scene","settings":{"id_counter":1,"custom_size":false,"items":[{"name":"UDP stream 41263","source_uuid":"a1000000-0000-0000-0000-000000000011","visible":true,"id":1,"pos":{"x":0.0,"y":0.0},"scale_filter":"disable","blend_method":"default","blend_type":"normal","private_settings":{}}]},"private_settings":{}},
echo {"name":"LAN Recognition","uuid":"a1000000-0000-0000-0000-000000000002","id":"scene","versioned_id":"scene","settings":{"id_counter":1,"custom_size":false,"items":[{"name":"UDP stream 41264","source_uuid":"a1000000-0000-0000-0000-000000000012","visible":true,"id":1,"pos":{"x":0.0,"y":0.0},"scale_filter":"disable","blend_method":"default","blend_type":"normal","private_settings":{}}]},"private_settings":{}},
echo {"name":"UDP stream 41263","uuid":"a1000000-0000-0000-0000-000000000011","id":"ffmpeg_source","versioned_id":"ffmpeg_source","settings":{"is_local_file":false,"input":"udp://@:41263?fifo_size=250000^&overrun_nonfatal=1","input_format":"mpegts","looping":false,"restart_on_activate":true,"close_when_inactive":true,"clear_on_media_end":false,"hw_decode":true},"private_settings":{}},
echo {"name":"UDP stream 41264","uuid":"a1000000-0000-0000-0000-000000000012","id":"ffmpeg_source","versioned_id":"ffmpeg_source","settings":{"is_local_file":false,"input":"udp://@:41264?fifo_size=250000^&overrun_nonfatal=1","input_format":"mpegts","looping":false,"restart_on_activate":true,"close_when_inactive":true,"clear_on_media_end":false,"hw_decode":true},"private_settings":{}}
echo ],"version":2}
) > "%receiverCollection%"
echo Receiver setup is complete. Use option 5 to open the live preview without recording to disk.
pause
endlocal
exit /b
:option2

echo [INFO] Checking if OBS Studio is installed...
if not exist "C:\Program Files\obs-studio\bin\64bit\obs64.exe" (
    echo [ERROR] OBS Studio not found!
    echo Please install OBS Studio to its default directory: C:\Program Files\obs-studio\
    pause
    exit /b
)

cd /d "C:\Program Files\obs-studio\bin\64bit"
start "" /MIN obs64.exe --multi --collection "scene1" --profile "profile1" --startrecording


endlocal
exit


:option5
if not exist "C:\Program Files\obs-studio\bin\64bit\obs64.exe" (
    echo OBS Studio not found in C:\Program Files\obs-studio\
    pause
    exit /b
)
cd /d "C:\Program Files\obs-studio\bin\64bit"
start "" /MIN obs64.exe --collection "lan_receiver" --profile "lan_receiver"
endlocal
exit
:option3
taskkill /f /im obs64.exe 2>nul
endlocal
exit
