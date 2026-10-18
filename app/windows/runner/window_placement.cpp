#include "window_placement.h"

namespace {

constexpr wchar_t kKey[] = L"Software\\Molla Workshop\\Continuum Companion";
constexpr wchar_t kValue[] = L"WindowPlacement";

}  // namespace

void RestoreWindowPlacement(HWND window) {
  WINDOWPLACEMENT placement{};
  DWORD size = sizeof(placement);
  if (RegGetValue(HKEY_CURRENT_USER, kKey, kValue, RRF_RT_REG_BINARY, nullptr,
                  &placement, &size) != ERROR_SUCCESS ||
      size != sizeof(placement) || placement.length != sizeof(placement)) {
    return;
  }
  // A monitor that has since been unplugged would leave the window off screen.
  if (MonitorFromRect(&placement.rcNormalPosition, MONITOR_DEFAULTTONULL) ==
      nullptr) {
    return;
  }
  // Never reopen minimised.
  if (placement.showCmd != SW_SHOWMAXIMIZED) {
    placement.showCmd = SW_SHOWNORMAL;
  }
  SetWindowPlacement(window, &placement);
}

void SaveWindowPlacement(HWND window) {
  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window, &placement)) {
    return;
  }
  HKEY key;
  if (RegCreateKeyEx(HKEY_CURRENT_USER, kKey, 0, nullptr, 0, KEY_SET_VALUE,
                     nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }
  RegSetValueEx(key, kValue, 0, REG_BINARY,
                reinterpret_cast<const BYTE*>(&placement), sizeof(placement));
  RegCloseKey(key);
}
