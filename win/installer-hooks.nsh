; Hooks for the Tauri NSIS installer (bundle.windows.nsis.installerHooks in tauri.conf.json).
;
; KeyCat installs for all users into Program Files (installMode perMachine), a folder only
; administrators can change: the login task of 以管理员身份运行 starts it elevated without asking,
; so it must not start anything the user's own programs could have replaced. The installer runs
; in the all-users context, where $APPDATA and $LOCALAPPDATA name ProgramData; the per-user paths
; below switch to the current user's first. The one exception is a per-user copy from 1.0.4 or
; earlier in a folder the user picked: an update stays in that folder (see below).
;
; Up to 1.0.1 KeyCat for Windows was an Electron app in %LOCALAPPDATA%\Programs\KeyCat. Its
; updater downloads this installer like any other release, so here the old copy is removed and
; its settings and start-at-login choice move over; otherwise two cats would run side by side.
; Its updater passes --force-run when the app should start again afterwards.

Var MigratedFromElectron
Var MovedFrom
Var HadDesktopShortcut

!macro NSIS_HOOK_PREINSTALL
  SetShellVarContext current
  StrCpy $R8 "$LOCALAPPDATA\Programs\KeyCat"
  ${If} ${FileExists} "$R8\Uninstall KeyCat.exe"
    DetailPrint "Removing KeyCat 1.0 (Electron)"
    StrCpy $MigratedFromElectron 1
    nsExec::Exec 'taskkill /f /im KeyCat.exe'
    Pop $R9
    ExecWait '"$R8\Uninstall KeyCat.exe" /S _?=$R8'
    Delete "$R8\Uninstall KeyCat.exe"
    RMDir "$R8"
  ${EndIf}

  ; Electron registered start at login under its AppUserModelId; the new build uses the product name.
  ReadRegStr $R9 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "com.ellobok.keycat"
  ${If} $R9 != ""
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "com.ellobok.keycat"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "KeyCat" '"$INSTDIR\KeyCat.exe"'
  ${EndIf}

  ; "Local State" marks the folder as Electron's profile; only settings.json is worth keeping.
  ${If} ${FileExists} "$APPDATA\KeyCat\Local State"
    ${IfNot} ${FileExists} "$APPDATA\com.ellobok.keycat\settings.json"
    ${AndIf} ${FileExists} "$APPDATA\KeyCat\settings.json"
      CreateDirectory "$APPDATA\com.ellobok.keycat"
      CopyFiles /SILENT "$APPDATA\KeyCat\settings.json" "$APPDATA\com.ellobok.keycat"
    ${EndIf}
    RMDir /r "$APPDATA\KeyCat"
  ${EndIf}
  RMDir /r "$LOCALAPPDATA\keycat-win-updater"

  ; Up to 1.0.4 the Tauri build installed per user, into %LOCALAPPDATA%\KeyCat unless the user
  ; picked another folder such as D:\KeyCat; its uninstall entry in HKCU says where, in quotes.
  ; That copy goes, or its shortcuts keep starting it and it updates itself here again and again.
  ; Its uninstaller takes its shortcuts along, which an update does not make again, so
  ; NSIS_HOOK_POSTINSTALL does. An uninstall without /UPDATE also drops its Run value, so start at
  ; login is pointed at this one.
  ReadRegStr $R8 HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCTNAME}" "InstallLocation"
  StrCpy $R9 $R8 1
  ${If} $R9 == "$\""
    StrCpy $R8 $R8 -1 1
  ${EndIf}
  ${If} $R8 == ""
    StrCpy $R8 "$LOCALAPPDATA\${PRODUCTNAME}"
  ${EndIf}
  ${If} $R8 != $INSTDIR
  ${AndIf} ${FileExists} "$R8\uninstall.exe"
    DetailPrint "Removing the per-user KeyCat in $R8"
    ReadRegStr $R7 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PRODUCTNAME}"
    nsExec::Exec 'taskkill /f /im ${MAINBINARYNAME}.exe'
    Pop $R9
    ${If} ${FileExists} "$DESKTOP\${PRODUCTNAME}.lnk"
      StrCpy $HadDesktopShortcut 1
    ${EndIf}
    ExecWait '"$R8\uninstall.exe" /S _?=$R8'
    Delete "$R8\uninstall.exe"
    RMDir "$R8"
    ; The uninstaller only removes a desktop shortcut that started this copy.
    ${If} ${FileExists} "$DESKTOP\${PRODUCTNAME}.lnk"
      StrCpy $HadDesktopShortcut 0
    ${EndIf}
    ; An update keeps a folder the user picked and installs there, not in Program Files; the
    ; installer's own folder page is left to the user. A copy that 1.1.0 put in Program Files
    ; beside the old one (it did not find this folder) goes. Outside Program Files KeyCat makes
    ; no login task for 以管理员身份运行 (task_allowed in win/src/autostart.rs).
    ${If} $UpdateMode = 1
    ${AndIf} $R8 != "$LOCALAPPDATA\${PRODUCTNAME}"
      ${If} ${FileExists} "$INSTDIR\uninstall.exe"
        DetailPrint "Removing the KeyCat in $INSTDIR"
        Delete "$INSTDIR\${MAINBINARYNAME}.exe"
        Delete "$INSTDIR\uninstall.exe"
        RMDir "$INSTDIR"
        StrCpy $MovedFrom $INSTDIR
      ${EndIf}
      StrCpy $INSTDIR $R8
      SetOutPath $INSTDIR
    ${EndIf}
    ${If} $R7 != ""
      WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PRODUCTNAME}" '"$INSTDIR\${MAINBINARYNAME}.exe"'
    ${EndIf}
  ${EndIf}

  ; A login task that starts KeyCat from anywhere but this folder (a per-user copy, or one removed
  ; by hand) is deleted: whatever sits at that path would start elevated. The Run value takes over
  ; start at login, and KeyCat makes the task again for this copy the next time it runs elevated.
  ; The task is named after the account, as in win/src/autostart.rs.
  System::Call 'Kernel32::SetEnvironmentVariable(t "KEYCAT_EXE", t "$INSTDIR\${MAINBINARYNAME}.exe")'
  nsExec::Exec `powershell -NoProfile -NonInteractive -Command "$$t = Get-ScheduledTask -TaskName ('KeyCat (' + $$env:USERNAME + ')') -ErrorAction SilentlyContinue; if ($$t -and $$t.Actions[0].Execute.Trim([char]34) -ne $$env:KEYCAT_EXE) { Unregister-ScheduledTask -InputObject $$t -Confirm:$$false; exit 2 }"`
  Pop $R9
  ${If} $R9 = 2
    DetailPrint "Removed a login task for another copy of KeyCat"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${PRODUCTNAME}" '"$INSTDIR\${MAINBINARYNAME}.exe"'
  ${EndIf}
  SetShellVarContext all
!macroend

!macro NSIS_HOOK_POSTINSTALL
  ; An update makes no shortcuts. Those of a Program Files copy removed above follow this one; the
  ; start menu entry, gone with a per-user copy (1.1.0 did not make it again either), and the
  ; desktop one if the per-user copy had it, are made here.
  ${If} $UpdateMode = 1
    ${If} $MovedFrom != ""
      !insertmacro IsShortcutTarget "$SMPROGRAMS\${PRODUCTNAME}.lnk" "$MovedFrom\${MAINBINARYNAME}.exe"
      Pop $R9
      ${If} $R9 = 1
        !insertmacro SetShortcutTarget "$SMPROGRAMS\${PRODUCTNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
      ${EndIf}
      !insertmacro IsShortcutTarget "$DESKTOP\${PRODUCTNAME}.lnk" "$MovedFrom\${MAINBINARYNAME}.exe"
      Pop $R9
      ${If} $R9 = 1
        !insertmacro SetShortcutTarget "$DESKTOP\${PRODUCTNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
      ${EndIf}
    ${EndIf}
    ${IfNot} ${FileExists} "$SMPROGRAMS\${PRODUCTNAME}.lnk"
      CreateShortcut "$SMPROGRAMS\${PRODUCTNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
      !insertmacro SetLnkAppUserModelId "$SMPROGRAMS\${PRODUCTNAME}.lnk"
    ${EndIf}
    ${If} $HadDesktopShortcut = 1
    ${AndIfNot} ${FileExists} "$DESKTOP\${PRODUCTNAME}.lnk"
      CreateShortcut "$DESKTOP\${PRODUCTNAME}.lnk" "$INSTDIR\${MAINBINARYNAME}.exe"
      !insertmacro SetLnkAppUserModelId "$DESKTOP\${PRODUCTNAME}.lnk"
    ${EndIf}
  ${EndIf}
  ${If} $MigratedFromElectron = 1
    ClearErrors
    ${GetOptions} $CMDLINE "--force-run" $R9
    ${IfNot} ${Errors}
      nsis_tauri_utils::RunAsUser "$INSTDIR\KeyCat.exe" ""
    ${EndIf}
  ${EndIf}
!macroend

; The login task is not part of the install, so the uninstaller removes it (not when updating,
; which keeps start at login as it is).
!macro NSIS_HOOK_PREUNINSTALL
  ${If} $UpdateMode <> 1
    ReadEnvStr $R9 USERNAME
    nsExec::Exec 'schtasks /Delete /F /TN "KeyCat ($R9)"'
    Pop $R9
  ${EndIf}
!macroend
