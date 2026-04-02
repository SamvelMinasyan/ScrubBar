// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    public init() {}
    
    public var body: some View {
        TabView {
            // MARK: - General Tab
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            // MARK: - Patterns Tab
            CustomPatternsSettingsView()
                .tabItem {
                    Label("Patterns", systemImage: "text.magnifyingglass")
                }
            
            // MARK: - Detection Tab
            DetectionSettingsView()
                .tabItem {
                    Label("Detection", systemImage: "eye.slash")
                }
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
}

// MARK: - Subviews

public struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var recordingHotkey: HotkeyManager.HotkeyId?
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)
            
            // History limit
            HStack {
                Text("Clipboard history limit:")
                Spacer()
                Stepper(
                    "",
                    value: Binding(
                        get: { appState.historyLimit },
                        set: { appState.historyLimit = max(2, min(1000, $0)); appState.saveSettings() }
                    ),
                    in: 2...1000,
                    step: 10
                )
                Text("\(appState.historyLimit)")
                    .frame(width: 36, alignment: .trailing)
                    .fontWeight(.medium)
            }
            
            Divider()
            
            Text("Hotkeys")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Click Change, then press the new key combination (keep this window focused).")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HotkeyRow(
                label: "Scrub clipboard",
                id: .scrub,
                appState: appState,
                recordingHotkey: $recordingHotkey
            )
            HotkeyRow(
                label: "Restore clipboard",
                id: .restore,
                appState: appState,
                recordingHotkey: $recordingHotkey
            )
            HotkeyRow(
                label: "Clipboard history",
                id: .history,
                appState: appState,
                recordingHotkey: $recordingHotkey
            )
            
            Spacer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyRecorded)) { notification in
            recordingHotkey = nil
            guard (notification.userInfo?["cancelled"] as? Bool) != true,
                  let raw = notification.userInfo?["hotkeyIdRaw"] as? UInt32,
                  let id = HotkeyManager.HotkeyId(rawValue: raw),
                  let data = notification.userInfo?["configData"] as? Data,
                  let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) else { return }
            appState.saveHotkey(config, for: id)
        }
    }
}

private struct HotkeyRow: View {
    let label: String
    let id: HotkeyManager.HotkeyId
    @ObservedObject var appState: AppState
    @Binding var recordingHotkey: HotkeyManager.HotkeyId?
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            if recordingHotkey == id {
                Text("Press shortcut...")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(hotkeyDisplayString(
                    keyCode: appState.hotkeyConfig(for: id).keyCode,
                    modifiers: appState.hotkeyConfig(for: id).modifiers
                ))
                .fontWeight(.medium)
                Button("Change") {
                    recordingHotkey = id
                    NotificationCenter.default.post(name: .startHotkeyRecording, object: nil, userInfo: ["hotkeyIdRaw": id.rawValue])
                }
            }
        }
    }
}

struct CustomPatternsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddSheet = false
    @State private var newName = ""
    @State private var newRegex = ""
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text("Custom Patterns")
                .font(.headline)
            
            List {
                ForEach(appState.customPatterns) { pattern in
                    VStack(alignment: .leading) {
                        Text(pattern.name).font(.headline)
                        Text(pattern.regex).font(.caption).fontDesign(.monospaced)
                    }
                }
                .onDelete(perform: deletePattern)
            }
            
            HStack {
                Button(action: { showingAddSheet = true }) {
                    Label("Add Pattern", systemImage: "plus")
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VStack(spacing: 20) {
                Text("Add Custom Pattern").font(.headline)
                
                TextField("Name (e.g. EMP_ID)", text: $newName)
                TextField("Regex (e.g. EMP-\\d{6})", text: $newRegex)
                
                HStack {
                    Button("Cancel") { showingAddSheet = false }
                    Button("Save") {
                        if !newName.isEmpty && !newRegex.isEmpty {
                            let pattern = CustomPattern(name: newName, regex: newRegex)
                            appState.customPatterns.append(pattern)
                            appState.saveSettings()
                            newName = ""
                            newRegex = ""
                            showingAddSheet = false
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 300)
        }
    }
    
    func deletePattern(at offsets: IndexSet) {
        appState.customPatterns.remove(atOffsets: offsets)
        appState.saveSettings()
    }
}

struct DetectionSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    let allTypes = [
        "IP", "IPV6", "MAC", "URL", "EMAIL", "PHONE",
        "CC", "SSN", "DATE", "PASSPORT", "LICENSE", "VIN", "PLATE",
        "APIKEY", "AWSKEY", "AWSSECRET",
        "ANTHROPIC", "GOOGLEKEY", "AZUREKEY", "SLACK",
        "TWILIO", "SENDGRID", "JWT", "PRIVKEY", "PASSWORD"
    ]
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text("Enabled Detection Types")
                .font(.headline)
            
            List {
                ForEach(allTypes, id: \.self) { type in
                    Toggle(type, isOn: Binding(
                        get: { !appState.disabledTypes.contains(type) },
                        set: { isEnabled in
                            if isEnabled {
                                appState.disabledTypes.remove(type)
                            } else {
                                appState.disabledTypes.insert(type)
                            }
                            appState.saveSettings()
                        }
                    ))
                }
            }
        }
    }
}
