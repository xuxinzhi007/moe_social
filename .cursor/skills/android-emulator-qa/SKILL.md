---
name: android-emulator-qa
description: Android emulator QA workflow for Moe Social. Use when validating Flutter/Android UI, navigation, startup, runtime errors, screenshots, uiautomator layout dumps, or when the user asks to check the current simulator/emulator.
---

# Android Emulator QA

Use this skill to verify that a Flutter/Android change actually works in the running emulator, not only in code review or static analysis.

## When To Use

- The task changes user-facing Flutter UI, navigation, animation, Android integration, permissions, startup, or platform channels.
- The user asks to see, test, operate, QA, screenshot, or validate the emulator.
- A bug depends on runtime state, visual layout, taps, input, permissions, or Android logs.

## Default Device

- Preferred device id: `emulator-5554`.
- Preferred debug package: `com.example.moe_social.dev`.
- Main activity: `com.example.moe_social.MainActivity`.

Confirm with:

```powershell
adb devices
adb -s emulator-5554 shell cmd package resolve-activity --brief com.example.moe_social.dev
```

## Validation Loop

1. Start or bring the app forward:

```powershell
adb -s emulator-5554 shell am start -n com.example.moe_social.dev/com.example.moe_social.MainActivity
```

2. Capture logs around the action. Filter for actionable failures first:

```powershell
adb -s emulator-5554 logcat -d Flutter:D AndroidRuntime:E ActivityTaskManager:I System.err:W *:S
```

3. Capture a screenshot with `screencap` + `pull`. Do not use PowerShell `>` for PNG bytes because it can corrupt binary output.

```powershell
adb -s emulator-5554 shell screencap -p /sdcard/emulator-current.png
adb -s emulator-5554 pull /sdcard/emulator-current.png C:\Users\ZhuanZ1\Desktop\moe_social\emulator-current.png
```

4. Read `emulator-current.png` with the image reader and compare the actual UI with the user's requested outcome.

5. For precise coordinates or accessibility text, dump and pull the UI tree:

```powershell
adb -s emulator-5554 shell uiautomator dump /sdcard/window.xml
adb -s emulator-5554 pull /sdcard/window.xml C:\Users\ZhuanZ1\Desktop\moe_social\window.xml
```

6. Operate only the target flow:

```powershell
adb -s emulator-5554 shell input tap <x> <y>
adb -s emulator-5554 shell input text <text>
adb -s emulator-5554 shell input keyevent KEYCODE_BACK
```

7. Re-capture screenshot/logs after the action and report whether the observed result matches the requirement.

8. Delete temporary QA artifacts after verification:

```powershell
Remove-Item C:\Users\ZhuanZ1\Desktop\moe_social\emulator-current.png -ErrorAction SilentlyContinue
Remove-Item C:\Users\ZhuanZ1\Desktop\moe_social\window.xml -ErrorAction SilentlyContinue
```

## Constraints

- Do startup, log filtering, screenshot, and layout verification as needed; avoid extra screenshot artifacts beyond the current proof image.
- Do not claim emulator verification passed unless a screenshot, layout dump, or relevant logs were actually inspected.
- If the agent command channel cannot run `adb`, ask the user to run the exact commands and then read the generated files from the workspace.
- Keep generated QA artifacts in the workspace root using stable names while validating: `emulator-current.png`, `window.xml`, and optional short log files.
- Delete screenshots, UI dumps, and log files after verification unless the user explicitly asks to retain them.
- Do not commit emulator screenshots, UI dumps, or log files unless the user explicitly asks.

## Completion Note

When finishing a Flutter/Android user-facing task, include:

- What was changed.
- Which emulator checks ran.
- What was observed on screen or in logs.
- Whether temporary QA artifacts were deleted.
- Any remaining risk if emulator operation was unavailable.
