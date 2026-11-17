
# DockSense

A lightweight menu bar application for macOS. Automatically hides the Dock when a window completely fills the usable area of a screen; otherwise, keeps the Dock visible.

DockSense is a renamed and optimized version of the MasaustuDock project, designed to reduce periodic polling. The source code is written in Objective-C with no third-party dependencies.

## Status

Development version. [GitHub macOS tests](https://github.com/mephistoggz/DockSense/actions) and local universal builds have been verified. Application startup, Dock/window access, and the Dock hiding and reappearing during Finder's "Fill / Return to Previous Size" workflow have been tested on a Mac. Permission-based event monitoring, multi-display functionality, and actual battery savings have not yet been verified. Detailed results are available in `VALIDATION.md`.

## Energy Efficiency

- With Accessibility permission, the application monitors window movement and resizing events from the foreground application.
- Consecutive events are consolidated within a 250 ms debounce interval.
- Application, Space, and display changes are tracked through system notifications.
- When supported window notifications are available, a 15-second fallback polling interval is used. Without permission, or when an application does not support notifications, the interval is 3 seconds.
- Fallback timers use a 20% tolerance, allowing the system to consolidate scheduled operations.
- Window scanning stops during system sleep, display sleep, and inactive user sessions.
- Dock settings are modified only when necessary.
- The 8-point margin used by macOS window tiling is taken into account when determining whether a window fills the screen.

The previous version scanned every 0.4 seconds, resulting in approximately 9,000 scheduled checks per hour. Under idle conditions, the new version nominally schedules 240 checks (15-second interval) or 1,200 checks (3-second interval) per hour. These figures do not represent measured battery savings; window events can trigger additional checks, and overall energy consumption must be measured separately.

## Requirements and Build

- macOS 11 or later; Intel or Apple Silicon.
- Apple Command Line Tools or Xcode. Install using `xcode-select --install`.

```sh
sh tests/run.sh
open build/DockSense.app
```

The build supports both processor architectures and applies a local ad-hoc code signature. It does not include Developer ID signing or Apple notarization. The build script does not suppress compilation or signing errors and preserves the previous application bundle if a build fails.

## Usage

1. Quit the previous MasaustuDock application to prevent both applications from managing the same Dock setting simultaneously.
2. Launch DockSense. **DS** will appear in the menu bar.
3. Optionally, select **Grant Accessibility Permission for Efficient Mode…** and enable DockSense under System Settings → Privacy & Security → Accessibility. The application also works without this permission using periodic polling.
4. Select **Status and Check Count…** to view the active operating mode and the number of window scans performed.
5. Select **Quit DockSense** to restore the Dock setting that was active when the application launched.

Read-only diagnostics:

```sh
build/DockSense.app/Contents/MacOS/DockSense --diagnose
```

This command does not modify Dock settings or print window titles. The application does not establish network connections or transmit telemetry.

## Known Limitations

- Dock control depends on undocumented `CoreDock` functions inherited from the original project. If these functions are unavailable, the application displays an error without modifying the Dock settings. Compatibility with future macOS versions is not guaranteed.
- A window filling any connected display triggers automatic Dock hiding. There is currently no option to restrict detection to the display containing the Dock.
- Changes in background applications or applications that do not support window notifications may not be detected until the next fallback check. In event-based mode, this delay may reach approximately 15 seconds, plus timer tolerance.
- The Dock may briefly appear during startup, display configuration changes, or wake-up while the application measures the usable screen area.
- If DockSense crashes or is forcibly terminated, the previous Dock setting may not be restored.
- While DockSense is running, it manages the system's Dock auto-hide setting. Manual changes may be overridden during the next check.
- Launch at login, a dedicated application icon, and notarized distribution are not included in this version.

## Testing

`sh tests/run.sh` executes 16 geometry and timing validation checks, builds the application for both processor architectures, and verifies the application bundle's code signature. GitHub Actions is configured to run the same checks on macOS. These automated checks do not replace real-world desktop testing or battery consumption measurements; the manual testing checklist is available in `VALIDATION.md`.

## Technical References

- [Apple: AXObserverCreate](https://developer.apple.com/documentation/applicationservices/1460133-axobservercreate)
- [Apple: AXObserverAddNotification](https://developer.apple.com/documentation/applicationservices/1462089-axobserveraddnotification)
- [Apple: NSWorkspace Application Notifications](https://developer.apple.com/documentation/appkit/nsworkspace/didactivateapplicationnotification)
