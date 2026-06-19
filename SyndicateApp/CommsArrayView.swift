import SwiftUI

struct CommsArrayView: View {
    @ObservedObject var viewModel: ChatViewModel
    let currentCode: String
    let lessonId: String
    @ObservedObject var syllabusVM: SyllabusViewModel
    
    @State private var inputText: String = ""
    @State private var isSendHovered = false
    
    // Prompt History State
    @State private var promptHistory: [String] = []
    @State private var historyIndex: Int = -1
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Theme Selector & Model Selector
            HStack(spacing: 8) {
                // Theme Picker (Warp Dark, Carbon, Editorial, Liquid Glass)
                Picker("", selection: $syllabusVM.activeTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                
                Spacer()
                
                // Local Model Picker
                Picker("", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.black.opacity(0.04))
            
            Divider()
                .background(Color.primary.opacity(0.05))
            
            // Message Log
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(messageObj: message, activeTheme: syllabusVM.activeTheme)
                                .id(message.id)
                        }
                        
                        if viewModel.isTyping {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                Text(viewModel.statusMessage.isEmpty ? "Carl is formulating Socratic inquiry..." : viewModel.statusMessage)
                                    .font(.system(size: 11, design: .default))
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .id("typing")
                        }
                    }
                    .padding(.vertical, 16)
                }
                .onChange(of: viewModel.messages) {
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isTyping) {
                    scrollToBottom(proxy)
                }
            }
            
            Divider()
                .background(Color.primary.opacity(0.05))
            
            // Chat Input Bar (Warp-styled Multi-line and history aware)
            HStack(spacing: 12) {
                // Vertical-axis TextField auto-expands from 1 to 5 lines
                TextField("Ask Carl about the physics...", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.45))
                    .cornerRadius(8)
                    .font(.body)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    // Consolidated Single-Modifier Keyboard Listener (Bypasses Compiler Timeouts)
                    .onKeyPress { press in
                        if press.key == .return {
                            if press.modifiers.contains(.shift) {
                                inputText += "\n"
                                return .handled
                            } else {
                                sendMessage()
                                return .handled
                            }
                        } else if press.key == .upArrow {
                            handleUpArrow()
                            return .handled
                        } else if press.key == .downArrow {
                            handleDownArrow()
                            return .handled
                        }
                        return .ignored
                    }
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.4) : syllabusVM.activeTheme.accentColor)
                        .shadow(color: isSendHovered ? syllabusVM.activeTheme.accentColor.opacity(0.2) : .clear, radius: 4)
                        .padding(10)
                        .background(isSendHovered ? Color.primary.opacity(0.05) : Color.clear)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isTyping)
                .onHover { hovering in
                    self.isSendHovered = hovering
                }
                .scaleEffect(isSendHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSendHovered)
            }
            .padding(12)
            .background(Color.black.opacity(0.04))
        }
        .frame(minWidth: 340, maxWidth: 450)
        .overlay(
            GeometryReader { geo in
                HStack {
                    Rectangle()
                        .fill(Color.primary.opacity(0.05))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                    Spacer()
                }
            }
        )
    }
    
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // INTERCEPT SLASH COMMANDS: /new, /clear, /reset
        if text.lowercased() == "/new" || text.lowercased() == "/clear" || text.lowercased() == "/reset" {
            DispatchQueue.main.async {
                self.inputText = ""
                viewModel.clearChat()
            }
            return
        }
        
        // Save to local prompt history
        if promptHistory.last != text {
            promptHistory.append(text)
        }
        historyIndex = -1
        
        // Asynchronously clear input on MainActor to avoid text-field binding retention
        DispatchQueue.main.async {
            self.inputText = ""
        }
        
        Task {
            await viewModel.sendMessage(text, context: currentCode, lessonId: lessonId)
        }
    }
    
    func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if viewModel.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Prompt History Navigation Helpers
    private func handleUpArrow() {
        guard !promptHistory.isEmpty else { return }
        if historyIndex == -1 {
            historyIndex = promptHistory.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }
        inputText = promptHistory[historyIndex]
    }
    
    private func handleDownArrow() {
        guard !promptHistory.isEmpty && historyIndex != -1 else { return }
        if historyIndex < promptHistory.count - 1 {
            historyIndex += 1
            inputText = promptHistory[historyIndex]
        } else {
            historyIndex = -1
            inputText = ""
        }
    }
}

// MARK: - Native macOS Apple Messages Styled Chat Bubble (Liquid Glass)
struct ChatBubble: View {
    let messageObj: ChatMessage
    let activeTheme: AppTheme
    
    var body: some View {
        HStack {
            if messageObj.isUser {
                Spacer()
            }
            
            VStack(alignment: messageObj.isUser ? .trailing : .leading, spacing: 4) {
                Text(messageObj.text)
                    .font(.body)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .foregroundColor(messageObj.isUser ? .white : activeTheme.textColor)
                    .textSelection(.enabled) // CRITICAL: Enables native text highlighting and copying from Chat!
                    .background(
                        messageObj.isUser 
                        ? activeTheme.accentColor
                        : (activeTheme == .systemGlass 
                           ? Color(NSColor.controlBackgroundColor).opacity(0.55) // Translucent system bubble
                           : activeTheme.textEditorBackground) // Matching solid theme card backing
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(messageObj.isUser ? activeTheme.accentColor.opacity(0.2) : Color.primary.opacity(0.04), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
                
                Text(formatTime(messageObj.timestamp))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 4)
            }
            
            if !messageObj.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
struct Message {}
