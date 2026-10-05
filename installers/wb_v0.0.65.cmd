@echo off
setlocal EnableExtensions DisableDelayedExpansion
title wb_v0.0.65 - MathType White Background Direct Ribbon Hook

set "WB_SELF=%~f0"
set "WB_MODE=install"
if /I "%~1"=="restore" set "WB_MODE=restore"

if /I "%~2"=="--elevated" goto :ELEVATED

rem Minimize repeated Windows trust prompts.  A freshly downloaded CMD may carry
rem Mark-of-the-Web (Zone.Identifier).  The very first pre-execution warning cannot
rem be removed by code that has not run yet, but once allowed, remove the mark from
rem the original file so later runs normally require only the real UAC consent.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Unblock-File -LiteralPath $env:WB_SELF -ErrorAction SilentlyContinue } catch {}" >nul 2>&1

rem UAC boundary isolation for OneDrive and other synchronized folders.
rem The original installer remains in place; only a temporary local copy is elevated.
set "WB_BOOT_LOG=%TEMP%\wb_v0.0.65_bootstrap_log.txt"
>"%WB_BOOT_LOG%" echo wb_v0.0.65 bootstrap started: %DATE% %TIME%
>>"%WB_BOOT_LOG%" echo Original script: %WB_SELF%
>>"%WB_BOOT_LOG%" echo Mode: %WB_MODE%

set "WB_STAGE_DIR=%TEMP%\wb_v0.0.65_stage_%RANDOM%_%RANDOM%"
set "WB_STAGE_SELF=%WB_STAGE_DIR%\wb_v0.0.65.cmd"
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

rem Elevated child finished; remove only the temporary launcher copy.
rd /s /q "%WB_STAGE_DIR%" >nul 2>&1

if "%WB_BOOT_RC%"=="0" (
    del /q "%WB_BOOT_LOG%" >nul 2>&1
    exit /b 0
)

>>"%WB_BOOT_LOG%" echo UAC/child installer returned error code %WB_BOOT_RC%.
echo.
echo [ERROR] The elevated installer could not be started or it returned an error.
echo [ERROR] Error code: %WB_BOOT_RC%
echo [ERROR] Bootstrap log: %WB_BOOT_LOG%
echo.
pause
exit /b %WB_BOOT_RC%

:ELEVATED
set "WB_VBS=%TEMP%\wb_v0.0.65_%RANDOM%_%RANDOM%.vbs"
set "WB_PS=%TEMP%\wb_v0.0.65_%RANDOM%_%RANDOM%.ps1"
set "WB_STARTUP_INFO=%TEMP%\wb_v0.0.65_%RANDOM%_%RANDOM%_startup.txt"
set "WB_LOG=%TEMP%\wb_v0.0.65_install_log.txt"

rem Word must not hold the global templates open while installing or restoring.
rem The user requested silent forced closure: no prompt and no polling/wait loop.
taskkill.exe /F /IM WINWORD.EXE >nul 2>&1

echo [INFO] wb_v0.0.65 %WB_MODE% started.
echo [INFO] A compatible MathType Ribbon is hooked directly; if none is found, a standalone wb Ribbon is installed.
echo [INFO] One lightweight WindowSelectionChange handler is installed; no timer, polling, or document scan is used.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop'; " ^
  "$lines=Get-Content -LiteralPath $env:WB_SELF; " ^
  "$v1=[Array]::IndexOf($lines, ':__WB_VBS_PAYLOAD__'); $v2=[Array]::IndexOf($lines, ':__WB_VBS_END__'); " ^
  "$p1=[Array]::IndexOf($lines, ':__WB_PS_PAYLOAD__'); $p2=[Array]::IndexOf($lines, ':__WB_PS_END__'); " ^
  "if($v1 -lt 0 -or $v2 -le $v1 -or $p1 -lt 0 -or $p2 -le $p1){throw 'Embedded payload markers not found.'}; " ^
  "if($env:WB_MODE -ne 'restore'){ $lines[($v1+1)..($v2-1)] | Set-Content -LiteralPath $env:WB_VBS -Encoding Unicode }; " ^
  "$lines[($p1+1)..($p2-1)] | Set-Content -LiteralPath $env:WB_PS -Encoding ASCII"

if errorlevel 1 (
    echo [ERROR] Failed to prepare installer payloads.
    pause
    exit /b 91
)

if /I "%WB_MODE%"=="restore" goto :RESTORE

echo [INFO] Checking for an installed wb_no variant before installing wb_v...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode prepare-switch -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED
rem The prepare-switch check may query Word through COM; make sure no hidden Word remains.
taskkill.exe /F /IM WINWORD.EXE >nul 2>&1

echo [INFO] Stage 1/2: creating the wb Word global add-in...
cscript.exe //nologo "%WB_VBS%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED

rem Close any hidden WINWORD process left behind by the COM creation step.
taskkill.exe /F /IM WINWORD.EXE >nul 2>&1

echo.
echo [INFO] Stage 2/2: detecting a compatible MathType Ribbon or installing the standalone fallback...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode install -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED

echo.
echo [SUCCESS] wb_v0.0.65 installed successfully.
echo [INFO] If a compatible MathType Ribbon was found, only its Ribbon XML was patched; MathType VBA was not modified.
echo [INFO] If no compatible MathType Ribbon was found, the wb background Ribbon was installed standalone.
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
echo [INFO] Restore selected. Restoring the original MathType state and removing the wb add-in...
taskkill.exe /F /IM WINWORD.EXE >nul 2>&1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode restore -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED

del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" >nul 2>&1
del /q "%WB_LOG%" >nul 2>&1
echo.
echo [SUCCESS] Restore completed and wb add-in removed.
timeout /t 3 /nobreak >nul
exit /b 0

:KEEP_INSTALLATION
del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" >nul 2>&1
del /q "%WB_LOG%" >nul 2>&1
echo.
echo [INFO] Keeping the installation. Closing installer.
exit /b 0

:RESTORE
echo [INFO] Restoring the original MathType template and removing the wb add-in...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WB_PS%" -Mode restore -LogFile "%WB_LOG%" -StartupPathFile "%WB_STARTUP_INFO%"
set "WB_RC=%ERRORLEVEL%"
if not "%WB_RC%"=="0" goto :FAILED

del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" >nul 2>&1
del /q "%WB_LOG%" >nul 2>&1

echo.
echo [SUCCESS] Restore completed and wb add-in removed.
echo.
pause
exit /b 0

:FAILED
del /q "%WB_VBS%" "%WB_PS%" "%WB_STARTUP_INFO%" >nul 2>&1
echo.
echo [ERROR] Operation failed. Error code: %WB_RC%
echo [ERROR] Detailed log retained at:
echo [ERROR] %WB_LOG%
echo.
pause
exit /b %WB_RC%

:__WB_VBS_PAYLOAD__
Option Explicit

Const INSTALLER_NAME = "wb_v0.0.65"
Const ADDIN_FILE = "wb_MathTypeWhiteBackground.dotm"
Const wdStartupPath = 8
Const wdFormatXMLTemplateMacroEnabled = 15
Const vbext_ct_StdModule = 1
Const vbext_ct_ClassModule = 2

Dim fso, sh, logPath
Dim restoreOK
Dim accessPath, accessExisted, oldAccessValue, accessChanged
Dim wordVersion, startupPath, wordInstallPath, targetPath
Dim startupInfoPath, startupInfo
Dim probe, wordApp, doc, vbProj, modMain, modEvents

Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
logPath = sh.ExpandEnvironmentStrings("%WB_LOG%")

On Error Resume Next
If fso.FileExists(logPath) Then fso.DeleteFile logPath, True
On Error GoTo 0

restoreOK = True

LogMsg "INFO", "Installer started: " & INSTALLER_NAME
LogMsg "INFO", "Runtime design: direct MathType Ribbon XML hook plus one lightweight WindowSelectionChange handler. Normal selection changes exit immediately unless one InlineShape is selected; no timer, polling, paragraph scan, or document scan."
LogMsg "INFO", "Word processes were force-closed by the elevated launcher before Stage 1."
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
        LogMsg "INFO", "Recorded Word Startup path for Stage 2."
    Else
        LogMsg "WARN", "Could not record Word Startup path for Stage 2. Error " & Err.Number & ": " & Err.Description
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
Set modEvents = vbProj.VBComponents.Add(vbext_ct_ClassModule)
If Err.Number <> 0 Then FailNow "Cannot create VBA application-event class. Error " & Err.Number & ": " & Err.Description
modEvents.Name = "WBAppEvents"
modEvents.CodeModule.AddFromString BuildEventClassCode()
If Err.Number <> 0 Then FailNow "Cannot write VBA application-event code. Error " & Err.Number & ": " & Err.Description

Err.Clear
doc.Save
If Err.Number <> 0 Then FailNow "Cannot save completed add-in. Error " & Err.Number & ": " & Err.Description

Set modEvents = Nothing
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

    If IsObject(modEvents) Then Set modEvents = Nothing
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
    AddCodeLine s, "Public Const WB_VERSION As String = ""0.0.65"""
    AddCodeLine s, "Private gWBBusy As Boolean"
    AddCodeLine s, "Private gWBColorIndex As Long"
    AddCodeLine s, "Private gWBShadeIndex As Long"
    AddCodeLine s, "Private gWBRibbon As Office.IRibbonUI"
    AddCodeLine s, "Private gWBEvents As WBAppEvents"
    AddCodeLine s, ""
    AddCodeLine s, "Public Function WB_SelfTest() As String"
    AddCodeLine s, "    WB_SelfTest = WB_VERSION"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub AutoExec()"
    AddCodeLine s, "    WB_EnsureAppEvents"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_EnsureAppEvents()"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    If gWBEvents Is Nothing Then Set gWBEvents = New WBAppEvents"
    AddCodeLine s, "    Set gWBEvents.App = Application"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_RibbonOnLoad(ByVal ribbon As Office.IRibbonUI)"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    WB_EnsureAppEvents"
    AddCodeLine s, "    Set gWBRibbon = ribbon"
    AddCodeLine s, "    WB_RunOriginalRibbonLoaded ribbon"
    AddCodeLine s, "    Err.Clear"
    AddCodeLine s, "    WB_BG_RefreshShadeControls"
    AddCodeLine s, "    WB_BG_RefreshColorControl"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_StandaloneRibbonOnLoad(ByVal ribbon As Office.IRibbonUI)"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    WB_EnsureAppEvents"
    AddCodeLine s, "    Set gWBRibbon = ribbon"
    AddCodeLine s, "    WB_BG_RefreshShadeControls"
    AddCodeLine s, "    WB_BG_RefreshColorControl"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub WB_RunOriginalRibbonLoaded(ByVal ribbon As Office.IRibbonUI)"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    Dim t As Template"
    AddCodeLine s, "    Dim callName As String"
    AddCodeLine s, ""
    AddCodeLine s, "    For Each t In Application.Templates"
    AddCodeLine s, "        If InStr(1, t.Name, ""MathType Commands"", vbTextCompare) > 0 Then"
    AddCodeLine s, "            callName = ""'"" & t.Name & ""'!MTCommand_OnRibbonLoaded"""
    AddCodeLine s, "            Err.Clear"
    AddCodeLine s, "            Application.Run callName, ribbon"
    AddCodeLine s, "            If Err.Number = 0 Then Exit Sub"
    AddCodeLine s, "        End If"
    AddCodeLine s, "    Next t"
    AddCodeLine s, ""
    AddCodeLine s, "    Err.Clear"
    AddCodeLine s, "    Application.Run ""MTCommand_OnRibbonLoaded"", ribbon"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_BG_UseTraditionalChineseUI() As Boolean"
    AddCodeLine s, "    On Error GoTo Fallback"
    AddCodeLine s, "    Dim lcid As Long"
    AddCodeLine s, "    lcid = CLng(Application.Language)"
    AddCodeLine s, "    Select Case lcid"
    AddCodeLine s, "        Case 1028, 2052, 3076, 4100, 5124"
    AddCodeLine s, "            WB_BG_UseTraditionalChineseUI = True"
    AddCodeLine s, "        Case Else"
    AddCodeLine s, "            WB_BG_UseTraditionalChineseUI = False"
    AddCodeLine s, "    End Select"
    AddCodeLine s, "    Exit Function"
    AddCodeLine s, "Fallback:"
    AddCodeLine s, "    Err.Clear"
    AddCodeLine s, "    WB_BG_UseTraditionalChineseUI = False"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_GetChineseVisible(ByVal control As Office.IRibbonControl, ByRef returnedVal)"
    AddCodeLine s, "    returnedVal = WB_BG_UseTraditionalChineseUI()"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_GetEnglishVisible(ByVal control As Office.IRibbonControl, ByRef returnedVal)"
    AddCodeLine s, "    returnedVal = Not WB_BG_UseTraditionalChineseUI()"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_GetColorIndex(ByVal control As Office.IRibbonControl, ByRef returnedVal)"
    AddCodeLine s, "    If gWBColorIndex < 0 Or gWBColorIndex > 7 Then gWBColorIndex = 0"
    AddCodeLine s, "    returnedVal = gWBColorIndex"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_GetColorPreviewImage(ByVal control As Office.IRibbonControl, ByRef returnedVal)"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    Dim shade As Long"
    AddCodeLine s, "    shade = gWBShadeIndex"
    AddCodeLine s, "    If shade < 0 Or shade > 2 Then shade = 1"
    AddCodeLine s, "    Set returnedVal = LoadPicture(WB_BG_IconPath(""preview_c"" & CStr(gWBColorIndex) & ""_s"" & CStr(shade) & "".bmp""))"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_GetShadeImage(ByVal control As Office.IRibbonControl, ByRef returnedVal)"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    Dim shade As Long"
    AddCodeLine s, "    Dim fn As String"
    AddCodeLine s, "    Select Case control.ID"
    AddCodeLine s, "        Case ""WB_B_ShadeLight"", ""WB_B_ShadeLight_ZH"": shade = 0"
    AddCodeLine s, "        Case ""WB_B_ShadeMedium"", ""WB_B_ShadeMedium_ZH"": shade = 1"
    AddCodeLine s, "        Case ""WB_B_ShadeDark"", ""WB_B_ShadeDark_ZH"": shade = 2"
    AddCodeLine s, "        Case Else: shade = 1"
    AddCodeLine s, "    End Select"
    AddCodeLine s, "    If gWBColorIndex >= 1 And gWBColorIndex <= 6 Then"
    AddCodeLine s, "        fn = ""shade_c"" & CStr(gWBColorIndex) & ""_s"" & CStr(shade) & "".bmp"""
    AddCodeLine s, "    Else"
    AddCodeLine s, "        fn = ""shade_neutral_s"" & CStr(shade) & "".bmp"""
    AddCodeLine s, "    End If"
    AddCodeLine s, "    Set returnedVal = LoadPicture(WB_BG_IconPath(fn))"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_BG_IconPath(ByVal fileName As String) As String"
    AddCodeLine s, "    WB_BG_IconPath = Environ$(""APPDATA"") & ""\wb_MathTypeWhiteBackground\icons\"" & fileName"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_ColorHeader(ByVal control As Office.IRibbonControl)"
    AddCodeLine s, "    ' Visual heading button only; color selection is handled by the adjacent drop-down."
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_OnColorChanged(ByVal control As Office.IRibbonControl, ByVal selectedId As String, ByVal selectedIndex As Integer)"
    AddCodeLine s, "    Select Case selectedId"
    AddCodeLine s, "        Case ""WB_Color_White"", ""WB_Color_White_ZH"": gWBColorIndex = 0"
    AddCodeLine s, "        Case ""WB_Color_Gray"", ""WB_Color_Gray_ZH"": gWBColorIndex = 1"
    AddCodeLine s, "        Case ""WB_Color_Beige"", ""WB_Color_Beige_ZH"": gWBColorIndex = 2"
    AddCodeLine s, "        Case ""WB_Color_Yellow"", ""WB_Color_Yellow_ZH"": gWBColorIndex = 3"
    AddCodeLine s, "        Case ""WB_Color_Blue"", ""WB_Color_Blue_ZH"": gWBColorIndex = 4"
    AddCodeLine s, "        Case ""WB_Color_Green"", ""WB_Color_Green_ZH"": gWBColorIndex = 5"
    AddCodeLine s, "        Case ""WB_Color_Pink"", ""WB_Color_Pink_ZH"": gWBColorIndex = 6"
    AddCodeLine s, "        Case ""WB_Color_None"", ""WB_Color_None_ZH"": gWBColorIndex = 7"
    AddCodeLine s, "        Case Else"
    AddCodeLine s, "            If selectedIndex >= 0 And selectedIndex <= 7 Then gWBColorIndex = selectedIndex"
    AddCodeLine s, "    End Select"
    AddCodeLine s, "    WB_BG_RefreshShadeControls"
    AddCodeLine s, "    WB_BG_RefreshColorControl"
    AddCodeLine s, "    WB_BG_ApplyToCurrentSelection"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_GetShadeEnabled(ByVal control As Office.IRibbonControl, ByRef returnedVal)"
    AddCodeLine s, "    returnedVal = (gWBColorIndex <> 0 And gWBColorIndex <> 7)"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_GetShadePressed(ByVal control As Office.IRibbonControl, ByRef returnedVal)"
    AddCodeLine s, "    If gWBColorIndex = 0 Or gWBColorIndex = 7 Then"
    AddCodeLine s, "        returnedVal = False"
    AddCodeLine s, "        Exit Sub"
    AddCodeLine s, "    End If"
    AddCodeLine s, "    Select Case control.ID"
    AddCodeLine s, "        Case ""WB_B_ShadeLight"", ""WB_B_ShadeLight_ZH"": returnedVal = (gWBShadeIndex = 0)"
    AddCodeLine s, "        Case ""WB_B_ShadeMedium"", ""WB_B_ShadeMedium_ZH"": returnedVal = (gWBShadeIndex = 1)"
    AddCodeLine s, "        Case ""WB_B_ShadeDark"", ""WB_B_ShadeDark_ZH"": returnedVal = (gWBShadeIndex = 2)"
    AddCodeLine s, "        Case Else: returnedVal = False"
    AddCodeLine s, "    End Select"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_OnShadeButton(ByVal control As Office.IRibbonControl, ByVal pressed As Boolean)"
    AddCodeLine s, "    If gWBColorIndex = 0 Or gWBColorIndex = 7 Then"
    AddCodeLine s, "        WB_BG_RefreshShadeControls"
    AddCodeLine s, "        Exit Sub"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    If pressed Then"
    AddCodeLine s, "        Select Case control.ID"
    AddCodeLine s, "            Case ""WB_B_ShadeLight"", ""WB_B_ShadeLight_ZH"": gWBShadeIndex = 0"
    AddCodeLine s, "            Case ""WB_B_ShadeMedium"", ""WB_B_ShadeMedium_ZH"": gWBShadeIndex = 1"
    AddCodeLine s, "            Case ""WB_B_ShadeDark"", ""WB_B_ShadeDark_ZH"": gWBShadeIndex = 2"
    AddCodeLine s, "        End Select"
    AddCodeLine s, "        WB_BG_ApplyToCurrentSelection"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    WB_BG_RefreshShadeControls"
    AddCodeLine s, "    WB_BG_RefreshColorControl"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub WB_BG_RefreshColorControl()"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    If gWBRibbon Is Nothing Then Exit Sub"
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_DD_BackgroundColor"""
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_DD_BackgroundColor_ZH"""
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub WB_BG_RefreshShadeControls()"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    If gWBRibbon Is Nothing Then Exit Sub"
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_B_ShadeLight"""
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_B_ShadeMedium"""
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_B_ShadeDark"""
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_B_ShadeLight_ZH"""
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_B_ShadeMedium_ZH"""
    AddCodeLine s, "    gWBRibbon.InvalidateControl ""WB_B_ShadeDark_ZH"""
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_ShadeHeader(ByVal control As Office.IRibbonControl)"
    AddCodeLine s, "    ' Visual heading button only; shade selection is handled by the three toggle buttons."
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_OnWindowSelectionChange(ByVal sel As Selection)"
    AddCodeLine s, "    On Error GoTo CleanExit"
    AddCodeLine s, "    If gWBBusy Then Exit Sub"
    AddCodeLine s, "    If sel Is Nothing Then Exit Sub"
    AddCodeLine s, ""
    AddCodeLine s, "    ' Fast exit for virtually every ordinary mouse click or caret movement."
    AddCodeLine s, "    If sel.Type <> wdSelectionInlineShape Then Exit Sub"
    AddCodeLine s, "    If sel.Range.InlineShapes.Count <> 1 Then Exit Sub"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim ils As InlineShape"
    AddCodeLine s, "    Set ils = sel.Range.InlineShapes(1)"
    AddCodeLine s, "    If Not WB_IsMathTypeInline(ils) Then Exit Sub"
    AddCodeLine s, ""
    AddCodeLine s, "    ' Avoid a document write when the selected equation already has the requested Fill."
    AddCodeLine s, "    If WB_BG_BackgroundMatches(ils, gWBColorIndex, gWBShadeIndex) Then Exit Sub"
    AddCodeLine s, ""
    AddCodeLine s, "    gWBBusy = True"
    AddCodeLine s, "    WB_BG_ApplyBackground ils, gWBColorIndex, gWBShadeIndex"
    AddCodeLine s, "CleanExit:"
    AddCodeLine s, "    gWBBusy = False"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Public Sub WB_BG_UpdateAll(ByVal control As Office.IRibbonControl)"
    AddCodeLine s, "    On Error GoTo CleanExit"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim oldScreenUpdating As Boolean"
    AddCodeLine s, "    Dim screenKnown As Boolean"
    AddCodeLine s, "    Dim ils As InlineShape"
    AddCodeLine s, ""
    AddCodeLine s, "    oldScreenUpdating = Application.ScreenUpdating"
    AddCodeLine s, "    screenKnown = True"
    AddCodeLine s, "    If oldScreenUpdating Then Application.ScreenUpdating = False"
    AddCodeLine s, ""
    AddCodeLine s, "    For Each ils In ActiveDocument.InlineShapes"
    AddCodeLine s, "        If WB_IsMathTypeInline(ils) Then"
    AddCodeLine s, "            WB_BG_ApplyBackground ils, gWBColorIndex, gWBShadeIndex"
    AddCodeLine s, "        End If"
    AddCodeLine s, "    Next ils"
    AddCodeLine s, ""
    AddCodeLine s, "CleanExit:"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, "    If screenKnown Then Application.ScreenUpdating = oldScreenUpdating"
    AddCodeLine s, "End Sub"
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
    AddCodeLine s, "        End If"    AddCodeLine s, "    End If"
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
    AddCodeLine s, "Private Sub WB_BG_ApplyToCurrentSelection()"
    AddCodeLine s, "    On Error GoTo Done"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim sel As Selection"
    AddCodeLine s, "    Dim r As Range"
    AddCodeLine s, "    Dim ils As InlineShape"
    AddCodeLine s, "    Set sel = Application.Selection"
    AddCodeLine s, ""
    AddCodeLine s, "    If sel.Type = wdSelectionInlineShape Then"
    AddCodeLine s, "        Set ils = sel.Range.InlineShapes(1)"
    AddCodeLine s, "        If WB_IsMathTypeInline(ils) Then"
    AddCodeLine s, "            WB_BG_ApplyBackground ils, gWBColorIndex, gWBShadeIndex"
    AddCodeLine s, "        End If"
    AddCodeLine s, "        Exit Sub"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    Set r = sel.Range"
    AddCodeLine s, "    For Each ils In r.InlineShapes"
    AddCodeLine s, "        If WB_IsMathTypeInline(ils) Then"
    AddCodeLine s, "            WB_BG_ApplyBackground ils, gWBColorIndex, gWBShadeIndex"
    AddCodeLine s, "        End If"
    AddCodeLine s, "    Next ils"
    AddCodeLine s, ""
    AddCodeLine s, "Done:"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_BG_BackgroundMatches(ByVal ils As InlineShape, ByVal colorIndex As Long, ByVal shadeIndex As Long) As Boolean"
    AddCodeLine s, "    On Error GoTo Nope"
    AddCodeLine s, "    Dim f As Object"
    AddCodeLine s, "    Dim targetColor As Long"
    AddCodeLine s, "    Set f = ils.Fill"
    AddCodeLine s, "    If f Is Nothing Then Exit Function"
    AddCodeLine s, ""
    AddCodeLine s, "    If colorIndex = 7 Then"
    AddCodeLine s, "        WB_BG_BackgroundMatches = (f.Visible = msoFalse)"
    AddCodeLine s, "        Exit Function"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    targetColor = WB_BG_ColorForIndex(colorIndex, shadeIndex)"
    AddCodeLine s, "    If f.Visible <> msoTrue Then Exit Function"
    AddCodeLine s, "    If f.ForeColor.RGB <> targetColor Then Exit Function"
    AddCodeLine s, "    If Abs(f.Transparency) > 0.0001 Then Exit Function"
    AddCodeLine s, "    WB_BG_BackgroundMatches = True"
    AddCodeLine s, "    Exit Function"
    AddCodeLine s, "Nope:"
    AddCodeLine s, "    WB_BG_BackgroundMatches = False"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub WB_BG_ApplyBackground(ByVal ils As InlineShape, ByVal colorIndex As Long, ByVal shadeIndex As Long)"
    AddCodeLine s, "    On Error Resume Next"
    AddCodeLine s, ""
    AddCodeLine s, "    Dim noFill As Boolean"
    AddCodeLine s, "    Dim targetColor As Long"
    AddCodeLine s, "    Dim f As Object"
    AddCodeLine s, "    noFill = (colorIndex = 7)"
    AddCodeLine s, "    If Not noFill Then targetColor = WB_BG_ColorForIndex(colorIndex, shadeIndex)"
    AddCodeLine s, ""
    AddCodeLine s, "    ' IMPORTANT: change only the InlineShape OLE object's Fill."
    AddCodeLine s, "    ' Do not touch ils.Range.Shading here; Word can expand that shading to the equation line."
    AddCodeLine s, "    Set f = ils.Fill"
    AddCodeLine s, "    If Err.Number <> 0 Then"
    AddCodeLine s, "        Err.Clear"
    AddCodeLine s, "        Exit Sub"
    AddCodeLine s, "    End If"
    AddCodeLine s, "    If f Is Nothing Then Exit Sub"
    AddCodeLine s, ""
    AddCodeLine s, "    If noFill Then"
    AddCodeLine s, "        f.Visible = msoFalse"
    AddCodeLine s, "    Else"
    AddCodeLine s, "        f.Visible = msoTrue"
    AddCodeLine s, "        f.Solid"
    AddCodeLine s, "        f.ForeColor.RGB = targetColor"
    AddCodeLine s, "        f.Transparency = 0"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    Err.Clear"
    AddCodeLine s, "    ils.Line.Visible = msoFalse"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_BG_ColorForIndex(ByVal colorIndex As Long, ByVal shadeIndex As Long) As Long"
    AddCodeLine s, "    Dim c As Long"
    AddCodeLine s, "    Dim r As Long"
    AddCodeLine s, "    Dim g As Long"
    AddCodeLine s, "    Dim b As Long"
    AddCodeLine s, ""
    AddCodeLine s, "    If colorIndex = 0 Then"
    AddCodeLine s, "        WB_BG_ColorForIndex = RGB(255,255,255)"
    AddCodeLine s, "        Exit Function"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    c = WB_BG_BaseColor(colorIndex)"
    AddCodeLine s, "    r = c And &HFF&"
    AddCodeLine s, "    g = (c \ &H100&) And &HFF&"
    AddCodeLine s, "    b = (c \ &H10000) And &HFF&"
    AddCodeLine s, ""
    AddCodeLine s, "    If shadeIndex = 0 Then"
    AddCodeLine s, "        r = WB_BG_BlendComponent(r, 255, 0.68)"
    AddCodeLine s, "        g = WB_BG_BlendComponent(g, 255, 0.68)"
    AddCodeLine s, "        b = WB_BG_BlendComponent(b, 255, 0.68)"
    AddCodeLine s, "    ElseIf shadeIndex = 2 Then"
    AddCodeLine s, "        r = CLng(r * 0.72 + 0.5)"
    AddCodeLine s, "        g = CLng(g * 0.72 + 0.5)"
    AddCodeLine s, "        b = CLng(b * 0.72 + 0.5)"
    AddCodeLine s, "    End If"
    AddCodeLine s, ""
    AddCodeLine s, "    WB_BG_ColorForIndex = RGB(r,g,b)"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_BG_BaseColor(ByVal colorIndex As Long) As Long"
    AddCodeLine s, "    Select Case colorIndex"
    AddCodeLine s, "        Case 1: WB_BG_BaseColor = RGB(166,166,166)"
    AddCodeLine s, "        Case 2: WB_BG_BaseColor = RGB(244,204,151)"
    AddCodeLine s, "        Case 3: WB_BG_BaseColor = RGB(255,255,0)"
    AddCodeLine s, "        Case 4: WB_BG_BaseColor = RGB(91,155,213)"
    AddCodeLine s, "        Case 5: WB_BG_BaseColor = RGB(112,173,71)"
    AddCodeLine s, "        Case 6: WB_BG_BaseColor = RGB(255,102,153)"
    AddCodeLine s, "        Case Else: WB_BG_BaseColor = RGB(255,255,255)"
    AddCodeLine s, "    End Select"
    AddCodeLine s, "End Function"
    AddCodeLine s, ""
    AddCodeLine s, "Private Function WB_BG_BlendComponent(ByVal fromValue As Long, ByVal toValue As Long, ByVal amount As Double) As Long"
    AddCodeLine s, "    WB_BG_BlendComponent = CLng(fromValue + (toValue - fromValue) * amount + 0.5)"
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

Function BuildEventClassCode()
    Dim s
    s = ""
    AddCodeLine s, "Option Explicit"
    AddCodeLine s, ""
    AddCodeLine s, "Public WithEvents App As Word.Application"
    AddCodeLine s, ""
    AddCodeLine s, "Private Sub App_WindowSelectionChange(ByVal Sel As Selection)"
    AddCodeLine s, "    WBMathTypeHook.WB_OnWindowSelectionChange Sel"
    AddCodeLine s, "End Sub"
    AddCodeLine s, ""
    BuildEventClassCode = s
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
Add-Type -AssemblyName System.Drawing
$target = $null
$backup = $null
$wordStartup = $null
$wbAddin = $null
$wbIconRoot = Join-Path $env:APPDATA 'wb_MathTypeWhiteBackground'
$wbIconDir = Join-Path $wbIconRoot 'icons'
$wbStateFile = Join-Path $wbIconRoot 'patched_target.txt'

function Log([string]$Level,[string]$Message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding Unicode
}

$wordStartup = $null
$wordInstallDir = $null
$wbAddin = $null

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

Resolve-WbWordPaths

function Test-WbRibbonPatch([string]$Path) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entryName in @('customUI/customUI.xml','customUI/CustomUI14.xml')) {
            $e = $zip.GetEntry($entryName)
            if ($null -eq $e) { continue }
            $s = $e.Open()
            try {
                $reader = New-Object IO.StreamReader($s,[Text.Encoding]::UTF8,$true)
                try { $xml = $reader.ReadToEnd() }
                finally { $reader.Dispose() }
            } finally { $s.Dispose() }

            if ($xml.Contains('WBMathTypeHook.WB_MT_OnInsertRightNumberedDispEqn')) {
                return $true
            }
        }
        return $false
    } finally { $zip.Dispose() }
}

function Add-WbRoot([System.Collections.Generic.List[string]]$Roots,[string]$Path) {
    if (-not [string]::IsNullOrWhiteSpace($Path)) { $Roots.Add($Path) }
}

function Get-WbMathTypeSearchRoots() {
    $roots = New-Object System.Collections.Generic.List[string]
    Add-WbRoot $roots $wordStartup
    if (-not [string]::IsNullOrWhiteSpace($wordInstallDir)) {
        Add-WbRoot $roots (Join-Path $wordInstallDir 'STARTUP')
    }
    Add-WbRoot $roots (Join-Path $env:APPDATA 'Microsoft\Word\STARTUP')

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

function Get-WbMathTypeCandidates() {
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

function Test-WbCompatibleMathTypeTemplate([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            if ($null -eq $zip.GetEntry('word/vbaProject.bin')) { return $false }

            $original = @(
                'onLoad="MTCommand_OnRibbonLoaded"',
                'onAction="MTCommand_OnInsertInlineEqn"',
                'onAction="MTCommand_OnInsertDispEqn"',
                'onAction="MTCommand_OnInsertRightNumberedDispEqn"'
            )
            $patched = @(
                'onLoad="WBMathTypeHook.WB_RibbonOnLoad"',
                'onAction="WBMathTypeHook.WB_MT_OnInsertInlineEqn"',
                'onAction="WBMathTypeHook.WB_MT_OnInsertDispEqn"',
                'onAction="WBMathTypeHook.WB_MT_OnInsertRightNumberedDispEqn"'
            )

            foreach ($entryName in @('customUI/customUI.xml','customUI/CustomUI14.xml')) {
                $e = $zip.GetEntry($entryName)
                if ($null -eq $e) { return $false }
                $st = $e.Open()
                try {
                    $reader = New-Object IO.StreamReader($st,[Text.Encoding]::UTF8,$true)
                    try { $xml = $reader.ReadToEnd() } finally { $reader.Dispose() }
                } finally { $st.Dispose() }

                if (-not $xml.Contains('<group id="MathType_G_Insert"')) { return $false }
                $originalOk = $true
                foreach ($x in $original) { if (-not $xml.Contains($x)) { $originalOk = $false; break } }
                $patchedOk = $true
                foreach ($x in $patched) { if (-not $xml.Contains($x)) { $patchedOk = $false; break } }
                if (-not $originalOk -and -not $patchedOk) { return $false }
            }
            return $true
        } finally { $zip.Dispose() }
    }
    catch {
        return $false
    }
}

function Find-WbCompatibleMathTypeTemplate() {
    $foundAny = $false
    foreach ($candidate in Get-WbMathTypeCandidates) {
        $foundAny = $true
        if (Test-WbCompatibleMathTypeTemplate $candidate) {
            Log 'INFO' "Compatible MathType Word template found: $candidate"
            return $candidate
        }
        Log 'WARN' "MathType template found but Ribbon structure is not compatible with the verified hook; leaving it unchanged: $candidate"
    }
    if (-not $foundAny) {
        Log 'INFO' 'No MathType Word template was found in Word STARTUP locations.'
    }
    return $null
}

function Get-WbBackupCandidates() {
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($root in Get-WbMathTypeSearchRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Filter 'MathType Commands*.dotm.wb_original' -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            $items.Add($_.FullName)
        }
    }
    $items | Sort-Object -Unique
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
            try { $xml = $reader.ReadToEnd() }
            finally { $reader.Dispose() }
        } finally { $stream.Dispose() }

        foreach ($k in $Replacements.Keys) {
            if (-not $xml.Contains($k)) {
                throw "Expected callback text not found in ${EntryName}: $k"
            }
            $xml = $xml.Replace($k,$Replacements[$k])
        }

        $entry.Delete()
        $newEntry = $zip.CreateEntry($EntryName,[IO.Compression.CompressionLevel]::Optimal)
        $outStream = $newEntry.Open()
        try {
            $enc = New-Object Text.UTF8Encoding($false)
            $writer = New-Object IO.StreamWriter($outStream,$enc)
            try { $writer.Write($xml) }
            finally { $writer.Dispose() }
        } finally { $outStream.Dispose() }
    } finally { $zip.Dispose() }
}

function Set-ZipTextEntry([IO.Compression.ZipArchive]$Zip,[string]$EntryName,[string]$Text) {
    $old = $Zip.GetEntry($EntryName)
    if ($null -ne $old) { $old.Delete() }
    $entry = $Zip.CreateEntry($EntryName,[IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try {
        $enc = New-Object Text.UTF8Encoding($false)
        $writer = New-Object IO.StreamWriter($stream,$enc)
        try { $writer.Write($Text) } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-ZipTextEntry([IO.Compression.ZipArchive]$Zip,[string]$EntryName) {
    $entry = $Zip.GetEntry($EntryName)
    if ($null -eq $entry) { return $null }
    $stream = $entry.Open()
    try {
        $reader = New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $stream.Dispose() }
}

function Set-ZipBytesEntry([IO.Compression.ZipArchive]$Zip,[string]$EntryName,[byte[]]$Bytes) {
    $old = $Zip.GetEntry($EntryName)
    if ($null -ne $old) { $old.Delete() }
    $entry = $Zip.CreateEntry($EntryName,[IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    try { $stream.Write($Bytes,0,$Bytes.Length) } finally { $stream.Dispose() }
}

function New-WbSwatchPng([int]$Index) {
    $size = 20
    $bmp = New-Object Drawing.Bitmap -ArgumentList $size,$size
    try {
        $g = [Drawing.Graphics]::FromImage($bmp)
        try {
            $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.Clear([Drawing.Color]::Transparent)

            # One-pixel drop shadow plus a beveled frame gives the color chips
            # a raised/3-D appearance while staying native to the Ribbon.
            $shadowBrush = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(90,0,0,0))
            try { $g.FillRectangle($shadowBrush,3,3,15,15) } finally { $shadowBrush.Dispose() }

            $outer = New-Object Drawing.Rectangle -ArgumentList 1,1,16,16
            $inner = New-Object Drawing.Rectangle -ArgumentList 2,2,14,14

            if ($Index -eq 7) {
                $baseBrush = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::White)
                try { $g.FillRectangle($baseBrush,$outer) } finally { $baseBrush.Dispose() }
            } else {
                switch ($Index) {
                    0 { $c = [Drawing.Color]::FromArgb(255,255,255) }
                    1 { $c = [Drawing.Color]::FromArgb(166,166,166) }
                    2 { $c = [Drawing.Color]::FromArgb(244,204,151) }
                    3 { $c = [Drawing.Color]::FromArgb(255,255,0) }
                    4 { $c = [Drawing.Color]::FromArgb(91,155,213) }
                    5 { $c = [Drawing.Color]::FromArgb(112,173,71) }
                    6 { $c = [Drawing.Color]::FromArgb(255,102,153) }
                    default { $c = [Drawing.Color]::White }
                }

                $lighter = [Drawing.Color]::FromArgb(
                    [Math]::Min(255,[int]$c.R + 45),
                    [Math]::Min(255,[int]$c.G + 45),
                    [Math]::Min(255,[int]$c.B + 45))
                $darker = [Drawing.Color]::FromArgb(
                    [Math]::Max(0,[int]$c.R - 35),
                    [Math]::Max(0,[int]$c.G - 35),
                    [Math]::Max(0,[int]$c.B - 35))

                $grad = New-Object Drawing.Drawing2D.LinearGradientBrush -ArgumentList $inner,$lighter,$darker,45.0
                try { $g.FillRectangle($grad,$inner) } finally { $grad.Dispose() }
            }

            $edge = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(90,90,90)),1
            try { $g.DrawRectangle($edge,$outer) } finally { $edge.Dispose() }

            $hi = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(235,255,255,255)),1
            try {
                $g.DrawLine($hi,2,2,15,2)
                $g.DrawLine($hi,2,2,2,15)
            } finally { $hi.Dispose() }

            $lo = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(120,40,40,40)),1
            try {
                $g.DrawLine($lo,2,16,16,16)
                $g.DrawLine($lo,16,2,16,16)
            } finally { $lo.Dispose() }

            if ($Index -eq 7) {
                $slashShadow = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(120,70,70,70)),3
                try { $g.DrawLine($slashShadow,4,15,15,4) } finally { $slashShadow.Dispose() }
                $slash = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::Red),2
                try { $g.DrawLine($slash,4,15,15,4) } finally { $slash.Dispose() }
            }
        } finally { $g.Dispose() }

        $ms = New-Object IO.MemoryStream
        try {
            $bmp.Save($ms,[Drawing.Imaging.ImageFormat]::Png)
            return ,$ms.ToArray()
        } finally { $ms.Dispose() }
    } finally { $bmp.Dispose() }
}

function New-WbFeaturePng([string]$Kind) {
    $size = 24
    $bmp = New-Object Drawing.Bitmap -ArgumentList $size,$size
    try {
        $g = [Drawing.Graphics]::FromImage($bmp)
        try {
            $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.Clear([Drawing.Color]::Transparent)

            # Glossy raised tile: shadow, diagonal gradient, highlight and dark lower edge.
            $shadow = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(70,0,0,0))
            try { $g.FillRectangle($shadow,4,4,18,18) } finally { $shadow.Dispose() }
            $tile = New-Object Drawing.Rectangle -ArgumentList 1,1,19,19
            $tileGrad = New-Object Drawing.Drawing2D.LinearGradientBrush -ArgumentList $tile,([Drawing.Color]::FromArgb(250,255,255,255)),([Drawing.Color]::FromArgb(225,190,195,202)),45.0
            try { $g.FillRectangle($tileGrad,$tile) } finally { $tileGrad.Dispose() }
            $edge = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(110,70,75,82)),1
            try { $g.DrawRectangle($edge,$tile) } finally { $edge.Dispose() }
            $hi = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(245,255,255,255)),1
            try { $g.DrawLine($hi,2,2,18,2); $g.DrawLine($hi,2,2,2,18) } finally { $hi.Dispose() }
            $lo = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(120,45,50,58)),1
            try { $g.DrawLine($lo,2,19,19,19); $g.DrawLine($lo,19,2,19,19) } finally { $lo.Dispose() }

            if ($Kind -eq 'UpdateAll') {
                # Two formula cards plus a circular update arrow.
                $card = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(248,248,250))
                $cardEdge = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(75,85,100)),1
                $ink = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(55,105,180)),2
                $arrow = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(45,145,75)),2
                try {
                    $g.FillRectangle($card,4,5,10,7); $g.DrawRectangle($cardEdge,4,5,10,7)
                    $g.FillRectangle($card,6,10,10,7); $g.DrawRectangle($cardEdge,6,10,10,7)
                    $g.DrawLine($ink,7,8,11,8); $g.DrawLine($ink,8,13,13,13)
                    $g.DrawArc($arrow,10,4,10,10,300,230)
                    $g.DrawLine($arrow,18,5,18,9); $g.DrawLine($arrow,18,5,14,5)
                } finally { $card.Dispose(); $cardEdge.Dispose(); $ink.Dispose(); $arrow.Dispose() }
            }
            elseif ($Kind -eq 'Background') {
                # Artist palette: immediately reads as color/background selection.
                $palette = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(232,205,158))
                $paletteEdge = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(105,80,50)),1
                $red = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(225,75,75))
                $blue = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(75,135,220))
                $green = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(85,175,95))
                $hole = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::FromArgb(245,245,245))
                try {
                    $g.FillEllipse($palette,4,5,14,12); $g.DrawEllipse($paletteEdge,4,5,14,12)
                    $g.FillEllipse($red,7,7,3,3); $g.FillEllipse($blue,11,7,3,3); $g.FillEllipse($green,7,12,3,3)
                    $g.FillEllipse($hole,13,12,3,3); $g.DrawEllipse($paletteEdge,13,12,3,3)
                } finally { $palette.Dispose(); $paletteEdge.Dispose(); $red.Dispose(); $blue.Dispose(); $green.Dispose(); $hole.Dispose() }
            }
            elseif ($Kind -eq 'Shade') {
                # Three raised bars from light to dark.
                $vals = @(225,145,65)
                for ($i=0; $i -lt 3; $i++) {
                    $x = 4 + 5*$i
                    $c = $vals[$i]
                    $r = New-Object Drawing.Rectangle -ArgumentList $x,6,4,10
                    $br = New-Object Drawing.Drawing2D.LinearGradientBrush -ArgumentList $r,([Drawing.Color]::FromArgb([Math]::Min(255,$c+25),[Math]::Min(255,$c+25),[Math]::Min(255,$c+25))),([Drawing.Color]::FromArgb([Math]::Max(0,$c-25),[Math]::Max(0,$c-25),[Math]::Max(0,$c-25))),45.0
                    $pn = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(70,70,70)),1
                    try { $g.FillRectangle($br,$r); $g.DrawRectangle($pn,$r) } finally { $br.Dispose(); $pn.Dispose() }
                }
            }
            elseif ($Kind -like 'Shade*') {
                switch ($Kind) { 'ShadeLight' {$c=220}; 'ShadeMedium' {$c=145}; default {$c=70} }
                $r = New-Object Drawing.Rectangle -ArgumentList 5,5,12,12
                $br = New-Object Drawing.Drawing2D.LinearGradientBrush -ArgumentList $r,([Drawing.Color]::FromArgb([Math]::Min(255,$c+30),[Math]::Min(255,$c+30),[Math]::Min(255,$c+30))),([Drawing.Color]::FromArgb([Math]::Max(0,$c-25),[Math]::Max(0,$c-25),[Math]::Max(0,$c-25))),45.0
                $pn = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(65,65,65)),1
                try { $g.FillRectangle($br,$r); $g.DrawRectangle($pn,$r) } finally { $br.Dispose(); $pn.Dispose() }
            }
        } finally { $g.Dispose() }

        $ms = New-Object IO.MemoryStream
        try { $bmp.Save($ms,[Drawing.Imaging.ImageFormat]::Png); return ,$ms.ToArray() }
        finally { $ms.Dispose() }
    } finally { $bmp.Dispose() }
}

function Get-WbRuntimeColor([int]$Index,[int]$Shade) {
    if ($Index -eq 0) { return [Drawing.Color]::FromArgb(255,255,255) }
    if ($Index -eq 7) { return [Drawing.Color]::White }

    switch ($Index) {
        1 { $r=166; $g=166; $b=166 }
        2 { $r=244; $g=204; $b=151 }
        3 { $r=255; $g=255; $b=0 }
        4 { $r=91;  $g=155; $b=213 }
        5 { $r=112; $g=173; $b=71 }
        6 { $r=255; $g=102; $b=153 }
        default { $r=255; $g=255; $b=255 }
    }

    if ($Shade -eq 0) {
        # PowerShell [int] conversion rounds .5 instead of truncating it.  For a
        # channel that is already 255, [int](255.5) becomes 256.  Floor first,
        # then clamp, so every value passed to Color.FromArgb stays in 0..255.
        $r = [int][Math]::Min(255,[Math]::Max(0,[Math]::Floor($r + (255-$r)*0.68 + 0.5)))
        $g = [int][Math]::Min(255,[Math]::Max(0,[Math]::Floor($g + (255-$g)*0.68 + 0.5)))
        $b = [int][Math]::Min(255,[Math]::Max(0,[Math]::Floor($b + (255-$b)*0.68 + 0.5)))
    }
    elseif ($Shade -eq 2) {
        $r = [int][Math]::Min(255,[Math]::Max(0,[Math]::Floor($r*0.72 + 0.5)))
        $g = [int][Math]::Min(255,[Math]::Max(0,[Math]::Floor($g*0.72 + 0.5)))
        $b = [int][Math]::Min(255,[Math]::Max(0,[Math]::Floor($b*0.72 + 0.5)))
    }
    return [Drawing.Color]::FromArgb([int]$r,[int]$g,[int]$b)
}

function Write-WbRuntimeSwatchBmp([string]$Path,[Drawing.Color]$Color,[bool]$NoFill) {
    $size = 20
    $bmp = New-Object Drawing.Bitmap -ArgumentList $size,$size
    try {
        $g = [Drawing.Graphics]::FromImage($bmp)
        try {
            $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $g.Clear([Drawing.Color]::FromArgb(246,246,246))

            $outer = New-Object Drawing.Rectangle -ArgumentList 0,0,19,19
            $inner = New-Object Drawing.Rectangle -ArgumentList 2,2,15,15

            if ($NoFill) {
                $fill = New-Object Drawing.SolidBrush -ArgumentList ([Drawing.Color]::White)
                try { $g.FillRectangle($fill,$inner) } finally { $fill.Dispose() }
            }
            else {
                $lighter = [Drawing.Color]::FromArgb(
                    [Math]::Min(255,[int]$Color.R + 36),
                    [Math]::Min(255,[int]$Color.G + 36),
                    [Math]::Min(255,[int]$Color.B + 36))
                $darker = [Drawing.Color]::FromArgb(
                    [Math]::Max(0,[int]$Color.R - 30),
                    [Math]::Max(0,[int]$Color.G - 30),
                    [Math]::Max(0,[int]$Color.B - 30))
                $grad = New-Object Drawing.Drawing2D.LinearGradientBrush -ArgumentList $inner,$lighter,$darker,45.0
                try { $g.FillRectangle($grad,$inner) } finally { $grad.Dispose() }
            }

            $edge = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(78,78,78)),1
            try { $g.DrawRectangle($edge,$outer) } finally { $edge.Dispose() }
            $hi = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::White),1
            try { $g.DrawLine($hi,1,1,18,1); $g.DrawLine($hi,1,1,1,18) } finally { $hi.Dispose() }
            $lo = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(95,45,45,45)),1
            try { $g.DrawLine($lo,1,18,18,18); $g.DrawLine($lo,18,1,18,18) } finally { $lo.Dispose() }

            if ($NoFill) {
                $slashShadow = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::FromArgb(105,80,80,80)),3
                try { $g.DrawLine($slashShadow,4,15,15,4) } finally { $slashShadow.Dispose() }
                $slash = New-Object Drawing.Pen -ArgumentList ([Drawing.Color]::Red),2
                try { $g.DrawLine($slash,4,15,15,4) } finally { $slash.Dispose() }
            }
        }
        finally { $g.Dispose() }

        $bmp.Save($Path,[Drawing.Imaging.ImageFormat]::Bmp)
    }    finally { $bmp.Dispose() }
}

function Write-WbRuntimeIcons {
    if (Test-Path -LiteralPath $wbIconDir) {
        Remove-Item -LiteralPath $wbIconDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $wbIconDir -Force | Out-Null

    # Drop-down preview: all colors and all shade states. White/No Fill ignore shade visually.
    for ($c=0; $c -le 7; $c++) {
        for ($s=0; $s -le 2; $s++) {
            $p = Join-Path $wbIconDir ("preview_c${c}_s${s}.bmp")
            Write-WbRuntimeSwatchBmp $p (Get-WbRuntimeColor $c $s) ($c -eq 7)
        }
    }

    # Dynamic shade buttons: use the currently selected background hue.
    for ($c=1; $c -le 6; $c++) {
        for ($s=0; $s -le 2; $s++) {
            $p = Join-Path $wbIconDir ("shade_c${c}_s${s}.bmp")
            Write-WbRuntimeSwatchBmp $p (Get-WbRuntimeColor $c $s) $false
        }
    }

    # Neutral icons are used while shade controls are disabled for White/No Background.
    $neutral = @([Drawing.Color]::FromArgb(220,220,220),[Drawing.Color]::FromArgb(145,145,145),[Drawing.Color]::FromArgb(70,70,70))
    for ($s=0; $s -le 2; $s++) {
        $p = Join-Path $wbIconDir ("shade_neutral_s${s}.bmp")
        Write-WbRuntimeSwatchBmp $p $neutral[$s] $false
    }
    Log 'INFO' "Generated dynamic Ribbon preview icons: $wbIconDir"
}

function Add-WbRibbonSwatches([string]$Path) {
    $ids = @('White','Gray','Beige','Yellow','Blue','Green','Pink','None','UpdateAll','Background','Shade','ShadeLight','ShadeMedium','ShadeDark')
    $files = @('wb_white.png','wb_gray.png','wb_beige.png','wb_yellow.png','wb_blue.png','wb_green.png','wb_pink.png','wb_none.png','wb_updateall.png','wb_background.png','wb_shade.png','wb_shade_light.png','wb_shade_medium.png','wb_shade_dark.png')

    $zip = [IO.Compression.ZipFile]::Open($Path,[IO.Compression.ZipArchiveMode]::Update)
    try {
        for ($i=0; $i -lt 8; $i++) {
            Set-ZipBytesEntry $zip ('customUI/images/' + $files[$i]) (New-WbSwatchPng $i)
        }
        Set-ZipBytesEntry $zip 'customUI/images/wb_updateall.png' (New-WbFeaturePng 'UpdateAll')
        Set-ZipBytesEntry $zip 'customUI/images/wb_background.png' (New-WbFeaturePng 'Background')
        Set-ZipBytesEntry $zip 'customUI/images/wb_shade.png' (New-WbFeaturePng 'Shade')
        Set-ZipBytesEntry $zip 'customUI/images/wb_shade_light.png' (New-WbFeaturePng 'ShadeLight')
        Set-ZipBytesEntry $zip 'customUI/images/wb_shade_medium.png' (New-WbFeaturePng 'ShadeMedium')
        Set-ZipBytesEntry $zip 'customUI/images/wb_shade_dark.png' (New-WbFeaturePng 'ShadeDark')

        $ct = Get-ZipTextEntry $zip '[Content_Types].xml'
        if ([string]::IsNullOrWhiteSpace($ct)) { throw 'Missing [Content_Types].xml.' }
        if ($ct -notmatch '(?i)Extension="png"') {
            $ct = $ct -replace '</Types>', '<Default Extension="png" ContentType="image/png"/></Types>'
            Set-ZipTextEntry $zip '[Content_Types].xml' $ct
        }

        foreach ($relsName in @('customUI/_rels/customUI.xml.rels','customUI/_rels/CustomUI14.xml.rels')) {
            $rels = Get-ZipTextEntry $zip $relsName
            if ([string]::IsNullOrWhiteSpace($rels)) {
                $rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"></Relationships>'
            }

            foreach ($id in $ids) {
                $rels = [regex]::Replace($rels, '<Relationship\b[^>]*\bId="WB_Img_' + $id + '"[^>]*/>', '', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }

            $insert = ''
            for ($i=0; $i -lt $ids.Count; $i++) {
                $insert += '<Relationship Id="WB_Img_' + $ids[$i] + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="images/' + $files[$i] + '"/>'
            }
            if ($rels -notmatch '</Relationships>') { throw "Invalid relationships XML: $relsName" }
            $rels = $rels -replace '</Relationships>', ($insert + '</Relationships>')
            Set-ZipTextEntry $zip $relsName $rels
        }
    } finally { $zip.Dispose() }
}


function Add-WbStandaloneRibbon([string]$Path,[string]$BackgroundGroup) {
    $ui2006 = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<customUI xmlns="http://schemas.microsoft.com/office/2006/01/customui" onLoad="WBMathTypeHook.WB_StandaloneRibbonOnLoad"><ribbon><tabs>' +
        '<tab id="WB_T_Math" label="MathType">' + $BackgroundGroup + '</tab></tabs></ribbon></customUI>'
    $ui2009 = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
        '<customUI xmlns="http://schemas.microsoft.com/office/2009/07/customui" onLoad="WBMathTypeHook.WB_StandaloneRibbonOnLoad"><ribbon><tabs>' +
        '<tab id="WB_T_Math" label="MathType">' + $BackgroundGroup + '</tab></tabs></ribbon></customUI>'

    $zip = [IO.Compression.ZipFile]::Open($Path,[IO.Compression.ZipArchiveMode]::Update)
    try {
        Set-ZipTextEntry $zip 'customUI/customUI.xml' $ui2006
        Set-ZipTextEntry $zip 'customUI/CustomUI14.xml' $ui2009

        $rels = Get-ZipTextEntry $zip '_rels/.rels'
        if ([string]::IsNullOrWhiteSpace($rels)) {
            throw 'Missing package relationship file: _rels/.rels'
        }
        $rels = [regex]::Replace($rels, '<Relationship\b[^>]*\bId="WB_Ribbon_2006"[^>]*/>', '', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $rels = [regex]::Replace($rels, '<Relationship\b[^>]*\bId="WB_Ribbon_2009"[^>]*/>', '', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        $insert = '<Relationship Id="WB_Ribbon_2006" Type="http://schemas.microsoft.com/office/2006/relationships/ui/extensibility" Target="customUI/customUI.xml"/>' +
                  '<Relationship Id="WB_Ribbon_2009" Type="http://schemas.microsoft.com/office/2007/relationships/ui/extensibility" Target="customUI/CustomUI14.xml"/>'
        if ($rels -notmatch '</Relationships>') { throw 'Invalid package relationship XML.' }
        $rels = $rels -replace '</Relationships>', ($insert + '</Relationships>')
        Set-ZipTextEntry $zip '_rels/.rels' $rels

        $ct = Get-ZipTextEntry $zip '[Content_Types].xml'
        if ([string]::IsNullOrWhiteSpace($ct)) { throw 'Missing [Content_Types].xml.' }
        if ($ct -notmatch '(?i)<Default\b[^>]*\bExtension="xml"') {
            $ct = $ct -replace '</Types>', '<Default Extension="xml" ContentType="application/xml"/></Types>'
            Set-ZipTextEntry $zip '[Content_Types].xml' $ct
        }
    }
    finally { $zip.Dispose() }

    Add-WbRibbonSwatches $Path
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
    # A standalone wb_v installation is identifiable from CustomUI inside the wb add-in itself.
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
    Log 'INFO' "wb_v0.0.65 PowerShell stage started in mode: $Mode"

    if ($Mode -eq 'prepare-switch') {
        Remove-WbInstalledVariant 'no'
        exit 0
    }

    if ($Mode -eq 'restore') {
        $restoreTarget = $null
        $restoreBackup = $null

        if (Test-Path -LiteralPath $wbStateFile) {
            $recorded = (Get-Content -LiteralPath $wbStateFile -Raw -ErrorAction SilentlyContinue).Trim()
            if (-not [string]::IsNullOrWhiteSpace($recorded)) {
                $candidateBackup = $recorded + '.wb_original'
                if (Test-Path -LiteralPath $candidateBackup) {
                    $restoreTarget = $recorded
                    $restoreBackup = $candidateBackup
                }
            }
        }

        if ($null -eq $restoreBackup) {
            foreach ($candidateBackup in Get-WbBackupCandidates) {
                if (-not (Test-WbRibbonPatch $candidateBackup)) {
                    $restoreBackup = $candidateBackup
                    $restoreTarget = $candidateBackup.Substring(0,$candidateBackup.Length - '.wb_original'.Length)
                    break
                }
            }
        }

        if ($null -ne $restoreBackup) {
            if (Test-WbRibbonPatch $restoreBackup) {
                throw 'The saved MathType backup is not pristine; restore was stopped to avoid reinstalling a patched backup.'
            }
            Copy-Item -LiteralPath $restoreBackup -Destination $restoreTarget -Force
            Log 'SUCCESS' 'Original MathType template restored.'
            Log 'INFO' "Restored from: $restoreBackup"
        } else {
            Log 'INFO' 'No MathType backup was found; there is no MathType Ribbon patch to restore.'
        }

        if (Test-Path -LiteralPath $wbAddin) {
            Remove-Item -LiteralPath $wbAddin -Force
        }
        if (Test-Path -LiteralPath $wbIconRoot) {
            Remove-Item -LiteralPath $wbIconRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        Log 'SUCCESS' 'wb add-in and standalone Ribbon files removed.'
        exit 0
    }

    if (-not (Test-Path -LiteralPath $wbAddin)) {
        throw "wb add-in was not created: $wbAddin"
    }

    $target = Find-WbCompatibleMathTypeTemplate
    $standalone = [string]::IsNullOrWhiteSpace($target)
    $tmp = $null
    $beforeVba = $null
    $beforeSig = $null
    $beforeSigAgile = $null

    if (-not $standalone) {
        $backup = $target + '.wb_original'
        $targetAlreadyPatched = Test-WbRibbonPatch $target

        if ($targetAlreadyPatched) {
            if (-not (Test-Path -LiteralPath $backup)) {
                throw 'The compatible MathType template is already wb-patched, but the pristine backup is missing. Restore/reinstall MathType before continuing.'
            }
            if (Test-WbRibbonPatch $backup) {
                throw 'The saved MathType backup is not pristine. Refusing to use a patched file as the installation source.'
            }
            if (-not (Test-WbCompatibleMathTypeTemplate $backup)) {
                throw 'The saved MathType backup no longer matches the verified Ribbon structure.'
            }

            # The patch changes Ribbon XML only. The current patched file and its pristine
            # backup must therefore contain the exact same MathType VBA project.
            $currentVba = Get-ZipEntryHash $target 'word/vbaProject.bin'
            $backupVbaCheck = Get-ZipEntryHash $backup 'word/vbaProject.bin'
            if ([string]::IsNullOrWhiteSpace($currentVba) -or
                [string]::IsNullOrWhiteSpace($backupVbaCheck) -or
                $currentVba -ne $backupVbaCheck) {
                throw 'The existing pristine backup does not match the current patched MathType VBA project. Refusing to overwrite a possibly newer MathType installation.'
            }

            Log 'INFO' "Current MathType template is already wb-patched; verified matching pristine backup: $backup"
        } else {
            Copy-Item -LiteralPath $target -Destination $backup -Force
            Log 'INFO' "Refreshed pristine MathType backup from the current unpatched template: $backup"
        }

        $leaf = [IO.Path]::GetFileNameWithoutExtension($target)
        $tmp = Join-Path $env:TEMP ($leaf + '.wb_v0.0.65.' + [Guid]::NewGuid().ToString('N') + '.dotm')
        Copy-Item -LiteralPath $backup -Destination $tmp -Force

        # Office STARTUP files can retain ReadOnly when copied; ZipArchiveMode.Update needs write access.
        try {
            $attrs = [IO.File]::GetAttributes($tmp)
            if (($attrs -band [IO.FileAttributes]::ReadOnly) -ne 0) {
                [IO.File]::SetAttributes($tmp, $attrs -band (-bnot [IO.FileAttributes]::ReadOnly))
            }
        }
        catch {
            throw ("Could not make temporary MathType package writable: " + $_.Exception.Message)
        }

        try {
            $fs = [IO.File]::Open($tmp, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            $fs.Dispose()
            Log 'INFO' 'Temporary MathType package passed read/write access test.'
        }
        catch {
            throw ("Temporary MathType package is still not writable: " + $_.Exception.Message)
        }

        $beforeVba = Get-ZipEntryHash $backup 'word/vbaProject.bin'
        $beforeSig = Get-ZipEntryHash $backup 'word/vbaProjectSignature.bin'
        $beforeSigAgile = Get-ZipEntryHash $backup 'word/vbaProjectSignatureAgile.bin'
        if ([string]::IsNullOrWhiteSpace($beforeVba)) {
            throw 'Original MathType vbaProject.bin could not be found.'
        }
    } else {
        Log 'INFO' 'No verified-compatible MathType Ribbon will be modified. Installing the wb background controls as a standalone MathType tab.'
    }

    Log 'INFO' 'Ribbon language is selected dynamically at Word startup from Application.Language; no reinstall is required after changing Word display language.'

    # Both localized groups are embedded with the same geometry. Word evaluates
    # getVisible at Ribbon load and shows exactly one according to its current UI language.
    # The English group intentionally retains the v0.0.44 layout/IDs unchanged.
    $wbBackgroundGroup = @'
<group id="WB_G_Background_ZH" label="&#x516C;&#x5F0F;&#x80CC;&#x666F;" getVisible="WBMathTypeHook.WB_BG_GetChineseVisible">
	<button id="WB_B_UpdateAll_ZH" size="normal" label="&#x66F4;&#x65B0;&#x6240;&#x6709;&#x516C;&#x5F0F;&#x7684;&#x80CC;&#x666F;&#x984F;&#x8272;" screentip="&#x5C07;&#x76EE;&#x524D;&#x8A2D;&#x5B9A;&#x5957;&#x7528;&#x5230;&#x5168;&#x6587;&#x6240;&#x6709; MathType &#x516C;&#x5F0F;" image="WB_Img_UpdateAll" onAction="WBMathTypeHook.WB_BG_UpdateAll"/>
	<box id="WB_BX_Color_ZH" boxStyle="horizontal">
		<button id="WB_B_ColorHeader_ZH" size="normal" label="&#x80CC;&#x666F;&#x984F;&#x8272;" screentip="&#x9078;&#x64C7;&#x516C;&#x5F0F;&#x80CC;&#x666F;&#x984F;&#x8272;" image="WB_Img_Background" onAction="WBMathTypeHook.WB_BG_ColorHeader"/>
		<dropDown id="WB_DD_BackgroundColor_ZH" sizeString="No Background" screentip="&#x9078;&#x64C7;&#x516C;&#x5F0F;&#x80CC;&#x666F;&#x984F;&#x8272;" getImage="WBMathTypeHook.WB_BG_GetColorPreviewImage" showImage="true" showItemImage="true" getSelectedItemIndex="WBMathTypeHook.WB_BG_GetColorIndex" onAction="WBMathTypeHook.WB_BG_OnColorChanged">
			<item id="WB_Color_White_ZH" label="&#x767D;&#x8272;" image="WB_Img_White"/>
			<item id="WB_Color_Gray_ZH" label="&#x7070;&#x8272;" image="WB_Img_Gray"/>
			<item id="WB_Color_Beige_ZH" label="&#x7C73;&#x8272;" image="WB_Img_Beige"/>
			<item id="WB_Color_Yellow_ZH" label="&#x9EC3;&#x8272;" image="WB_Img_Yellow"/>
			<item id="WB_Color_Blue_ZH" label="&#x85CD;&#x8272;" image="WB_Img_Blue"/>
			<item id="WB_Color_Green_ZH" label="&#x7DA0;&#x8272;" image="WB_Img_Green"/>
			<item id="WB_Color_Pink_ZH" label="&#x7C89;&#x7D05;&#x8272;" image="WB_Img_Pink"/>
			<item id="WB_Color_None_ZH" label="&#x7121;&#x80CC;&#x666F;" image="WB_Img_None"/>
		</dropDown>
	</box>
	<box id="WB_BX_Shade_ZH" boxStyle="horizontal">
		<button id="WB_B_ShadeHeader_ZH" size="normal" label="&#x984F;&#x8272;&#x6DF1;&#x6DFA;" screentip="&#x8ABF;&#x6574;&#x76EE;&#x524D;&#x80CC;&#x666F;&#x8272;&#x7684;&#x6DF1;&#x6DFA;" image="WB_Img_Shade" onAction="WBMathTypeHook.WB_BG_ShadeHeader"/>
		<toggleButton id="WB_B_ShadeLight_ZH" size="normal" label="&#x6DFA;" getImage="WBMathTypeHook.WB_BG_GetShadeImage" getEnabled="WBMathTypeHook.WB_BG_GetShadeEnabled" getPressed="WBMathTypeHook.WB_BG_GetShadePressed" onAction="WBMathTypeHook.WB_BG_OnShadeButton"/>
		<toggleButton id="WB_B_ShadeMedium_ZH" size="normal" label="&#x4E2D;" getImage="WBMathTypeHook.WB_BG_GetShadeImage" getEnabled="WBMathTypeHook.WB_BG_GetShadeEnabled" getPressed="WBMathTypeHook.WB_BG_GetShadePressed" onAction="WBMathTypeHook.WB_BG_OnShadeButton"/>
		<toggleButton id="WB_B_ShadeDark_ZH" size="normal" label="&#x6DF1;" getImage="WBMathTypeHook.WB_BG_GetShadeImage" getEnabled="WBMathTypeHook.WB_BG_GetShadeEnabled" getPressed="WBMathTypeHook.WB_BG_GetShadePressed" onAction="WBMathTypeHook.WB_BG_OnShadeButton"/>
	</box>
</group>
<group id="WB_G_Background" label="Equation Background" getVisible="WBMathTypeHook.WB_BG_GetEnglishVisible">
	<button id="WB_B_UpdateAll" size="normal" label="Update All Equation Background Colors" screentip="Apply the current background setting to all MathType equations" image="WB_Img_UpdateAll" onAction="WBMathTypeHook.WB_BG_UpdateAll"/>
	<box id="WB_BX_Color" boxStyle="horizontal">
		<button id="WB_B_ColorHeader" size="normal" label="Background Color" screentip="Choose the equation background color" image="WB_Img_Background" onAction="WBMathTypeHook.WB_BG_ColorHeader"/>
		<dropDown id="WB_DD_BackgroundColor" sizeString="No Background" screentip="Choose the equation background color" getImage="WBMathTypeHook.WB_BG_GetColorPreviewImage" showImage="true" showItemImage="true" getSelectedItemIndex="WBMathTypeHook.WB_BG_GetColorIndex" onAction="WBMathTypeHook.WB_BG_OnColorChanged">
			<item id="WB_Color_White" label="White" image="WB_Img_White"/>
			<item id="WB_Color_Gray" label="Gray" image="WB_Img_Gray"/>
			<item id="WB_Color_Beige" label="Beige" image="WB_Img_Beige"/>
			<item id="WB_Color_Yellow" label="Yellow" image="WB_Img_Yellow"/>
			<item id="WB_Color_Blue" label="Blue" image="WB_Img_Blue"/>
			<item id="WB_Color_Green" label="Green" image="WB_Img_Green"/>
			<item id="WB_Color_Pink" label="Pink" image="WB_Img_Pink"/>
			<item id="WB_Color_None" label="No Background" image="WB_Img_None"/>
		</dropDown>
	</box>
	<box id="WB_BX_Shade" boxStyle="horizontal">
		<button id="WB_B_ShadeHeader" size="normal" label="Color Shade" screentip="Adjust the shade of the current background color" image="WB_Img_Shade" onAction="WBMathTypeHook.WB_BG_ShadeHeader"/>
		<toggleButton id="WB_B_ShadeLight" size="normal" label="Light" getImage="WBMathTypeHook.WB_BG_GetShadeImage" getEnabled="WBMathTypeHook.WB_BG_GetShadeEnabled" getPressed="WBMathTypeHook.WB_BG_GetShadePressed" onAction="WBMathTypeHook.WB_BG_OnShadeButton"/>
		<toggleButton id="WB_B_ShadeMedium" size="normal" label="Medium" getImage="WBMathTypeHook.WB_BG_GetShadeImage" getEnabled="WBMathTypeHook.WB_BG_GetShadeEnabled" getPressed="WBMathTypeHook.WB_BG_GetShadePressed" onAction="WBMathTypeHook.WB_BG_OnShadeButton"/>
		<toggleButton id="WB_B_ShadeDark" size="normal" label="Dark" getImage="WBMathTypeHook.WB_BG_GetShadeImage" getEnabled="WBMathTypeHook.WB_BG_GetShadeEnabled" getPressed="WBMathTypeHook.WB_BG_GetShadePressed" onAction="WBMathTypeHook.WB_BG_OnShadeButton"/>
	</box>
</group>
'@


    if ($standalone) {
        Add-WbStandaloneRibbon $wbAddin $wbBackgroundGroup
        Write-WbRuntimeIcons
        if (Test-Path -LiteralPath $wbStateFile) {
            Remove-Item -LiteralPath $wbStateFile -Force -ErrorAction SilentlyContinue
        }

        $word = $null
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false
            $word.DisplayAlerts = 0
            Start-Sleep -Milliseconds 750

            $names = @()
            foreach ($t in $word.Templates) { $names += [string]$t.Name }
            if (-not ($names -contains 'wb_MathTypeWhiteBackground.dotm')) {
                throw 'wb standalone global template did not load.'
            }

            $ver = [string]$word.Run('WBMathTypeHook.WB_SelfTest')
            if ($ver -ne '0.0.65') {
                throw "wb standalone self-test returned unexpected value: $ver"
            }
            Log 'INFO' 'Standalone Word startup self-test passed: wb Ribbon template loaded and WBMathTypeHook is globally callable.'
        }
        finally {
            if ($null -ne $word) {
                try { $word.Quit() } catch {}
                try { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) | Out-Null } catch {}
            }
        }

        Log 'SUCCESS' 'Standalone wb equation-background Ribbon installed; no MathType template was modified.'
        exit 0
    }


    $repl = @{
        'onLoad="MTCommand_OnRibbonLoaded"' = 'onLoad="WBMathTypeHook.WB_RibbonOnLoad"'
        'onAction="MTCommand_OnInsertInlineEqn"' = 'onAction="WBMathTypeHook.WB_MT_OnInsertInlineEqn"'
        'onAction="MTCommand_OnInsertDispEqn"' = 'onAction="WBMathTypeHook.WB_MT_OnInsertDispEqn"'
        'onAction="MTCommand_OnInsertRightNumberedDispEqn"' = 'onAction="WBMathTypeHook.WB_MT_OnInsertRightNumberedDispEqn"'
        '<group id="MathType_G_Insert"' = ($wbBackgroundGroup + "`r`n`t`t`t`t<group id=`"MathType_G_Insert`"")
    }

    foreach ($uiPart in @('customUI/customUI.xml','customUI/CustomUI14.xml')) {
        Log 'INFO' "Patching $uiPart."
        Replace-ZipXml $tmp $uiPart $repl
    }

    Log 'INFO' 'Adding 3-D feature icons and background-color swatches to both MathType Ribbon parts.'
    Log 'INFO' 'Ribbon sizing: v0.0.44 English geometry is used identically for English and Traditional Chinese.'
    Add-WbRibbonSwatches $tmp
    Write-WbRuntimeIcons

    $afterVba = Get-ZipEntryHash $tmp 'word/vbaProject.bin'
    $afterSig = Get-ZipEntryHash $tmp 'word/vbaProjectSignature.bin'
    $afterSigAgile = Get-ZipEntryHash $tmp 'word/vbaProjectSignatureAgile.bin'

    if ($afterVba -ne $beforeVba) {
        throw 'Safety check failed: vbaProject.bin changed.'
    }
    if ($beforeSig -and $afterSig -ne $beforeSig) {
        throw 'Safety check failed: vbaProjectSignature.bin changed.'
    }
    if ($beforeSigAgile -and $afterSigAgile -ne $beforeSigAgile) {
        throw 'Safety check failed: vbaProjectSignatureAgile.bin changed.'
    }

    Log 'INFO' "Verified unchanged MathType VBA SHA-256: $beforeVba"
    Log 'INFO' 'Verified VBA signature streams are unchanged.'

    Copy-Item -LiteralPath $tmp -Destination $target -Force
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    Log 'INFO' 'Patched MathType template installed.'

    # Verify both templates load and the module-qualified wb macro is globally callable.
    $word = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        Start-Sleep -Milliseconds 750

        $names = @()
        foreach ($t in $word.Templates) { $names += [string]$t.Name }

        $targetName = [IO.Path]::GetFileName($target)
        if (-not ($names -contains $targetName)) {
            throw "Patched MathType global template did not load: $targetName"
        }
        if (-not ($names -contains 'wb_MathTypeWhiteBackground.dotm')) {
            throw 'wb global template did not load.'
        }

        $ver = [string]$word.Run('WBMathTypeHook.WB_SelfTest')
        if ($ver -ne '0.0.65') {
            throw "wb hook self-test returned unexpected value: $ver"
        }

        Log 'INFO' 'Word startup self-test passed: both templates loaded and WBMathTypeHook is globally callable.'
        Log 'INFO' 'WindowSelectionChange auto-apply handler is included in the wb global add-in.'
    }
    finally {
        if ($null -ne $word) {
            try { $word.Quit() } catch {}
            try { [Runtime.InteropServices.Marshal]::FinalReleaseComObject($word) | Out-Null } catch {}
        }
    }

    if (-not (Test-Path -LiteralPath $wbIconRoot)) { New-Item -ItemType Directory -Path $wbIconRoot -Force | Out-Null }
    Set-Content -LiteralPath $wbStateFile -Value $target -Encoding ASCII
    Log 'INFO' "Recorded patched MathType target: $target"
    Log 'SUCCESS' 'Direct MathType Ribbon hook installed and verified.'
    exit 0
}
catch {
    Log 'ERROR' $_.Exception.Message

    if ($null -ne $tmp -and (Test-Path -LiteralPath $tmp)) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }

    if ($Mode -eq 'install') {
        try {
            Get-Process WINWORD -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            if ($null -ne $backup -and $null -ne $target -and (Test-Path -LiteralPath $backup)) {
                Copy-Item -LiteralPath $backup -Destination $target -Force
                Log 'WARN' 'Automatic rollback restored the original MathType template.'
            }
            if (Test-Path -LiteralPath $wbAddin) {
                Remove-Item -LiteralPath $wbAddin -Force -ErrorAction SilentlyContinue
            }
            if (Test-Path -LiteralPath $wbIconRoot) {
                Remove-Item -LiteralPath $wbIconRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
            Log 'WARN' 'Automatic rollback removed the wb add-in and Ribbon support files.'
        } catch {
            Log 'ERROR' ('Automatic rollback failed: ' + $_.Exception.Message)
        }
    }

    exit 2
}
:__WB_PS_END__