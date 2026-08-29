---
name: android-emulator-qa
description: Reusable Android emulator QA workflow for Moe Social. Use when validating Flutter/Android UI, navigation, startup, runtime errors, screenshots, permissions, or when the user asks to check the current simulator/emulator.
---

# Android Emulator QA

Use this skill to verify that a Flutter/Android change works in the running emulator, not only in code review or static analysis. It is project-local and can be invoked explicitly as `$android-emulator-qa`; use the smallest mode that proves the requested behavior.

## When To Use

- The task changes user-facing Flutter UI, navigation, animation, Android integration, permissions, startup, or platform channels.
- The user asks to see, test, operate, QA, screenshot, or validate the emulator.
- A bug depends on runtime state, visual layout, taps, input, permissions, or Android logs.

## Project Target

- Preferred device id: `emulator-5554`.
- Debug package: `com.example.moe_social.dev`.
- Release package: `com.example.moe_social`.
- Main activity class: `com.example.moe_social.MainActivity`.

The debug build adds the `.dev` application id suffix, while both variants share the same activity class. Resolve the installed package before starting the app instead of assuming that only the debug package exists:

```powershell
adb devices
$device = 'emulator-5554'
$package = @(
  'com.example.moe_social.dev',
  'com.example.moe_social'
) | Where-Object {
  (adb -s $device shell pm path $_ 2>$null).Trim()
} | Select-Object -First 1
if (-not $package) {
  throw "No installed Moe Social package found on $device"
}
$activity = (
  adb -s $device shell cmd package resolve-activity --brief $package
  | Select-Object -Last 1
).Trim()
```

If no device is listed, stop and report the exact missing prerequisite. Do not rebuild or reinstall automatically unless the user asked for it or the requested check cannot use the installed build.

## Choose A Mode

- **Smoke**: launch the installed app, wait briefly, inspect actionable logs, and report startup state.
- **Visual**: smoke plus one screenshot at the requested page/state; inspect the image before claiming the layout is acceptable.
- **Interaction**: smoke plus a UI dump and only the taps/input needed for the target flow.
- **Permissions**: inspect current permission/app-op state and test the requested flow; never grant, revoke, or accept a system prompt silently.

When the user says they will perform the verification themselves, finish the code task without running the emulator and state that emulator QA was intentionally skipped.

## Fast Validation Loop

1. Confirm the device and installed package:

```powershell
adb devices
adb -s $device get-state
```

2. Start the resolved package:

```powershell
adb -s $device shell am force-stop $package
adb -s $device shell am start -n "$package/$activity"
Start-Sleep -Seconds 2
```

3. Read the cheapest useful evidence first. Do not capture a screenshot and a UI dump after every action:

```powershell
adb -s $device logcat -d -t 300 Flutter:D AndroidRuntime:E ActivityTaskManager:I System.err:W *:S
```

Filter for `FATAL EXCEPTION`, `AndroidRuntime`, `E/flutter`, `Exception`, and the target screen or action. Avoid clearing the whole device log unless a clean baseline is necessary.

4. For a visual check, capture one proof image with `screencap` + `pull`. Never use PowerShell `>` for PNG bytes because it can corrupt binary output:

```powershell
adb -s $device shell screencap -p /sdcard/emulator-current.png
adb -s $device pull /sdcard/emulator-current.png C:\Users\ZhuanZ1\Desktop\moe_social\emulator-current.png
```

Read `emulator-current.png` with the image reader and compare the actual UI with the requested outcome. Use a second screenshot only after a meaningful state change.

5. For precise coordinates or accessibility text, dump the UI tree:

```powershell
adb -s $device shell uiautomator dump /sdcard/window.xml
adb -s $device pull /sdcard/window.xml C:\Users\ZhuanZ1\Desktop\moe_social\window.xml
```

Use the visible text and bounds from `window.xml` to target the requested flow. Operate only the target path:

```powershell
adb -s $device shell input tap <x> <y>
adb -s $device shell input text <text>
adb -s $device shell input keyevent KEYCODE_BACK
```

6. For permission-related work, inspect first and mutate only after the user has explicitly asked for that exact operation:

```powershell
adb -s $device shell dumpsys package $package
adb -s $device shell appops get $package
```

7. After the target action, collect only the evidence needed to decide pass/fail: a UI dump for text/state, a screenshot for layout, or filtered logs for runtime failures. Do not claim emulator verification passed unless the selected evidence was actually inspected.

8. Delete temporary QA artifacts after verification:

```powershell
Remove-Item -LiteralPath C:\Users\ZhuanZ1\Desktop\moe_social\emulator-current.png -ErrorAction SilentlyContinue
Remove-Item -LiteralPath C:\Users\ZhuanZ1\Desktop\moe_social\window.xml -ErrorAction SilentlyContinue
```

## Constraints

- Do startup, log filtering, screenshot, and layout verification only when the selected mode needs them; avoid unnecessary waits and duplicate artifacts.
- If the agent command channel cannot run `adb`, ask the user to run the exact commands and then read the generated files from the workspace.
- Keep generated QA artifacts in the workspace root using stable names while validating: `emulator-current.png`, `window.xml`, and optional short log files.
- Delete screenshots, UI dumps, and log files after verification unless the user explicitly asks to retain them.
- Do not commit emulator screenshots, UI dumps, or log files unless the user explicitly asks.
- Do not use emulator QA as a reason to change product behavior, permissions, API contracts, or navigation.

## Completion Note

When finishing a Flutter/Android user-facing task, include:

- What was changed.
- Which mode ran, or that emulator QA was intentionally skipped.
- What was observed on screen, in the UI tree, or in filtered logs.
- Whether temporary QA artifacts were deleted.
- Any remaining risk if emulator operation was unavailable.
