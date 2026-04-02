// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import Foundation
import ScrubBarCore

let arguments = CommandLine.arguments

guard arguments.count > 1 else {
    print("Usage: ScrubBarCLI <file_path> [file_path...]")
    exit(1)
}

let filePaths = arguments.dropFirst()
let scrubber = FileScrubber()

print("ScrubBar File Obfuscation")
print("-------------------------")

for path in filePaths {
    let url = URL(fileURLWithPath: path)
    
    // Check if exists
    var isDir: ObjCBool = false
    if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
        print("❌ File not found: \(path)")
        continue
    }
    
    if isDir.boolValue {
        print("⚠️ Skipping directory: \(path)")
        continue
    }
    
    print("Processing: \(url.lastPathComponent)")
    
    do {
        let outputURL = try scrubber.scrubFile(at: url)
        print("✅ Created: \(outputURL.lastPathComponent)")
    } catch {
        print("❌ Failed: \(error)")
    }
}
