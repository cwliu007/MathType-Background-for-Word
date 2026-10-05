@echo off
setlocal EnableExtensions DisableDelayedExpansion
title wb_no_v0.0.13 - MathType White Background Direct Ribbon Hook

set "WB_SELF=%~f0"
set "WB_MODE=install"
if /I "%~1"=="restore" set "WB_MODE=restore"

if /I "%~2"=="--elevated" goto :ELEVATED

rem Minimize repeated Windows trust prompts.  A freshly downloaded CMD may carry
rem Mark-of-the-Web (Zone.Identifier).  The very first pre-execution warning cannot
rem be removed by code that has not run yet, but once allowed, remove the mark from
rem the original file so later runs normally require only the real UAC consent.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Unblock-File -LiteralPath $env:WB_SELF -ErrorAction SilentlyContinue } catch {}" >nul 2>&1

rem UAC boundary isolation: the original installer may live in OneDrive or another sync root.
rem Copy only this installer to local TEMP before elevation. The elevated process then runs
rem the local copy and never needs to reopen the OneDrive source path.
set "WB_DESKTOP="
for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2^>nul`) do if not defined WB_DESKTOP set "WB_DESKTOP=%%D"
if not defined WB_DESKTOP set "WB_DESKTOP=%USERPROFILE%\Desktop"
if not exist "%WB_DESKTOP%" mkdir "%WB_DESKTOP%" >nul 2>&1
set "WB_BOOT_LOG=%WB_DESKTOP%\wb_no_v0.0.13_bootstrap_log.txt"
set "WB_CHILD_REPORT=%WB_DESKTOP%\wb_no_v0.0.13_child_error.txt"
del /q "%WB_CHILD_REPORT%" >nul 2>&1
>"%WB_BOOT_LOG%" echo wb_no_v0.0.13 bootstrap started: %DATE% %TIME%
>>"%WB_BOOT_LOG%" echo Original script: %WB_SELF%
>>"%WB_BOOT_LOG%" echo Mode: %WB_MODE%

set "WB_STAGE_DIR=%TEMP%\wb_no_v0.0.13_stage_%RANDOM%_%RANDOM%"
set "WB_STAGE_SELF=%WB_STAGE_DIR%\wb_no_v0.0.13.cmd"
mkdir "%WB_STAGE_DIR%" >nul 2>&1
if errorlevel 1 (
    >>"%WB_BOOT_LOG%" echo Failed to create local UAC staging directory: %WB_STAGE_DIR%
    echo [ERROR] Could not create the local UAC staging directory.
    echo [ERROR] Bootstrap log: %WB_BOOT_LOG%
    pause
    exit /b 93
)
copy /y "%WB_SELF%" "%WB_STAGE_SELF%" >nul 2>&1
if errorlevel 1 (
    >>"%WB_BOOT_LOG%" echo Failed to copy installer to local staging path: %WB_STAGE_SELF%
    rd /s /q "%WB_STAGE_DIR%" >nul 2>&1
    echo [ERROR] Could not copy the installer to the local UAC staging directory.
    echo [ERROR] Bootstrap log: %WB_BOOT_LOG%
    pause
    exit /b 94
)
>>"%WB_BOOT_LOG%" echo Local elevated script: %WB_STAGE_SELF%
rem The local staging copy must not inherit a web/OneDrive zone mark, otherwise
rem Windows can show a second file-trust confirmation before the UAC prompt.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Unblock-File -LiteralPath $env:WB_STAGE_SELF -ErrorAction SilentlyContinue } catch {}" >nul 2>&1

echo [INFO] Administrator permission is required only to patch or restore a MathType template under Program Files.
echo [INFO] Requesting Windows UAC permission...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; try { $p=Start-Process -FilePath $env:WB_STAGE_SELF -Verb RunAs -Wait -PassThru -ArgumentList @($env:WB_MODE,'--elevated'); exit $p.ExitCode } catch { Write-Host ('[ERROR] UAC launch failed: ' + $_.Exception.Message); exit 90 }"
set "WB_BOOT_RC=%ERRORLEVEL%"

rem The elevated child has finished; remove only the local bootstrap copy.
rd /s /q "%WB_STAGE_DIR%" >nul 2>&1

if "%WB_BOOT_RC%"=="0" goto :BOOTSTRAP_OK

>>"%WB_BOOT_LOG%" echo UAC/child installer returned error code %WB_BOOT_RC%.
echo.
echo [ERROR] The elevated installer could not be started or it returned an error.
echo [ERROR] Error code: %WB_BOOT_RC%
echo [ERROR] Bootstrap log: %WB_BOOT_LOG%
echo.
if exist "%WB_CHILD_REPORT%" (
    echo ==================== CHILD INSTALLER ERROR ====================
    type "%WB_CHILD_REPORT%"
    echo ===============================================================
    echo.
) else (
    echo [WARN] No child error report was produced.
    echo.
)
pause
exit /b %WB_BOOT_RC%

:BOOTSTRAP_OK
del /q "%WB_BOOT_LOG%" "%WB_CHILD_REPORT%" >nul 2>&1
exit /b 0

:ELEVATED
set "WB_VBS=%TEMP%\wb_no_v0.0.13_%RANDOM%_%RANDOM%.vbs"
set "WB_PS=%TEMP%\wb_no_v0.0.13_%RANDOM%_%RANDOM%.ps1"
set "WB_STARTUP_INFO=%TEMP%\wb_no_v0.0.13_%RANDOM%_%RANDOM%_wordpaths.txt"
set "WB_STAGE1_OUT=%TEMP%\wb_no_v0.0.13_%RANDOM%_%RANDOM%_stage1.txt"
if not defined WB_DESKTOP (
    for /f "usebackq delims=" %%D in (`powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')" 2^>nul`) do if not defined WB_DESKTOP set "WB_DESKTOP=%%D"
)
if not defined WB_DESKTOP set "WB_DESKTOP=%USERPROFILE%\Desktop"
if not exist "%WB_DESKTOP%" mkdir "%WB_DESKTOP%" >nul 2>&1
set "WB_LOG=%WB_DESKTOP%\wb_no_v0.0.13_install_log.txt"
set "WB_CHILD_REPORT=%WB_DESKTOP%\wb_no_v0.0.13_child_error.txt"
set "WB_FAIL_STAGE=Elevated installer startup"
del /q "%WB_CHILD_REPORT%" >nul 2>&1
set "WB_ORIGINAL_CWD=%CD%"
cd /d "%TEMP%" >nul 2>&1
if errorlevel 1 (
    set "WB_RC=92"
    set "WB_FAIL_STAGE=Switching elevated working directory to TEMP"
    goto :FAILED
)

echo [INFO] wb_no_v0.0.13 %WB_MODE% started.
echo [INFO] Elevated working directory isolated from the source folder: %CD%
echo [INFO] This is the wb_v0.0.37 direct-hook core with cross-Office path detection.
echo [INFO] No SelectionChange, WindowActivate/Deactivate, timer, or polling is installed.
echo.

set "WB_FAIL_STAGE=Preparing embedded VBS and PowerShell payloads"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; " ^
  "$lines=Get-Content -LiteralPath $env:WB_SELF; " ^
  "$v1=[Array]::IndexOf($lines, ':__WB_VBS_PAYLOAD__'); $v2=[Array]::IndexOf($lines, ':__WB_VBS_END__'); " ^
  "$p1=[Array]::IndexOf($lines, ':__WB_PS_PAYLOAD__'); $p2=[Array]::IndexOf($lines, ':__WB_PS_END__'); " ^
  "if($v1 -lt 0 -or $v2 -le $v1 -or $p1 -lt 0 -or $p2 -le $p1){throw 'Embedded payload markers not found.'}; " ^
  "if($env:WB_MODE -ne 'restore'){ $lines[($v1+1)..($v2-1)] | Set-Content -LiteralPath $env:WB_VBS -Encoding Unicode }; " ^
  "$lines[($p1+1)..($p2-1)] | Set-Content -LiteralPath $env:WB_PS -Encoding ASCII"

if errorlevel 1 (
    set "WB_RC=91"
    >"%WB_LOG%" echo [%DATE% %TIME%] [ERROR] Failed to prepare installer payloads.
    goto :FAILED
)

if /I "%WB_MODE%"=="restore" goto :RESTORE

rem Word must not hold either variant open during the pre-switch check.
taskkill /F /IM WINWORD.EXE >nul 2>&1

echo [INFO] Checking for an installed wb_v Ribbon variant before installing wb_no...
set "WB_FAIL_STAGE=Pre-install conflicting wb_v detection/removal"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode prepare-switch -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED
echo [INFO] Closing Microsoft Word processes before Stage 1...
taskkill /F /IM WINWORD.EXE >nul 2>&1
echo [INFO] Word close step completed.
echo [INFO] Stage 1/2: creating the wb Word global add-in and detecting this Word installation...
set "WB_FAIL_STAGE=Stage 1 - cscript / Word global add-in creation"
>"%WB_STAGE1_OUT%" echo ===== wb_no_v0.0.13 Stage 1 cscript output =====
cscript.exe //nologo "%WB_VBS%" >>"%WB_STAGE1_OUT%" 2>&1
set "WB_RC=%ERRORLEVEL%"
if "%WB_RC%"=="0" (
    del /q "%WB_STAGE1_OUT%" >nul 2>&1
    goto :STAGE2
)
if not exist "%WB_LOG%" >"%WB_LOG%" echo [%DATE% %TIME%] [ERROR] Stage 1 failed before the VBScript installer could create its own log.
echo.
echo [ERROR] Stage 1 cscript.exe returned error code %WB_RC%.
echo [ERROR] cscript.exe output follows:
type "%WB_STAGE1_OUT%"
echo.
>>"%WB_LOG%" echo [%DATE% %TIME%] [ERROR] cscript.exe returned error code %WB_RC%.
>>"%WB_LOG%" echo.
>>"%WB_LOG%" type "%WB_STAGE1_OUT%"
>>"%WB_LOG%" echo.
goto :FAILED

:STAGE2

rem Close any hidden Word process left by the Stage 1 COM creation step.
taskkill.exe /F /IM WINWORD.EXE >nul 2>&1

echo.
echo [INFO] Stage 2/2: locating and patching a compatible MathType Word template...
set "WB_FAIL_STAGE=Stage 2 - MathType discovery / Ribbon patch"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode install -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED

echo.
echo [SUCCESS] wb_no_v0.0.13 installed successfully.
echo [INFO] The wb_v0.0.37 formula-handling core is unchanged.
echo [INFO] MathType VBA was not modified; only compatible Ribbon XML callbacks were patched.
echo.
echo [INFO] You can also restore later by running:
echo [INFO] "%~nx0" restore
echo.
echo [QUESTION] Restore the original state now?
echo [INFO] Y = restore now; N = keep the installation. Default is N after 15 seconds.
choice /C YN /N /T 15 /D N /M "[Y/N]: "
set "WB_CHOICE_RC=%ERRORLEVEL%"

if "%WB_CHOICE_RC%"=="1" goto :POST_INSTALL_RESTORE
goto :KEEP_INSTALLATION

:POST_INSTALL_RESTORE
echo.
rem Restore must not run while Word holds the MathType/global templates open.
taskkill.exe /F /IM WINWORD.EXE >nul 2>&1
echo [INFO] Restore selected. Restoring the original MathType template and removing the wb add-in...
set "WB_FAIL_STAGE=Post-install restore"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode restore -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED

del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" "%WB_STAGE1_OUT%" >nul 2>&1
del /q "%WB_LOG%" >nul 2>&1
echo.
echo [SUCCESS] Restore completed and wb add-in removed.
timeout /t 3 /nobreak >nul
exit /b 0

:KEEP_INSTALLATION
del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" "%WB_STAGE1_OUT%" >nul 2>&1
del /q "%WB_LOG%" >nul 2>&1
echo.
echo [INFO] Keeping the installation. Closing installer.
exit /b 0

:RESTORE
rem Manual restore uses the same safe forced-close behavior as installation.
taskkill.exe /F /IM WINWORD.EXE >nul 2>&1
echo [INFO] Restoring the original MathType template and removing the wb add-in...
set "WB_FAIL_STAGE=Manual restore"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode restore -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED

del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" "%WB_STAGE1_OUT%" >nul 2>&1
del /q "%WB_LOG%" >nul 2>&1

echo.
echo [SUCCESS] Original MathType template restored and wb add-in removed.
echo.
pause
exit /b 0

:FAILED
>"%WB_CHILD_REPORT%" echo wb_no_v0.0.13 elevated child failure report
>>"%WB_CHILD_REPORT%" echo Time: %DATE% %TIME%
>>"%WB_CHILD_REPORT%" echo Stage: %WB_FAIL_STAGE%
>>"%WB_CHILD_REPORT%" echo Error code: %WB_RC%
>>"%WB_CHILD_REPORT%" echo Script: %WB_SELF%
>>"%WB_CHILD_REPORT%" echo Original working directory: %WB_ORIGINAL_CWD%
>>"%WB_CHILD_REPORT%" echo Elevated working directory: %CD%
>>"%WB_CHILD_REPORT%" echo.
if exist "%WB_STAGE1_OUT%" (
    >>"%WB_CHILD_REPORT%" echo ===== cscript stdout/stderr =====
    >>"%WB_CHILD_REPORT%" type "%WB_STAGE1_OUT%"
    >>"%WB_CHILD_REPORT%" echo.
)
if exist "%WB_LOG%" (
    >>"%WB_CHILD_REPORT%" echo ===== installer log =====
    >>"%WB_CHILD_REPORT%" type "%WB_LOG%"
    >>"%WB_CHILD_REPORT%" echo.
)
del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" "%WB_STAGE1_OUT%" >nul 2>&1
echo.
echo [ERROR] Operation failed. Error code: %WB_RC%
echo [ERROR] Failure stage: %WB_FAIL_STAGE%
echo [ERROR] Detailed child report retained at:
echo [ERROR] %WB_CHILD_REPORT%
echo [ERROR] Installer log retained at:
echo [ERROR] %WB_LOG%
echo.
pause
exit /b %WB_RC%

:__WB_VBS_PAYLOAD__
Option Explicit

Const INSTALLER_NAME = "wb_no_v0.0.13"
Const ADDIN_FILE = "wb_MathTypeWhiteBackground.dotm"
Const wdStartupPath = 8
Const wdFormatXMLTemplateMacroEnabled = 15
Const vbext_ct_StdModule = 1

Dim fso, sh, logPath
Dim restoreOK
Dim accessPath, accessExisted, oldAccessValue, accessChanged
Dim wordVersion, startupPath, wordInstallPath, targetPath
Dim startupInfoPath, startupInfo
Dim probe, wordApp, doc, vbProj, modMain

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
logPath = sh.ExpandEnvironmentStrings("%WB_LOG%")

On Error Resume Next
If fso.FileExists(logPath) Then fso.DeleteFile logPath, True
On Error GoTo 0

restoreOK = True

LogMsg "INFO", "Installer started: " & INSTALLER_NAME
LogMsg "INFO", "Runtime design: direct MathType Ribbon XML hook; all three insert commands use one local-only repair path. No Word application events, timer, polling, or full-document scan."
LogMsg "INFO", "Microsoft Word processes were closed by the elevated installer before Stage 1."
LogMsg "INFO", "Detecting Word version and user Startup path."

On Error Resume Next
Err.Clear
Set probe = CreateObject("Word.Application")
If Err.Number <> 0 Then
    FailNow "Cannot start Microsoft Word. Error " & Err.Number & ": " & Err.Description
End If

wordVersion = probe.Version
startupPath = probe.Options.DefaultFilePath(wdStartupPath)
wordInstallPath = probe.Path
LogMsg "INFO", "Word version: " & wordVersion
LogMsg "INFO", "Word Startup path: " & startupPath
LogMsg "INFO", "Word application path: " & wordInstallPath

Err.Clear
probe.Quit
If Err.Number <> 0 Then
    LogMsg "WARN", "Word probe Quit error " & Err.Number & ": " & Err.Description
    Err.Clear
End If
Set probe = Nothing
On Error GoTo 0

If Len(Trim(startupPath)) = 0 Then
    startupPath = sh.ExpandEnvironmentStrings("%APPDATA%") & "\Microsoft\Word\STARTUP"
    LogMsg "WARN", "Using fallback Word Startup path: " & startupPath
End If

If Not fso.FolderExists(startupPath) Then
    On Error Resume Next
    Err.Clear
    fso.CreateFolder startupPath
    If Err.Number <> 0 Then
        FailNow "Cannot create Word Startup folder. Error " & Err.Number & ": " & Err.Description
    End If
    On Error GoTo 0
End If

startupInfoPath = sh.ExpandEnvironmentStrings("%WB_STARTUP_INFO%")
If Len(Trim(startupInfoPath)) > 0 Then
    On Error Resume Next
    Err.Clear
    Set startupInfo = fso.CreateTextFile(startupInfoPath, True, True)
    If Err.Number = 0 Then
        startupInfo.WriteLine startupPath
        startupInfo.WriteLine wordInstallPath
        startupInfo.Close
        Set startupInfo = Nothing
        LogMsg "INFO", "Recorded Word paths for Stage 2."
    Else
        LogMsg "WARN", "Could not record Word paths for Stage 2. Error " & Err.Number & ": " & Err.Description
        Err.Clear
    End If
    On Error GoTo 0
End If

targetPath = fso.BuildPath(startupPath, ADDIN_FILE)
LogMsg "INFO", "Removing old wb MathType add-in versions."
RemoveOldAddins startupPath

accessPath = "HKCU\Software\Microsoft\Office\" & wordVersion & "\Word\Security\AccessVBOM"

On Error Resume Next
Err.Clear
oldAccessValue = sh.RegRead(accessPath)
If Err.Number = 0 Then
    accessExisted = True
    LogMsg "INFO", "Existing AccessVBOM value: " & CStr(oldAccessValue)
Else
    Err.Clear
    accessExisted = False
    LogMsg "INFO", "AccessVBOM did not previously exist."
End If

Err.Clear
sh.RegWrite accessPath, 1, "REG_DWORD"
If Err.Number <> 0 Then
    FailNow "Cannot temporarily enable VBA project access. Error " & Err.Number & ": " & Err.Description
End If
accessChanged = True
On Error GoTo 0

LogMsg "INFO", "Creating direct-hook Word global template."

On Error Resume Next
Err.Clear
Set wordApp = CreateObject("Word.Application")
If Err.Number <> 0 Then FailNow "Cannot start Word for add-in creation. Error " & Err.Number & ": " & Err.Description
wordApp.Visible = False
wordApp.DisplayAlerts = 0

Err.Clear
Set doc = wordApp.Documents.Add
If Err.Number <> 0 Then FailNow "Cannot create temporary Word document. Error " & Err.Number & ": " & Err.Description

Err.Clear
doc.SaveAs2 targetPath, wdFormatXMLTemplateMacroEnabled
If Err.Number <> 0 Then FailNow "Cannot create add-in file. Error " & Err.Number & ": " & Err.Description

Err.Clear
Set vbProj = doc.VBProject
If Err.Number <> 0 Then FailNow "Cannot access new add-in VBA project. Error " & Err.Number & ": " & Err.Description

Set modMain = vbProj.VBComponents.Add(vbext_ct_StdModule)
If Err.Number <> 0 Then FailNow "Cannot create VBA module. Error " & Err.Number & ": " & Err.Description

modMain.Name = "WBMathTypeHook"
modMain.CodeModule.AddFromString BuildMainModuleCode()
If Err.Number <> 0 Then FailNow "Cannot write VBA hook code. Error " & Err.Number & ": " & Err.Description

Err.Clear
doc.Save
If Err.Number <> 0 Then FailNow "Cannot save completed add-in. Error " & Err.Number & ": " & Err.Description

Set modMain = Nothing
Set vbProj = Nothing

doc.Close False
Set doc = Nothing
wordApp.Quit
Set wordApp = Nothing
LogMsg "INFO", "Hidden Word Quit requested and COM references released."
On Error GoTo 0

If Not fso.FileExists(targetPath) Then
    FailNow "The wb add-in was not created: " & targetPath
End If

LogMsg "INFO", "Created wb add-in: " & targetPath
LogMsg "INFO", "Installed file size: " & CStr(fso.GetFile(targetPath).Size) & " bytes."

RestoreAccessVBOM
If Not restoreOK Then
    FailNow "The add-in was created, but AccessVBOM could not be restored."
End If

LogMsg "SUCCESS", "Stage 1 completed: wb global template created."
WScript.Quit 0

Sub RemoveOldAddins(ByVal folderPath)
    Dim folder, file, n, removeIt, paths(), count, i
    count = 0

    On Error Resume Next
    Set folder = fso.GetFolder(folderPath)
    If Err.Number <> 0 Then
        FailNow "Cannot enumerate Word Startup folder. Error " & Err.Number & ": " & Err.Description
    End If
    On Error GoTo 0

    For Each file In folder.Files
        n = LCase(file.Name)
        removeIt = False

        If n = "mathtypewhitebackground.dotm" Then removeIt = True
        If n = "wb_mathtypewhitebackground.dotm" Then removeIt = True
        If InStr(1, n, "wb_mathtypewhitebackground_", vbTextCompare) = 1 And Right(n, 5) = ".dotm" Then removeIt = True
        If InStr(1, n, "mathtypewhitebackground_", vbTextCompare) = 1 And Right(n, 5) = ".dotm" Then removeIt = True

        If removeIt Then
            ReDim Preserve paths(count)
            paths(count) = file.Path
            count = count + 1
        End If
    Next

    For i = 0 To count - 1
        On Error Resume Next
        Err.Clear
        fso.DeleteFile paths(i), True
        If Err.Number <> 0 Then
            FailNow "Cannot remove old add-in: " & paths(i) & ". Error " & Err.Number & ": " & Err.Description
        Else
            LogMsg "INFO", "Removed old add-in: " & paths(i)
        End If
        On Error GoTo 0
    Next
End Sub

Sub RestoreAccessVBOM()
    If Not accessChanged Then Exit Sub

    On Error Resume Next
    Err.Clear
    If accessExisted Then
        sh.RegWrite accessPath, oldAccessValue, "REG_DWORD"
        If Err.Number <> 0 Then
            restoreOK = False
            LogMsg "ERROR", "Failed to restore AccessVBOM. Error " & Err.Number & ": " & Err.Description
            Err.Clear
        Else
            LogMsg "INFO", "Restored original AccessVBOM value."
        End If
    Else
        sh.RegDelete accessPath
        If Err.Number <> 0 Then
            restoreOK = False
            LogMsg "ERROR", "Failed to remove temporary AccessVBOM value. Error " & Err.Number & ": " & Err.Description
            Err.Clear
        Else
            LogMsg "INFO", "Removed temporary AccessVBOM value."
        End If
    End If
    accessChanged = False
    On Error GoTo 0
End Sub

Sub FailNow(ByVal message)
    On Error Resume Next
    LogMsg "ERROR", message

    If IsObject(modMain) Then Set modMain = Nothing
    If IsObject(vbProj) Then Set vbProj = Nothing

    If IsObject(doc) Then
        Err.Clear
        doc.Close False
        Set doc = Nothing
    End If

    If IsObject(wordApp) Then
        Err.Clear
        wordApp.Quit
        Set wordApp = Nothing
    End If

    If IsObject(probe) Then
        Err.Clear
        probe.Quit
        Set probe = Nothing
    End If

    RestoreAccessVBOM
    LogMsg "ERROR", "Install log retained: " & logPath
    WScript.Quit 1
End Sub

Function TimeStamp()
    TimeStamp = Year(Now) & "-" & Right("0" & Month(Now), 2) & "-" & Right("0" & Day(Now), 2) & " " & _
                Right("0" & Hour(Now), 2) & ":" & Right("0" & Minute(Now), 2) & ":" & Right("0" & Second(Now), 2)
End Function

Sub LogMsg(ByVal level, ByVal message)
    Dim line, f
    line = TimeStamp() & " [" & level & "] " & message
    WScript.Echo line
    On Error Resume Next
    Set f = fso.OpenTextFile(logPath, 8, True, -1)
    If Err.Number = 0 Then
        f.WriteLine line
        f.Close
    Else
        Err.Clear
    End If
    Set f = Nothing
    On Error GoTo 0
End Sub

Sub AddCodeLine(ByRef s, ByVal lineText)
    s = s & lineText & vbCrLf
End Sub

Function BuildMainModuleCode()
    Dim s
    s = ""

    AddCodeLine s, "Option Explicit"
    AddCodeLine s, ""
    AddCodeLine s, "Public Const WB_VERSION As String = ""0.0.13"""
    AddCodeLine s, "Private gWBBusy As Boolean"
    AddCodeLine s, ""
    AddCodeLine s, "Public Function WB_SelfTest() As String"
    AddCodeLine s, "    WB_SelfTest = WB_VERSION"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_MT_OnInsertInlineEqn(ByVal control As Office.IRibbonControl)"
    AddCodeLine s, "    WB_InsertAndPaint ""MTCommand_InsertInlineEqn"""
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_MT_OnInsertDispEqn(ByVal control As Office.IRibbonControl)"
    AddCodeLine s, "    WB_InsertAndPaint ""MTCommand_InsertDispEqn"""
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_MT_OnInsertRightNumberedDispEqn(ByVal control As Office.IRibbonControl)"
    AddCodeLine s, "    WB_InsertAndPaint ""MTCommand_InsertRightNumberedDispEqn"""
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub WB_InsertAndPaint(ByVal macroName As String)"
    AddCodeLine s, "    If gWBBusy Then Exit Sub"
    AddCodeLine s, "    gWBBusy = True"
    AddCodeLine s, "    On Error GoTo CleanExit"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim anchor As Long"
    AddCodeLine s, "    anchor = Selection.Start"
    AddCodeLine s, ""
    AddCodeLine s, "    If WB_RunMathTypeMacro(macroName) Then"
    AddCodeLine s, "        WB_PaintLocalEquation anchor"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "CleanExit:"
    AddCodeLine s, "    gWBBusy = False"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_RunMathTypeMacro(ByVal macroName As String) As Boolean"
    AddCodeLine s, "    On Error GoTo Failed"
    AddCodeLine s, "    Application.Run MacroName:=macroName"
    AddCodeLine s, "    WB_RunMathTypeMacro = True"
    AddCodeLine s, "    Exit Function"
    AddCodeLine s, ""
    AddCodeLine s, "Failed:"
    AddCodeLine s, "    WB_RunMathTypeMacro = False"
    AddCodeLine s, "    MsgBox ""Could not run MathType macro: "" & macroName & vbCrLf & ""Error "" & CStr(Err.Number) & "": "" & Err.Description, vbExclamation, ""wb MathType"""
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub WB_PaintLocalEquation(ByVal anchor As Long)"
    AddCodeLine s, "    On Error GoTo Done"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim sel As Selection"
    AddCodeLine s, "    Dim selR As Range"
    AddCodeLine s, "    Dim ils As InlineShape"
    AddCodeLine s, "    Dim p As Range"
    AddCodeLine s, "    Dim q As Range"
    AddCodeLine s, "    Dim localR As Range"
    AddCodeLine s, "    Set sel = Application.Selection"
    AddCodeLine s, "    Set selR = sel.Range"
    AddCodeLine s, ""
    AddCodeLine s, "    ' Fast path: Word often returns with the new MathType OLE selected."
    AddCodeLine s, "    If sel.Type = wdSelectionInlineShape Then"
    AddCodeLine s, "        On Error Resume Next"
    AddCodeLine s, "        Set ils = selR.InlineShapes(1)"
    AddCodeLine s, "        Err.Clear"
    AddCodeLine s, "        On Error GoTo Done"
    AddCodeLine s, "        If Not ils Is Nothing Then"
    AddCodeLine s, "            If WB_IsMathTypeInline(ils) Then"
    AddCodeLine s, "                WB_ApplyWhiteBackground ils"
    AddCodeLine s, "                Exit Sub"
    AddCodeLine s, "            End If"
    AddCodeLine s, "        End If"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    ' Fallback: one small range covering the current paragraph and its neighbors."
    AddCodeLine s, "    Set p = selR.Paragraphs(1).Range"
    AddCodeLine s, "    Set localR = p.Duplicate"
    AddCodeLine s, ""
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    Set q = p.Previous(wdParagraph, 1)"
    AddCodeLine s, "    If Not q Is Nothing Then localR.SetRange Start:=q.Start, End:=localR.End"
    AddCodeLine s, "    Set q = Nothing"
    AddCodeLine s, "    Set q = p.Next(wdParagraph, 1)"
    AddCodeLine s, "    If Not q Is Nothing Then localR.SetRange Start:=localR.Start, End:=q.End"
    AddCodeLine s, "    Err.Clear"
    AddCodeLine s, "    On Error GoTo Done"
    AddCodeLine s, ""
    AddCodeLine s, "    Set ils = WB_FindNearestMathType(localR, anchor)"
    AddCodeLine s, "    If Not ils Is Nothing Then WB_ApplyWhiteBackground ils"
    AddCodeLine s, ""
    AddCodeLine s, "Done:"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_FindNearestMathType(ByVal r As Range, ByVal anchor As Long) As InlineShape"
    AddCodeLine s, "    On Error GoTo Done"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim ils As InlineShape"
    AddCodeLine s, "    Dim best As InlineShape"
    AddCodeLine s, "    Dim t As Long"
    AddCodeLine s, "    Dim d As Long"
    AddCodeLine s, "    Dim bestD As Long"
    AddCodeLine s, "    bestD = 2147483647"
    AddCodeLine s, ""
    AddCodeLine s, "    For Each ils In r.InlineShapes"
    AddCodeLine s, "        t = ils.Type"
    AddCodeLine s, "        If t = wdInlineShapeEmbeddedOLEObject Or t = wdInlineShapeLinkedOLEObject Then"
    AddCodeLine s, "            d = Abs(ils.Range.Start - anchor)"
    AddCodeLine s, "            If d < bestD Then"
    AddCodeLine s, "                If WB_HasMathTypeProgID(ils) Then"
    AddCodeLine s, "                    bestD = d"
    AddCodeLine s, "                    Set best = ils"
    AddCodeLine s, "                    If bestD = 0 Then Exit For"
    AddCodeLine s, "                End If"
    AddCodeLine s, "            End If"
    AddCodeLine s, "        End If"
    AddCodeLine s, "    Next ils"
    AddCodeLine s, ""
    AddCodeLine s, "    Set WB_FindNearestMathType = best"
    AddCodeLine s, "Done:"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_IsMathTypeInline(ByVal ils As InlineShape) As Boolean"
    AddCodeLine s, "    On Error GoTo Nope"
    AddCodeLine s, "    Dim t As Long"
    AddCodeLine s, "    t = ils.Type"
    AddCodeLine s, "    If t <> wdInlineShapeEmbeddedOLEObject And t <> wdInlineShapeLinkedOLEObject Then Exit Function"
    AddCodeLine s, "    WB_IsMathTypeInline = WB_HasMathTypeProgID(ils)"
    AddCodeLine s, "    Exit Function"
    AddCodeLine s, "Nope:"
    AddCodeLine s, "    WB_IsMathTypeInline = False"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_HasMathTypeProgID(ByVal ils As InlineShape) As Boolean"
    AddCodeLine s, "    On Error GoTo Nope"
    AddCodeLine s, "    Dim prog As String"
    AddCodeLine s, "    prog = CStr(ils.OLEFormat.ProgID)"
    AddCodeLine s, "    If InStr(1, prog, ""Equation.DSMT"", vbTextCompare) > 0 Then"
    AddCodeLine s, "        WB_HasMathTypeProgID = True"
    AddCodeLine s, "        Exit Function"
    AddCodeLine s, "    End If"
    AddCodeLine s, "    WB_HasMathTypeProgID = (InStr(1, prog, ""MathType"", vbTextCompare) > 0)"
    AddCodeLine s, "    Exit Function"
    AddCodeLine s, "Nope:"
    AddCodeLine s, "    WB_HasMathTypeProgID = False"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub WB_ApplyWhiteBackground(ByVal ils As InlineShape)"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim needsShading As Boolean"
    AddCodeLine s, "    With ils.Range.Shading"
    AddCodeLine s, "        needsShading = (.Texture <> wdTextureNone)"
    AddCodeLine s, "        If Not needsShading Then needsShading = (.BackgroundPatternColor <> wdColorWhite)"
    AddCodeLine s, "        If needsShading Then"
    AddCodeLine s, "            .Texture = wdTextureNone"
    AddCodeLine s, "            .ForegroundPatternColor = wdColorAutomatic"
    AddCodeLine s, "            .BackgroundPatternColor = wdColorWhite"
    AddCodeLine s, "        End If"
    AddCodeLine s, "    End With"
    AddCodeLine s, ""
    AddCodeLine s, "    Err.Clear"
    AddCodeLine s, "    Dim f As Object"
    AddCodeLine s, "    Dim needsFill As Boolean"
    AddCodeLine s, "    Set f = ils.Fill"
    AddCodeLine s, "    If Err.Number <> 0 Then"
    AddCodeLine s, "        Err.Clear"
    AddCodeLine s, "        Exit Sub"
    AddCodeLine s, "    End If"
    AddCodeLine s, "    If f Is Nothing Then Exit Sub"
    AddCodeLine s, ""
    AddCodeLine s, "    If f.Visible <> msoTrue Then"
    AddCodeLine s, "        needsFill = True"
    AddCodeLine s, "    ElseIf f.ForeColor.RGB <> RGB(255,255,255) Then"
    AddCodeLine s, "        needsFill = True"
    AddCodeLine s, "    ElseIf Abs(f.Transparency) > 0.0001 Then"
    AddCodeLine s, "        needsFill = True"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    If Err.Number <> 0 Then"
    AddCodeLine s, "        Err.Clear"
    AddCodeLine s, "        needsFill = True"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    If needsFill Then"
    AddCodeLine s, "        f.Visible = msoTrue"
    AddCodeLine s, "        f.Solid"
    AddCodeLine s, "        f.ForeColor.RGB = RGB(255,255,255)"
    AddCodeLine s, "        f.Transparency = 0"
    AddCodeLine s, "    End If"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    BuildMainModuleCode = s
End Function
:__WB_VBS_END__

:__WB_PS_PAYLOAD__
param(
    [ValidateSet('install','restore','prepare-switch')][string]$Mode,
    [string]$LogFile,
    [string]$StartupPathFile
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$target = $null
$backup = $null
$wordStartup = $null
$wordInstallDir = $null
$wbAddin = $null
$wbIconRoot = Join-Path $env:APPDATA 'wb_MathTypeWhiteBackground'
$tmp = $null

function Log([string]$Level,[string]$Message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding Unicode
}

function Word-IsRunning {
    return @(Get-Process WINWORD -ErrorAction SilentlyContinue).Count -gt 0
}

function Resolve-WbWordPaths {
    if (-not [string]::IsNullOrWhiteSpace($StartupPathFile) -and (Test-Path -LiteralPath $StartupPathFile)) {
        try {
            $lines = @(Get-Content -LiteralPath $StartupPathFile -Encoding Unicode)
            if ($lines.Count -ge 1 -and -not [string]::IsNullOrWhiteSpace([string]$lines[0])) {
                $script:wordStartup = ([string]$lines[0]).Trim()
            }
            if ($lines.Count -ge 2 -and -not [string]::IsNullOrWhiteSpace([string]$lines[1])) {
                $script:wordInstallDir = ([string]$lines[1]).Trim()
            }
        } catch {
            Log 'WARN' "Could not read Stage 1 Word path file: $($_.Exception.Message)"
        }
    }
    if ([string]::IsNullOrWhiteSpace($script:wordStartup) -or [string]::IsNullOrWhiteSpace($script:wordInstallDir)) {
        $word = $null
        try {
            $word = New-Object -ComObject Word.Application
            if ([string]::IsNullOrWhiteSpace($script:wordStartup)) {
                $script:wordStartup = ([string]$word.Options.DefaultFilePath(8)).Trim()
            }
            if ([string]::IsNullOrWhiteSpace($script:wordInstallDir)) {
                $script:wordInstallDir = ([string]$word.Path).Trim()
            }
        } catch {
            Log 'WARN' "Could not query Word paths through COM: $($_.Exception.Message)"
        } finally {
            if ($null -ne $word) {
                try { $word.Quit() } catch {}
                try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) } catch {}
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($script:wordStartup)) {
        $script:wordStartup = Join-Path $env:APPDATA 'Microsoft\Word\STARTUP'
        Log 'WARN' "Using fallback Word Startup path: $script:wordStartup"
    }

    $script:wbAddin = Join-Path $script:wordStartup 'wb_MathTypeWhiteBackground.dotm'
    Log 'INFO' "Word Startup path: $script:wordStartup"
    if (-not [string]::IsNullOrWhiteSpace($script:wordInstallDir)) {
        Log 'INFO' "Word application path: $script:wordInstallDir"
    }
}

function Add-WbRoot([System.Collections.Generic.List[string]]$Roots,[string]$Path) {
    if (-not [string]::IsNullOrWhiteSpace($Path)) { $Roots.Add($Path) }
}

function Get-WbMathTypeSearchRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    Add-WbRoot $roots $wordStartup
    if (-not [string]::IsNullOrWhiteSpace($wordInstallDir)) {
        Add-WbRoot $roots (Join-Path $wordInstallDir 'STARTUP')
    }
    Add-WbRoot $roots (Join-Path $env:APPDATA 'Microsoft\Word\STARTUP')

    # Word COM is the primary source. Registry and Program Files enumeration are fallbacks
    # so this also works with Click-to-Run, MSI, 32-bit Office, and future OfficeXX folders.
    foreach ($regPath in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\WINWORD.EXE'
    )) {
        try {
            $exe = [string](Get-ItemPropertyValue -LiteralPath $regPath -Name '(default)' -ErrorAction Stop)
            if (-not [string]::IsNullOrWhiteSpace($exe)) {
                Add-WbRoot $roots (Join-Path ([IO.Path]::GetDirectoryName($exe)) 'STARTUP')
            }
        } catch {}
    }

    foreach ($base in @($env:ProgramFiles, [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'))) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }
        foreach ($officeBase in @((Join-Path $base 'Microsoft Office\Root'),(Join-Path $base 'Microsoft Office'))) {
            if (-not (Test-Path -LiteralPath $officeBase)) { continue }
            Get-ChildItem -LiteralPath $officeBase -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer -and $_.Name -like 'Office*' } | ForEach-Object {
                Add-WbRoot $roots (Join-Path $_.FullName 'STARTUP')
            }
        }
    }

    $seen = @{}
    foreach ($r in $roots) {
        if ([string]::IsNullOrWhiteSpace($r)) { continue }
        $full = $r
        try { $full = [IO.Path]::GetFullPath($r) } catch {}
        $key = $full.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $full
        }
    }
}

function Get-WbMathTypeCandidates {
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($root in Get-WbMathTypeSearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Filter 'MathType Commands*.dotm' -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            $items.Add($_.FullName)
        }
    }

    $items | Sort-Object `
        @{Expression={ if ([IO.Path]::GetFileName($_) -ieq 'MathType Commands 6 For Word 2016.dotm') { 0 } else { 1 } }}, `
        @{Expression={ $_ }} -Unique
}

function Get-WbBackupCandidates {
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($root in Get-WbMathTypeSearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Filter 'MathType Commands*.dotm.wb_original' -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            $items.Add($_.FullName)
        }
    }
    $items | Sort-Object -Unique
}

function Test-WbCompatibleMathTypeTemplate([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            if ($null -eq $zip.GetEntry('word/vbaProject.bin')) { return $false }
            $original = @(
                'onAction="MTCommand_OnInsertInlineEqn"',
                'onAction="MTCommand_OnInsertDispEqn"',
                'onAction="MTCommand_OnInsertRightNumberedDispEqn"'
            )
            $patched = @(
                'onAction="WBMathTypeHook.WB_MT_OnInsertInlineEqn"',
                'onAction="WBMathTypeHook.WB_MT_OnInsertDispEqn"',
                'onAction="WBMathTypeHook.WB_MT_OnInsertRightNumberedDispEqn"'
            )
            foreach ($entryName in @('customUI/customUI.xml','customUI/CustomUI14.xml')) {
                $e = $zip.GetEntry($entryName)
                if ($null -eq $e) { return $false }
                $s = $e.Open()
                try {
                    $reader = New-Object IO.StreamReader($s,[Text.Encoding]::UTF8,$true)
                    try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
                } finally { $s.Dispose() }
                if (-not $xml.Contains('<group id="MathType_G_Insert"')) { return $false }
                $originalOk = $true
                foreach ($x in $original) { if (-not $xml.Contains($x)) { $originalOk = $false; break } }
                $patchedOk = $true
                foreach ($x in $patched) { if (-not $xml.Contains($x)) { $patchedOk = $false; break } }
                if (-not $originalOk -and -not $patchedOk) { return $false }
            }
            return $true
        } finally { $zip.Dispose() }
    } catch { return $false }
}

function Find-WbCompatibleMathTypeTemplate {
    $foundAny = $false
    foreach ($candidate in Get-WbMathTypeCandidates) {
        $foundAny = $true
        if (Test-WbCompatibleMathTypeTemplate $candidate) {
            Log 'INFO' "Compatible MathType Word template found: $candidate"
            return $candidate
        }
        Log 'WARN' "MathType template found but its Ribbon structure is not compatible with the wb_v0.0.37 hook; leaving it unchanged: $candidate"
    }
    if (-not $foundAny) { Log 'INFO' 'No MathType Word template was found in the detected Word STARTUP locations.' }
    return $null
}

function Test-WbRibbonPatch([string]$Path) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entryName in @('customUI/customUI.xml','customUI/CustomUI14.xml')) {
            $e = $zip.GetEntry($entryName)
            if ($null -eq $e) { continue }
            $s = $e.Open()
            try {
                $reader = New-Object IO.StreamReader($s,[Text.Encoding]::UTF8,$true)
                try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
            } finally { $s.Dispose() }
            if ($xml.Contains('WBMathTypeHook.WB_MT_OnInsertRightNumberedDispEqn')) { return $true }
        }
        return $false
    } finally { $zip.Dispose() }
}

function Get-ZipEntryHash([string]$Path,[string]$EntryName) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $e = $zip.GetEntry($EntryName)
        if ($null -eq $e) { return $null }
        $s = $e.Open()
        try {
            $sha = [Security.Cryptography.SHA256]::Create()
            try {
                $h = $sha.ComputeHash($s)
                return ([BitConverter]::ToString($h)).Replace('-','')
            } finally { $sha.Dispose() }
        } finally { $s.Dispose() }
    } finally { $zip.Dispose() }
}

function Replace-ZipXml([string]$Path,[string]$EntryName,[hashtable]$Replacements) {
    $zip = [IO.Compression.ZipFile]::Open($Path,[IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $zip.GetEntry($EntryName)
        if ($null -eq $entry) { throw "Missing XML entry: $EntryName" }
        $stream = $entry.Open()
        try {
            $reader = New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true)
            try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally { $stream.Dispose() }
        foreach ($k in $Replacements.Keys) {
            if (-not $xml.Contains($k)) { throw "Expected callback text not found in ${EntryName}: $k" }
            $xml = $xml.Replace($k,$Replacements[$k])
        }
        $entry.Delete()
        $newEntry = $zip.CreateEntry($EntryName,[IO.Compression.CompressionLevel]::Optimal)
        $outStream = $newEntry.Open()
        try {
            $enc = New-Object Text.UTF8Encoding($false)
            $writer = New-Object IO.StreamWriter($outStream,$enc)
            try { $writer.Write($xml) } finally { $writer.Dispose() }
        } finally { $outStream.Dispose() }
    } finally { $zip.Dispose() }
}


function Get-WbInstalledVariantFromPackage([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $null }
    $zip = $null
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        $sawDirectHook = $false
        foreach ($entryName in @('customUI/customUI.xml','customUI/CustomUI14.xml')) {
            $entry = $zip.GetEntry($entryName)
            if ($null -eq $entry) { continue }
            $stream = $entry.Open()
            try {
                $reader = New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true)
                try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
            } finally { $stream.Dispose() }

            if ($xml -match 'WB_G_Background|WB_BG_|WBMathTypeHook\.WB_RibbonOnLoad|WBMathTypeHook\.WB_StandaloneRibbonOnLoad') {
                return 'ribbon'
            }
            if ($xml.Contains('WBMathTypeHook.WB_MT_OnInsertInlineEqn') -or
                $xml.Contains('WBMathTypeHook.WB_MT_OnInsertDispEqn') -or
                $xml.Contains('WBMathTypeHook.WB_MT_OnInsertRightNumberedDispEqn')) {
                $sawDirectHook = $true
            }
        }
        if ($sawDirectHook) { return 'no' }
        return $null
    }
    catch { return $null }
    finally { if ($null -ne $zip) { $zip.Dispose() } }
}

function Find-WbInstalledVariantInfo {
    # wb_v standalone installs expose their background Ribbon in the wb add-in package.
    $addinVariant = Get-WbInstalledVariantFromPackage $wbAddin
    if ($addinVariant -eq 'ribbon') {
        return [pscustomobject]@{ Variant='ribbon'; Target=$null; Source=$wbAddin }
    }

    foreach ($root in Get-WbMathTypeSearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Filter 'MathType Commands*.dotm' -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.PSIsContainer -or $_.Name.EndsWith('.wb_original',[StringComparison]::OrdinalIgnoreCase)) { return }
            $variant = Get-WbInstalledVariantFromPackage $_.FullName
            if (-not [string]::IsNullOrWhiteSpace($variant)) {
                $script:wbDetectedVariantInfo = [pscustomobject]@{ Variant=$variant; Target=$_.FullName; Source=$_.FullName }
            }
        }
        if ($null -ne $script:wbDetectedVariantInfo) { return $script:wbDetectedVariantInfo }
    }
    return $null
}

function Remove-WbInstalledVariant([string]$ExpectedVariant) {
    $script:wbDetectedVariantInfo = $null
    $info = Find-WbInstalledVariantInfo
    if ($null -eq $info -or $info.Variant -ne $ExpectedVariant) {
        Log 'INFO' "No conflicting $ExpectedVariant wb variant was detected."
        return
    }

    Log 'INFO' "Conflicting wb variant detected: $($info.Variant) at $($info.Source)"
    if (-not [string]::IsNullOrWhiteSpace([string]$info.Target)) {
        $restoreTarget = [string]$info.Target
        $restoreBackup = $restoreTarget + '.wb_original'
        if (-not (Test-Path -LiteralPath $restoreBackup)) {
            throw "Cannot switch wb variants safely because the pristine MathType backup is missing: $restoreBackup"
        }
        if ($null -ne (Get-WbInstalledVariantFromPackage $restoreBackup)) {
            throw "Cannot switch wb variants safely because the MathType backup is already patched: $restoreBackup"
        }
        $currentVba = Get-ZipEntryHash $restoreTarget 'word/vbaProject.bin'
        $backupVba = Get-ZipEntryHash $restoreBackup 'word/vbaProject.bin'
        if ([string]::IsNullOrWhiteSpace($currentVba) -or [string]::IsNullOrWhiteSpace($backupVba) -or $currentVba -ne $backupVba) {
            throw 'Cannot switch wb variants safely because the current MathType VBA project does not match the pristine backup.'
        }
        Copy-Item -LiteralPath $restoreBackup -Destination $restoreTarget -Force
        Log 'INFO' "Restored pristine MathType template before switching wb variants: $restoreTarget"
    }

    if (Test-Path -LiteralPath $wbAddin) {
        Remove-Item -LiteralPath $wbAddin -Force
        Log 'INFO' "Removed conflicting wb add-in: $wbAddin"
    }
    if (Test-Path -LiteralPath $wbIconRoot) {
        Remove-Item -LiteralPath $wbIconRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Log 'SUCCESS' "Conflicting $ExpectedVariant wb variant removed before installation."
}

try {
    Log 'INFO' "wb_no_v0.0.13 PowerShell stage started in mode: $Mode"

    if (Word-IsRunning) {
        throw 'Microsoft Word is currently running. Close every Word window first.'
    }

    Resolve-WbWordPaths

    if ($Mode -eq 'prepare-switch') {
        Remove-WbInstalledVariant 'ribbon'
        exit 0
    }

    if ($Mode -eq 'restore') {
        $restoreBackup = $null
        $restoreTarget = $null
        foreach ($candidateBackup in Get-WbBackupCandidates) {
            if (-not (Test-WbRibbonPatch $candidateBackup)) {
                $candidateTarget = $candidateBackup.Substring(0,$candidateBackup.Length - '.wb_original'.Length)
                if (Test-Path -LiteralPath $candidateTarget) {
                    $restoreBackup = $candidateBackup
                    $restoreTarget = $candidateTarget
                    break
                }
            }
        }
        if ($null -eq $restoreBackup) {
            throw 'Original MathType backup was not found in the detected Word STARTUP locations.'
        }
        Copy-Item -LiteralPath $restoreBackup -Destination $restoreTarget -Force
        if (Test-Path -LiteralPath $wbAddin) { Remove-Item -LiteralPath $wbAddin -Force }
        Log 'SUCCESS' 'Original MathType template restored.'
        Log 'INFO' "Restored from: $restoreBackup"
        Log 'INFO' 'wb MathType white-background add-in removed.'
        exit 0
    }

    $target = Find-WbCompatibleMathTypeTemplate
    if ([string]::IsNullOrWhiteSpace($target)) {
        $searched = (Get-WbMathTypeSearchRoots) -join '; '
        throw "No compatible MathType Word template was found. Searched: $searched"
    }
    $backup = $target + '.wb_original'

    if (-not (Test-Path -LiteralPath $wbAddin)) { throw "wb add-in was not created: $wbAddin" }

    $targetAlreadyPatched = Test-WbRibbonPatch $target
    if ($targetAlreadyPatched) {
        if (-not (Test-Path -LiteralPath $backup)) {
            throw 'The MathType template is already wb-patched, but the pristine backup is missing. Restore/reinstall MathType before continuing.'
        }
        if (Test-WbRibbonPatch $backup) {
            throw 'The saved MathType backup is not pristine. Refusing to use a patched file as the installation source.'
        }
        if (-not (Test-WbCompatibleMathTypeTemplate $backup)) {
            throw 'The saved MathType backup does not match the verified MathType Ribbon structure.'
        }
        $currentVba = Get-ZipEntryHash $target 'word/vbaProject.bin'
        $backupVbaCheck = Get-ZipEntryHash $backup 'word/vbaProject.bin'
        if ([string]::IsNullOrWhiteSpace($currentVba) -or [string]::IsNullOrWhiteSpace($backupVbaCheck) -or $currentVba -ne $backupVbaCheck) {
            throw 'The existing pristine backup does not match the current patched MathType VBA project. Refusing to overwrite a possibly newer MathType installation.'
        }
        Log 'INFO' "Current MathType template is already wb-patched; verified matching pristine backup: $backup"
    } else {
        Copy-Item -LiteralPath $target -Destination $backup -Force
        Log 'INFO' "Refreshed pristine MathType backup from the current unpatched template: $backup"
    }

    $leaf = [IO.Path]::GetFileNameWithoutExtension($target)
    $tmp = Join-Path $env:TEMP ($leaf + '.wb_no_v0.0.13.' + [Guid]::NewGuid().ToString('N') + '.dotm')
    Copy-Item -LiteralPath $backup -Destination $tmp -Force

    try {
        $attrs = [IO.File]::GetAttributes($tmp)
        if (($attrs -band [IO.FileAttributes]::ReadOnly) -ne 0) {
            [IO.File]::SetAttributes($tmp, $attrs -band (-bnot [IO.FileAttributes]::ReadOnly))
        }
    } catch { throw ("Could not make temporary MathType package writable: " + $_.Exception.Message) }

    try {
        $fs = [IO.File]::Open($tmp,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $fs.Dispose()
        Log 'INFO' 'Temporary MathType package passed read/write access test.'
    } catch { throw ("Temporary MathType package is still not writable: " + $_.Exception.Message) }

    $beforeVba = Get-ZipEntryHash $backup 'word/vbaProject.bin'
    $beforeSig = Get-ZipEntryHash $backup 'word/vbaProjectSignature.bin'
    $beforeSigAgile = Get-ZipEntryHash $backup 'word/vbaProjectSignatureAgile.bin'
    if ([string]::IsNullOrWhiteSpace($beforeVba)) { throw 'Original MathType vbaProject.bin could not be found.' }

    $repl = @{
        'onAction="MTCommand_OnInsertInlineEqn"' = 'onAction="WBMathTypeHook.WB_MT_OnInsertInlineEqn"'
        'onAction="MTCommand_OnInsertDispEqn"' = 'onAction="WBMathTypeHook.WB_MT_OnInsertDispEqn"'
        'onAction="MTCommand_OnInsertRightNumberedDispEqn"' = 'onAction="WBMathTypeHook.WB_MT_OnInsertRightNumberedDispEqn"'
    }
    foreach ($uiPart in @('customUI/customUI.xml','customUI/CustomUI14.xml')) {
        Log 'INFO' "Patching $uiPart."
        Replace-ZipXml $tmp $uiPart $repl
    }

    $afterVba = Get-ZipEntryHash $tmp 'word/vbaProject.bin'
    $afterSig = Get-ZipEntryHash $tmp 'word/vbaProjectSignature.bin'
    $afterSigAgile = Get-ZipEntryHash $tmp 'word/vbaProjectSignatureAgile.bin'
    if ($afterVba -ne $beforeVba) { throw 'Safety check failed: vbaProject.bin changed.' }
    if ($beforeSig -and $afterSig -ne $beforeSig) { throw 'Safety check failed: vbaProjectSignature.bin changed.' }
    if ($beforeSigAgile -and $afterSigAgile -ne $beforeSigAgile) { throw 'Safety check failed: vbaProjectSignatureAgile.bin changed.' }

    Log 'INFO' "Verified unchanged MathType VBA SHA-256: $beforeVba"
    Log 'INFO' 'Verified VBA signature streams are unchanged.'
    Copy-Item -LiteralPath $tmp -Destination $target -Force
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    $tmp = $null
    Log 'INFO' "Patched MathType template installed: $target"

    $word = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        Start-Sleep -Milliseconds 750
        $names = @()
        foreach ($t in $word.Templates) { $names += [string]$t.Name }
        $mathTypeLeaf = [IO.Path]::GetFileName($target)
        if (-not ($names -contains $mathTypeLeaf)) { throw "Patched MathType global template did not load: $mathTypeLeaf" }
        if (-not ($names -contains 'wb_MathTypeWhiteBackground.dotm')) { throw 'wb global template did not load.' }
        $ver = [string]$word.Run('WBMathTypeHook.WB_SelfTest')
        if ($ver -ne '0.0.13') { throw "wb hook self-test returned unexpected value: $ver" }
        Log 'INFO' 'Word startup self-test passed: the detected MathType template and WBMathTypeHook both loaded.'
    } finally {
        if ($null -ne $word) {
            try { $word.Quit() } catch {}
            try { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) } catch {}
        }
    }

    Log 'SUCCESS' 'Direct MathType Ribbon hook installed and verified.'
    exit 0
}
catch {
    Log 'ERROR' $_.Exception.Message
    if ($null -ne $tmp -and (Test-Path -LiteralPath $tmp)) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
    if ($Mode -eq 'install' -and $null -ne $backup -and $null -ne $target -and (Test-Path -LiteralPath $backup)) {
        try {
            Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Copy-Item -LiteralPath $backup -Destination $target -Force
            if ($null -ne $wbAddin -and (Test-Path -LiteralPath $wbAddin)) {
                Remove-Item -LiteralPath $wbAddin -Force -ErrorAction SilentlyContinue
            }
            Log 'WARN' 'Automatic rollback restored the original MathType template and removed the wb add-in.'
        } catch {
            Log 'ERROR' ('Automatic rollback failed: ' + $_.Exception.Message)
        }
    }
    exit 2
}
:__WB_PS_END__