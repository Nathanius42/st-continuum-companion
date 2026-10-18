; Continuum Companion installer (#606), adapted from the STCR installer
; (HWRM\Tools\Installer and Launcher\STCR Installer\STCR_Installer.nsi).
;
; Built by tools/package_windows.ps1, which passes:
;   /DSOURCE=<staged app folder>  the Release build plus the Visual C++ runtime DLLs
;   /DVERSION=<x.y.z>             from app/pubspec.yaml
;   /DOUTFILE=<path to the .exe>
;
; Installs for the current user under %LOCALAPPDATA%\Programs, so it needs no
; administrator rights. Written for NSIS 3; it also compiles with the mod's NSIS 2.46,
; which lacks Unicode, so the Unicode switch is only set on NSIS 3.

!ifdef NSIS_PACKEDVERSION
  Unicode true
!endif
SetCompressor /SOLID lzma

!ifndef SOURCE
  !error "Pass /DSOURCE=<staged app folder>"
!endif
!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!ifndef OUTFILE
  !define OUTFILE "ContinuumCompanion-${VERSION}-setup.exe"
!endif

!define PRODUCT_NAME "Continuum Companion"
!define PRODUCT_PUBLISHER "Molla Workshop"
!define PRODUCT_EXE "continuum_companion.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ContinuumCompanion"
!define UNINSTALLER_NAME "Uninstall Continuum Companion.exe"

Name "${PRODUCT_NAME} ${VERSION}"
OutFile "${OUTFILE}"
BrandingText "${PRODUCT_NAME} ${VERSION}"
InstallDir "$LOCALAPPDATA\Programs\${PRODUCT_NAME}"
InstallDirRegKey HKCU "${PRODUCT_UNINST_KEY}" "InstallLocation"
RequestExecutionLevel user

;------------- Modern UI -------------
!include "MUI2.nsh"

!define MUI_ABORTWARNING
!define MUI_ICON "..\app\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "..\app\windows\runner\resources\app_icon.ico"
!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_WELCOMEPAGE_TEXT "This will install ${PRODUCT_NAME} ${VERSION}, the ship library for Star Trek Continuum Remastered.$\r$\n$\r$\nClick Next to continue."
!define MUI_LICENSEPAGE_TEXT_TOP "Please read this notice before installing."
!define MUI_LICENSEPAGE_BUTTON "I &understand"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PRODUCT_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Open ${PRODUCT_NAME}"

Var StartMenuFolder
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "${PRODUCT_NAME}"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "HKCU"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "${PRODUCT_UNINST_KEY}"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "Start Menu Folder"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "notice.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_STARTMENU Application $StartMenuFolder
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;------------- Installer -------------
Section -Install
  SetOverwrite on
  ; Remove the data folder from any earlier version so no stale assets are left behind.
  RMDir /r "$INSTDIR\data"
  SetOutPath "$INSTDIR"
  File /r "${SOURCE}\*.*"
  File "notice.txt"

  DetailPrint "Creating shortcuts..."
  CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\${PRODUCT_EXE}"
  !insertmacro MUI_STARTMENU_WRITE_BEGIN Application
    CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME}.lnk" "$INSTDIR\${PRODUCT_EXE}"
    CreateShortCut "$SMPROGRAMS\$StartMenuFolder\Uninstall ${PRODUCT_NAME}.lnk" "$INSTDIR\${UNINSTALLER_NAME}"
  !insertmacro MUI_STARTMENU_WRITE_END

  WriteUninstaller "$INSTDIR\${UNINSTALLER_NAME}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\${PRODUCT_EXE}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${PRODUCT_UNINST_KEY}" "UninstallString" "$\"$INSTDIR\${UNINSTALLER_NAME}$\""
  WriteRegDWORD HKCU "${PRODUCT_UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${PRODUCT_UNINST_KEY}" "NoRepair" 1
SectionEnd

;------------- Uninstaller -------------
; Removes only what the installer put there, then the folder if it's empty, so a
; folder the user chose that holds other files is never wiped.
Section Uninstall
  Delete "$INSTDIR\${PRODUCT_EXE}"
  Delete "$INSTDIR\flutter_windows.dll"
  Delete "$INSTDIR\native_assets.json"
  Delete "$INSTDIR\msvcp140.dll"
  Delete "$INSTDIR\vcruntime140.dll"
  Delete "$INSTDIR\vcruntime140_1.dll"
  Delete "$INSTDIR\notice.txt"
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\${UNINSTALLER_NAME}"
  RMDir "$INSTDIR"

  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
  !insertmacro MUI_STARTMENU_GETFOLDER Application $StartMenuFolder
  Delete "$SMPROGRAMS\$StartMenuFolder\${PRODUCT_NAME}.lnk"
  Delete "$SMPROGRAMS\$StartMenuFolder\Uninstall ${PRODUCT_NAME}.lnk"
  RMDir "$SMPROGRAMS\$StartMenuFolder"

  DeleteRegKey HKCU "${PRODUCT_UNINST_KEY}"
SectionEnd
