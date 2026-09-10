// Prints the window number of a process's first on-screen, normal-level window, so
// `screencapture -l` can capture that window and nothing else on the screen.
// Compiled and used by scripts/run-app.sh.
//
// Exits 1 when the process has no such window yet, which the script treats as "keep
// waiting" rather than as a failure.
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let pid = Int(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: window-id <pid>\n".utf8))
    exit(2)
}

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

let match = windows.first { window in
    (window[kCGWindowOwnerPID as String] as? Int) == pid
        && (window[kCGWindowLayer as String] as? Int) == 0
}

guard let id = match?[kCGWindowNumber as String] as? Int else { exit(1) }
print(id)
