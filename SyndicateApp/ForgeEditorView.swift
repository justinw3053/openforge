import SwiftUI

struct ForgeEditorView: View {
    @ObservedObject var viewModel: SyllabusViewModel
    @State private var consoleOutput: String = ""
    
    @State private var isVerifyHovered = false
    @State private var isResetHovered = false
    
    var body: some View {
        VSplitView {
            // Upper Panel: Discovery Lab Bento Card (Dynamic Theme)
            VStack(spacing: 0) {
                BentoPanel(title: "Discovery Playbook", systemIcon: "safari.fill", activeTheme: viewModel.activeTheme) {
                    if viewModel.activeContent != nil {
                        MarkdownWebView(markdown: viewModel.activeContent?.markdown ?? "")
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Forging playbook...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .frame(minHeight: 200)
            
            // Lower Panel: Code Stage Bento Card & Terminal Console
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    // Bento Code Stage (Dynamic Theme & Warp Styled)
                    VStack(alignment: .leading, spacing: 0) {
                        // Header bar
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 11))
                                .foregroundColor(viewModel.activeTheme.accentColor)
                            
                            Text("active_lab.py")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(viewModel.activeTheme == .warpDark || viewModel.activeTheme == .warpCarbon ? .white.opacity(0.6) : .secondary)
                            
                            Spacer()
                            
                            Button(action: resetCode) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset")
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(isResetHovered ? Color.primary.opacity(0.05) : Color.clear)
                                .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(viewModel.activeContent == nil)
                            .onHover { hovering in
                                self.isResetHovered = hovering
                            }
                            .scaleEffect(isResetHovered ? 1.02 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isResetHovered)
                            
                            Button(action: verifyCode) {
                                HStack(spacing: 6) {
                                    if viewModel.isRunningTests {
                                        ProgressView()
                                            .scaleEffect(0.4)
                                    } else {
                                        Image(systemName: "play.fill")
                                    }
                                    Text("Verify Code")
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 12)
                                .background(
                                    viewModel.isRunningTests 
                                    ? Color.gray 
                                    : (isVerifyHovered ? viewModel.activeTheme.accentColor.opacity(0.9) : viewModel.activeTheme.accentColor)
                                )
                                .cornerRadius(5)
                                .shadow(color: isVerifyHovered ? viewModel.activeTheme.accentColor.opacity(0.25) : .clear, radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(viewModel.activeContent == nil || viewModel.isRunningTests)
                            .onHover { hovering in
                                self.isVerifyHovered = hovering
                            }
                            .scaleEffect(isVerifyHovered ? 1.03 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isVerifyHovered)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Color.black.opacity(0.02))
                        
                        Divider()
                            .background(Color.primary.opacity(0.05))
                        
                        // Code Editor Pane - standard translucent/solid background
                        TextEditor(text: $viewModel.activeCode)
                            .font(.system(.body, design: .monospaced))
                            .padding(10)
                            .scrollContentBackground(.hidden) // CRITICAL FIX: Hides the default Cocoa text editor solid background!
                            .background(viewModel.activeTheme == .systemGlass ? Color.clear : viewModel.activeTheme.textEditorBackground)
                    }
                    .background(viewModel.activeTheme == .systemGlass ? AnyView(Color.clear.background(.thinMaterial)) : AnyView(viewModel.activeTheme.contentBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12)) // CRITICAL FIX: Forces perfect rounded corner clipping on the editor stage!
                    .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                    
                    // Warp-Style, High-Contrast Translucent Terminal Console (Hard-edges bug fixed via clipShape!)
                    if !consoleOutput.isEmpty {
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "terminal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(viewModel.activeTheme.accentColor)
                                
                                Text("Warp Console")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(viewModel.activeTheme == .warpDark || viewModel.activeTheme == .warpCarbon ? .white.opacity(0.6) : .secondary)
                                Spacer()
                                Button("Clear") {
                                    consoleOutput = ""
                                }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Color.black.opacity(0.15))
                            
                            Divider()
                                .background(Color.white.opacity(0.04))
                            
                            ScrollView {
                                // Real-time ANSI-colored logs!
                                AnsiText(text: consoleOutput)
                                    .padding(14)
                            }
                            .frame(height: 120)
                            .background(viewModel.activeTheme == .warpCarbon ? Color(red: 0.05, green: 0.05, blue: 0.05) : Color(red: 0.06, green: 0.08, blue: 0.11))
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12)) // CRITICAL FIX: Forces perfect, beautiful rounded clipping on all child containers!
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: consoleOutput)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(minHeight: 280)
        }
    }
    
    func resetCode() {
        if let content = viewModel.activeContent, let first = content.exercises.first {
            viewModel.activeCode = first.starter_code
        }
    }
    
    func verifyCode() {
        guard let content = viewModel.activeContent else { return }
        
        consoleOutput = "Spawning isolated Python verification subprocess...\n\n"
        viewModel.isRunningTests = true
        
        // Grab assertions for the active exercise
        let assertions = content.exercises.map { $0.assertions }.joined(separator: "\n")
        
        // Use persistent viewModel.executor instead of a localized struct member
        viewModel.executor.execute(
            code: viewModel.activeCode,
            assertions: assertions,
            onOutput: { output in
                // Safely update console text on @MainActor
                DispatchQueue.main.async {
                    self.consoleOutput += output
                }
            },
            onCompletion: { success in
                // Safely update state on @MainActor
                DispatchQueue.main.async {
                    viewModel.isRunningTests = false
                    if success {
                        self.consoleOutput += "\n\n\u{001B}[1;32m[SUCCESS] All assertions passed successfully! Playbook solved.\u{001B}[0m"
                        
                        if let selected = viewModel.selectedLesson {
                            Task {
                                await trackProgress(lessonId: selected.id)
                            }
                        }
                    } else {
                        self.consoleOutput += "\n\n\u{001B}[1;31m[FAILURE] Code verification failed. Ask Carl for Socratic guidance.\u{001B}[0m"
                    }
                }
            }
        )
    }
    
    func trackProgress(lessonId: String) async {
        guard let url = URL(string: "http://127.0.0.1:5050/api/track") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = ["lesson": lessonId]
        request.httpBody = try? JSONEncoder().encode(payload)
        
        _ = try? await URLSession.shared.data(for: request)
    }
}

// MARK: - Bespoke Bento Panel Container Component (Dynamic Glass)
struct BentoPanel<Content: View>: View {
    let title: String
    let systemIcon: String
    let activeTheme: AppTheme
    let content: Content
    
    init(title: String, systemIcon: String, activeTheme: AppTheme, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemIcon = systemIcon
        self.activeTheme = activeTheme
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card Header
            HStack(spacing: 8) {
                Image(systemName: systemIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(activeTheme.accentColor)
                
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(activeTheme == .warpDark || activeTheme == .warpCarbon ? .white.opacity(0.6) : .secondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Color.black.opacity(0.01))
            
            Divider()
                .background(Color.primary.opacity(0.05))
            
            // Card Content
            content
                .frame(maxHeight: .infinity)
        }
        .background(activeTheme == .systemGlass ? AnyView(Color.clear.background(.thinMaterial)) : AnyView(activeTheme.contentBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
    }
}
