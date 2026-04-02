// Copyright (c) 2025 Samvel Minasyan
// Licensed under the MIT License. See LICENSE file for details.

import SwiftUI
import Combine

public extension Notification.Name {
    static let historyArrowUp = Notification.Name("historyArrowUp")
    static let historyArrowDown = Notification.Name("historyArrowDown")
    static let historyPasteSelected = Notification.Name("historyPasteSelected")
}

public struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedIndex = 0
    
    // Callback to paste items
    public var onPaste: (HistoryItem, Bool) -> Void // item, scrubbed
    
    public init(onPaste: @escaping (HistoryItem, Bool) -> Void) {
        self.onPaste = onPaste
    }
    
    var filteredHistory: [HistoryItem] {
        if searchText.isEmpty {
            return appState.clipboardHistory
        }
        return appState.clipboardHistory.filter { item in
            switch item.type {
            case .text(let str):
                return str.localizedCaseInsensitiveContains(searchText)
            case .image:
                return false
            }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            TextField("Type to search...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .font(.system(size: 14))
                .onChange(of: searchText) { newValue in
                    selectedIndex = 0
                }
            
            Divider()
            
            // List - normal mouse wheel scrolling; selection only via tap or arrow keys
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredHistory.enumerated()), id: \.element.id) { index, item in
                            HistoryRow(
                                item: item,
                                isSelected: index == selectedIndex,
                                onTap: {
                                    selectedIndex = index
                                    onPaste(item, false)
                                },
                                onDelete: {
                                    appState.removeFromHistory(item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
                .onChange(of: selectedIndex) { newIndex in
                    if newIndex >= 0, newIndex < filteredHistory.count {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(filteredHistory[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .historyArrowUp)) { _ in
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .historyArrowDown)) { _ in
                if selectedIndex < filteredHistory.count - 1 {
                    selectedIndex += 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .historyPasteSelected)) { _ in
                if !filteredHistory.isEmpty, selectedIndex >= 0, selectedIndex < filteredHistory.count {
                    onPaste(filteredHistory[selectedIndex], false)
                }
            }
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(10)
        .frame(width: 500, height: 400)
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // PII Shield
            if !item.piiMatches.isEmpty {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.yellow)
                    .imageScale(.small)
            }
            
            // Content
            Group {
                switch item.type {
                case .text(let text):
                    Text(formatText(text))
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                        .foregroundColor(isSelected ? .white : .primary)
                case .image(let img):
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 30)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isHovering ? .primary : .secondary)
                    .opacity(isHovering ? 0.9 : 0.5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.8) : (isHovering ? Color.gray.opacity(0.2) : Color.clear))
        .cornerRadius(4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    func formatText(_ text: String) -> String {
        // Only visualize consecutive spaces and newlines
        var formatted = text.replacingOccurrences(of: "\n", with: "⏎ ")
        // Replace double spaces with dots to show structure but keep single spaces clean
        formatted = formatted.replacingOccurrences(of: "  ", with: "··")
        return formatted
    }
}

// Helper for visual blur
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
