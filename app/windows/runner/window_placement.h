#ifndef RUNNER_WINDOW_PLACEMENT_H_
#define RUNNER_WINDOW_PLACEMENT_H_

#include <windows.h>

// The window's size, position and maximised state are remembered between runs
// (#550), in HKEY_CURRENT_USER\Software\Molla Workshop\Continuum Companion.

// Puts |window| where it was when last closed. Does nothing on a first run, or
// when the saved place is no longer on any monitor.
void RestoreWindowPlacement(HWND window);

// Saves where |window| is, for the next run.
void SaveWindowPlacement(HWND window);

#endif  // RUNNER_WINDOW_PLACEMENT_H_
