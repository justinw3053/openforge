import Foundation
import SwiftUI
import CryptoKit

// MARK: - Dynamic Theme Preset Enum
enum AppTheme: String, CaseIterable, Codable {
    case systemGlass = "Liquid Glass"
    case warpDark = "Warp Dark"
    case warpCarbon = "Warp Carbon"
    case warmEditorial = "Warm Editorial"
}

extension AppTheme {
    var accentColor: Color {
        switch self {
        case .systemGlass:
            return Color.accentColor // Native macOS system accent
        case .warpDark:
            return Color.cyan
        case .warpCarbon:
            return Color.orange
        case .warmEditorial:
            return Color(red: 0.39, green: 0.36, blue: 1.0) // Stripe Indigo
        }
    }
    
    var sidebarBackground: Color {
        switch self {
        case .systemGlass:
            return Color.clear
        case .warpDark:
            return Color(red: 0.04, green: 0.05, blue: 0.07)
        case .warpCarbon:
            return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .warmEditorial:
            return Color(red: 0.95, green: 0.95, blue: 0.94)
        }
    }
    
    var contentBackground: Color {
        switch self {
        case .systemGlass:
            return Color.clear
        case .warpDark:
            return Color(red: 0.06, green: 0.08, blue: 0.11)
        case .warpCarbon:
            return Color(red: 0.11, green: 0.11, blue: 0.11)
        case .warmEditorial:
            return Color(red: 0.97, green: 0.97, blue: 0.96)
        }
    }
    
    var textEditorBackground: Color {
        switch self {
        case .systemGlass:
            return Color.clear
        case .warpDark:
            return Color(red: 0.03, green: 0.04, blue: 0.06)
        case .warpCarbon:
            return Color(red: 0.06, green: 0.06, blue: 0.06)
        case .warmEditorial:
            return Color(red: 0.985, green: 0.985, blue: 0.98)
        }
    }
    
    var textColor: Color {
        switch self {
        case .systemGlass:
            return .primary
        case .warpDark, .warpCarbon:
            return .white
        case .warmEditorial:
            return Color(red: 0.09, green: 0.14, blue: 0.25)
        }
    }
}

// MARK: - Lesson Models
struct Lesson: Identifiable, Codable, Hashable {
    let id: String      // Relative path: e.g., "phase_0_prep/playroom_p0_env.ipynb"
    let title: String   // Parsed heading title
}

struct Exercise: Codable, Hashable {
    let starter_code: String
    let assertions: String
}

struct LessonContent: Codable, Hashable {
    let title: String
    let markdown: String
    let exercises: [Exercise]
}

// MARK: - Chat Models
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let isUser: Bool
    var text: String
    let timestamp = Date()
}

// MARK: - SHA-256 Hashing Helper
func sha256(_ string: String) -> String {
    let inputData = Data(string.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - Syllabus State Controller
@MainActor
class SyllabusViewModel: ObservableObject {
    @Published var lessons: [Lesson] = []
    @Published var selectedLesson: Lesson? = nil
    @Published var activeContent: LessonContent? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isRunningTests: Bool = false
    
    // Auto-save and Conflict State
    @Published var activeCode: String = "" {
        didSet {
            if !isInitialLoading {
                codeDidChange(to: activeCode)
            }
        }
    }
    
    @Published var lastWrittenHash: String = ""
    @Published var showConflictModal: Bool = false
    @Published var pendingExternalCode: String = ""
    
    // Multi-Exercise navigation state
    @Published var selectedExerciseIndex: Int = 0
    
    // Dynamic Active Theme (Saves persistently to UserDefaults)
    @Published var activeTheme: AppTheme = .systemGlass {
        didSet {
            UserDefaults.standard.set(activeTheme.rawValue, forKey: "lastSelectedTheme")
        }
    }
    
    // Persistent Subprocess Executor prevents View recreation leaks
    let executor = CodeExecutor()
    
    private let fileWatcher = FileWatcher()
    private var saveTask: Task<Void, Never>? = nil
    private var isInitialLoading: Bool = false
    private let workspacePath = "/Users/justin/python-ai-academy"
    
    init() {
        // Restore last selected theme on boot
        if let lastThemeStr = UserDefaults.standard.string(forKey: "lastSelectedTheme"),
           let restoredTheme = AppTheme(rawValue: lastThemeStr) {
            self.activeTheme = restoredTheme
        }
    }
    
    func fetchSyllabus() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "http://127.0.0.1:5050/api/lessons") else {
            self.errorMessage = "Invalid API URL"
            self.isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parsedLessons = try JSONDecoder().decode([Lesson].self, from: data)
            self.lessons = parsedLessons
            self.isLoading = false
            
            // Restore last selected lesson from UserDefaults on app launch, or default to first
            if let lastLessonId = UserDefaults.standard.string(forKey: "lastSelectedLessonId"),
               let matchedLesson = parsedLessons.first(where: { $0.id == lastLessonId }) {
                self.selectLesson(matchedLesson)
            } else if self.selectedLesson == nil, let first = parsedLessons.first {
                self.selectLesson(first)
            }
        } catch {
            self.errorMessage = "Backend offline. Run local server to connect."
            self.isLoading = false
        }
    }
    
    func selectLesson(_ lesson: Lesson) {
        self.selectedLesson = lesson
        self.activeContent = nil
        self.isInitialLoading = true
        self.activeCode = ""
        self.lastWrittenHash = ""
        self.selectedExerciseIndex = 0 // Reset to first exercise on workbook switch
        
        // Save selected lesson ID persistently across app restarts
        UserDefaults.standard.set(lesson.id, forKey: "lastSelectedLessonId")
        
        self.saveTask?.cancel() // CRITICAL FIX: Kill any pending auto-saves from the previous lesson
        self.saveTask = nil
        self.fileWatcher.stopWatching()
        self.executor.terminateActiveProcess() // Terminate any running test on lesson change
        
        Task {
            await fetchLessonContent(lesson)
        }
    }
    
    func fetchLessonContent(_ lesson: Lesson) async {
        guard let encodedId = lesson.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "http://127.0.0.1:5050/api/lessons/\(encodedId)") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let content = try JSONDecoder().decode(LessonContent.self, from: data)
            self.activeContent = content
            
            self.isInitialLoading = true
            self.selectedExerciseIndex = 0
            if let firstExercise = content.exercises.first {
                let starter = firstExercise.starter_code
                self.activeCode = starter
                
                // Asynchronously write active_lab.py to disk (non-blocking I/O)
                let activeLabPath = "\(workspacePath)/active_lab.py"
                DispatchQueue.global(qos: .background).async {
                    try? starter.write(toFile: activeLabPath, atomically: true, encoding: .utf8)
                }
                self.lastWrittenHash = sha256(starter)
            }
            self.isInitialLoading = false
            
            // Start watching active_lab.py asynchronously
            let activeLabPath = "\(workspacePath)/active_lab.py"
            self.fileWatcher.startWatching(filePath: activeLabPath) { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    self.fileDidChangeExternally()
                }
            }
            
        } catch {
            self.errorMessage = "Failed to load lesson content."
            self.isInitialLoading = false
        }
    }
    
    // MARK: - Multi-Exercise Selector (Non-blocking I/O)
    func selectExercise(index: Int) {
        guard let content = activeContent, index >= 0 && index < content.exercises.count else { return }
        
        // Terminate any active process running on the previous exercise
        self.executor.terminateActiveProcess()
        
        self.selectedExerciseIndex = index
        self.isInitialLoading = true
        
        let starter = content.exercises[index].starter_code
        self.activeCode = starter
        
        // Write selected exercise code to active_lab.py
        let activeLabPath = "\(workspacePath)/active_lab.py"
        DispatchQueue.global(qos: .background).async {
            try? starter.write(toFile: activeLabPath, atomically: true, encoding: .utf8)
        }
        self.lastWrittenHash = sha256(starter)
        self.isInitialLoading = false
    }
    
    // MARK: - Asynchronous Auto-Save Debouncer (Non-blocking I/O)
    private func codeDidChange(to newCode: String) {
        saveTask?.cancel()
        
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await autoSave(newCode)
        }
    }
    
    private func autoSave(_ code: String) async {
        let hash = sha256(code)
        self.lastWrittenHash = hash
        
        let activeLabPath = "\(workspacePath)/active_lab.py"
        DispatchQueue.global(qos: .background).async {
            try? code.write(toFile: activeLabPath, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - File Watcher Handler
    private func fileDidChangeExternally() {
        let activeLabPath = "\(workspacePath)/active_lab.py"
        
        // Load file asynchronously to prevent blocking MainActor UI thread
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let currentDiskCode = (try? String(contentsOfFile: activeLabPath, encoding: .utf8)) ?? ""
            let currentDiskHash = sha256(currentDiskCode)
            
            Task { @MainActor in
                if currentDiskHash == self.lastWrittenHash {
                    return
                }
                
                if self.activeCode != currentDiskCode && self.activeCode != "" {
                    self.pendingExternalCode = currentDiskCode
                    self.showConflictModal = true
                } else {
                    self.activeCode = currentDiskCode
                    self.lastWrittenHash = currentDiskHash
                }
            }
        }
    }
    
    func keepMyChanges() {
        showConflictModal = false
        let codeToSave = activeCode
        Task {
            await autoSave(codeToSave)
        }
    }
    
    func loadDiskVersion() {
        showConflictModal = false
        self.isInitialLoading = true
        self.activeCode = pendingExternalCode
        self.lastWrittenHash = sha256(pendingExternalCode)
        self.isInitialLoading = false
    }
}

// MARK: - Carl Socratic Chat Controller
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isTyping: Bool = false
    @Published var availableModels: [String] = []
    @Published var isOllamaOnline: Bool = true
    @Published var statusMessage: String = ""
    
    // Dynamic selectedModel that automatically saves to UserDefaults and unloads previous models
    @Published var selectedModel: String = "" {
        didSet {
            if !selectedModel.isEmpty {
                // Keep selected model persistent across app kills
                UserDefaults.standard.set(selectedModel, forKey: "lastSelectedModel")
                
                // UNLOAD PREVIOUS MODEL COMMAND (Free M5 Pro Unified memory immediately)
                if !oldValue.isEmpty && oldValue != selectedModel {
                    stopOllamaModel(oldValue)
                }
            }
        }
    }
    
    private let workspacePath = "/Users/justin/python-ai-academy"
    private var memoryText: String = ""
    
    init() {
        messages.append(ChatMessage(isUser: false, text: "Welcome to The Forge. I am Carl, your Socratic mentor. Choose a playbook to begin, or ask me any question about the implementation physics."))
        
        // Restore previous selection placeholder (fetchAvailableModels will match it against active local ones)
        if let lastModel = UserDefaults.standard.string(forKey: "lastSelectedModel") {
            self.selectedModel = lastModel
        }
        
        // Fetch local models on application startup
        Task {
            await fetchAvailableModels()
        }
    }
    
    func fetchAvailableModels() async {
        guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            struct TagsResponse: Codable {
                struct Model: Codable { let name: String }
                let models: [Model]
            }
            
            let response = try JSONDecoder().decode(TagsResponse.self, from: data)
            let names = response.models.map { $0.name }
            
            DispatchQueue.main.async {
                self.availableModels = names
                
                // Match lastSelectedModel against fetched list, fallback to first, or default
                if let lastModel = UserDefaults.standard.string(forKey: "lastSelectedModel"), names.contains(lastModel) {
                    self.selectedModel = lastModel
                } else if let first = names.first {
                    self.selectedModel = first
                } else {
                    self.availableModels = ["qwen2.5-coder:7b"]
                    self.selectedModel = "qwen2.5-coder:7b"
                }
                
                self.isOllamaOnline = true
                self.statusMessage = ""
            }
        } catch {
            DispatchQueue.main.async {
                self.availableModels = ["qwen2.5-coder:7b"]
                self.selectedModel = "qwen2.5-coder:7b"
                self.isOllamaOnline = false
                self.statusMessage = "Ollama Offline. Launch daemon on 127.0.0.1:11434"
            }
        }
    }
    
    /// Clears the chat log and resets the Socratic tutor state
    func clearChat() {
        messages = [
            ChatMessage(isUser: false, text: "Welcome to The Forge. I am Carl, your Socratic mentor. Choose a playbook to begin, or ask me any question about the implementation physics.")
        ]
        isTyping = false
        statusMessage = ""
    }
    
    /// Unloads a specific model from local Apple Silicon memory instantly
    func stopOllamaModel(_ model: String) {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct UnloadPayload: Codable {
            let model: String
            let prompt: String
            let keep_alive: Int
        }
        
        let payload = UnloadPayload(model: model, prompt: "", keep_alive: 0)
        request.httpBody = try? JSONEncoder().encode(payload)
        
        // Execute background network call silently (Ollama instantly frees memory)
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func sendMessage(_ text: String, context: String, lessonId: String) async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let userMsg = ChatMessage(isUser: true, text: text)
        messages.append(userMsg)
        
        isTyping = true
        statusMessage = "Consulting local RAG & loading Carl..."
        
        // 1. Asynchronously query local ChromaDB via our high-speed TCP daemon
        let ragResults = await RAGService.shared.queryRAG(query: text)
        let formattedRAG = ragResults.joined(separator: "\n\n")
        
        statusMessage = "Carl is waking up (loading model weights)..."
        
        // 2. Load the Socratic Memory asynchronously
        let memoryLedger = await loadMemoryLedger()
        
        // 3. Build Socratic prompt structures (System-Attention Isolated)
        let systemPrompt = """
        You are Carl, a brilliant, helpful Socratic tutor guiding an adult developer through the Syndicate 3.0 curriculum.
        Your primary directive: NEVER give out direct solution code!
        Instead, help them understand the physics of what they are doing by asking targeted questions, analyzing their tracebacks, or suggesting conceptual naive attempts.
        Keep your responses short, concise, and focused. You are a peer-programmer and mentor.
        
        If you discover a new milestone or recurring conceptual struggle, you have the special ability to write a structured update to the student's profile.
        To do so, output exactly: <memory_update>Add/Update details here</memory_update> at the very end of your response.
        """
        
        guard let url = URL(string: "http://127.0.0.1:11434/api/chat") else {
            isTyping = false
            return
        }
        
        // 4. Configure HTTP Request with 60-Second timeout
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct MessagePayload: Codable {
            let role: String
            let content: String
        }
        struct OllamaPayload: Codable {
            let model: String
            let messages: [MessagePayload]
            let stream: Bool
        }
        
        // CRITICAL FIX: Pack prompt into distinct role messages rather than single flat user text
        var messagesArray: [MessagePayload] = []
        
        // 1. SYSTEM ROLE MESSAGE: Hard guidelines, memory profile, and local RAG context
        let systemContent = """
        \(systemPrompt)
        
        Socratic Student Profile Memory:
        \(memoryLedger)
        
        Offline Documentation Vault (RAG Matches):
        \(formattedRAG)
        """
        messagesArray.append(MessagePayload(role: "system", content: systemContent))
        
        // 2. CHAT HISTORY: Append last 6 messages of context continuity
        let historyQueue = messages.suffix(7).dropLast() // Exclude the newly added user query
        for msg in historyQueue {
            if msg.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            messagesArray.append(MessagePayload(role: msg.isUser ? "user" : "assistant", content: msg.text))
        }
        
        // 3. USER ROLE MESSAGE: Workbook ID, Live editor python workspace code, and user query
        let userContent = """
        Curriculum Workbook ID: \(lessonId)
        My Active Code:
        ```python
        \(context)
        ```
        
        My Query: \(text)
        """
        messagesArray.append(MessagePayload(role: "user", content: userContent))
        
        let payload = OllamaPayload(model: selectedModel, messages: messagesArray, stream: true)
        request.httpBody = try? JSONEncoder().encode(payload)
        
        // 5. Stream response using modern URLSession bytes async sequence
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                appendCarlReply("Error: Local model failed to respond. Code: 500")
                isTyping = false
                return
            }
            
            statusMessage = ""
            
            var fullText = ""
            let assistantMsg = ChatMessage(isUser: false, text: "")
            messages.append(assistantMsg)
            let assistantIndex = messages.count - 1
            
            struct OllamaResponse: Codable {
                struct Message: Codable {
                    let content: String
                }
                let message: Message
                let done: Bool
            }
            
            for try await line in bytes.lines {
                guard let lineData = line.data(using: .utf8) else { continue }
                if let chunk = try? JSONDecoder().decode(OllamaResponse.self, from: lineData) {
                    fullText += chunk.message.content
                    
                    // Render with memory tags stripped in real-time (prevents UI flicker)
                    let cleanedText = stripMemoryTags(fullText)
                    messages[assistantIndex].text = cleanedText
                }
            }
            
            // 6. Post-processing: Extract memory updates if Carl outputted any
            parseAndProcessMemoryUpdate(fullText)
            isTyping = false
            
        } catch {
            statusMessage = "Ollama connection timeout. Try a lighter model."
            appendCarlReply("Sorry, my connection to the local model timed out. Let's try that again.")
            isTyping = false
        }
    }
    
    private func appendCarlReply(_ text: String) {
        messages.append(ChatMessage(isUser: false, text: text))
    }
    
    // MARK: - Memory Ledger Operations (Asynchronous Non-blocking)
    private func loadMemoryLedger() async -> String {
        let memoryPath = "\(workspacePath)/.pi/memory.txt"
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let content = (try? String(contentsOfFile: memoryPath, encoding: .utf8)) ?? ""
                continuation.resume(returning: content)
            }
        }
    }
    
    private func appendMemoryUpdate(_ update: String) {
        let memoryPath = "\(workspacePath)/.pi/memory.txt"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        
        let newEntry = "\n- [\(dateStr)] \(update)"
        
        DispatchQueue.global(qos: .background).async {
            if let fileHandle = FileHandle(forWritingAtPath: memoryPath) {
                fileHandle.seekToEndOfFile()
                if let data = newEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                try? fileHandle.close()
            } else {
                try? newEntry.write(toFile: memoryPath, atomically: true, encoding: .utf8)
            }
        }
    }
    
    private func parseAndProcessMemoryUpdate(_ text: String) {
        let pattern = "<memory_update>([\\s\\S]*?)</memory_update>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for result in results {
            if result.numberOfRanges > 1 {
                let innerRange = result.range(at: 1)
                let updateText = nsString.substring(with: innerRange).trimmingCharacters(in: .whitespacesAndNewlines)
                appendMemoryUpdate(updateText)
            }
        }
    }
    
    /// Hides memory tags in real-time by truncating anything starting from "<memory_update>"
    private func stripMemoryTags(_ text: String) -> String {
        if let range = text.range(of: "<memory_update>") {
            return String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}
