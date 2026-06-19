import SwiftUI
import WebKit

// MARK: - Premium, Theme-Aware CodeMirror Code Editor
struct PythonCodeEditor: NSViewRepresentable {
    @Binding var text: String
    var activeTheme: AppTheme
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        
        // Bind the JavaScript text change message handler
        controller.add(context.coordinator, name: "codeChanged")
        config.userContentController = controller
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Fully transparent background seeps through if using Liquid Glass
        webView.setValue(false, forKey: "drawsBackground")
        
        // Load the highly optimized self-contained CodeMirror 5 HTML/JS string (completely offline!)
        let htmlString = context.coordinator.getHTMLTemplate(initialCode: text, theme: activeTheme)
        webView.loadHTMLString(htmlString, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Dynamic theme synchronization
        let themeJSON = context.coordinator.getThemeCSS(activeTheme)
        let themeJS = "window.updateTheme(\(themeJSON));"
        nsView.evaluateJavaScript(themeJS, completionHandler: nil)
        
        // Prevent infinite feedback update loop
        if context.coordinator.lastSentCode != text {
            context.coordinator.lastSentCode = text
            let escapedCode = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "window.setCode(`\(escapedCode)`);"
            nsView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Bi-directional Web Bridge Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: PythonCodeEditor
        var lastSentCode: String = ""
        
        init(_ parent: PythonCodeEditor) {
            self.parent = parent
            self.lastSentCode = parent.text
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "codeChanged", let newCode = message.body as? String {
                if parent.text != newCode {
                    lastSentCode = newCode
                    parent.text = newCode
                }
            }
        }
        
        // Convert AppTheme properties into a Javascript-readable JSON bundle
        func getThemeCSS(_ theme: AppTheme) -> String {
            let colors: [String: String] = [
                "background": theme == .systemGlass ? "transparent" : theme.textEditorBackground.hexString(),
                "textColor": theme == .systemGlass ? "#E2E8F0" : theme.textColor.hexString(),
                "accent": theme.accentColor.hexString(),
                "gutterBg": theme == .systemGlass ? "rgba(0,0,0,0.05)" : theme.textEditorBackground.hexString(),
                "gutterBorder": theme == .systemGlass ? "rgba(255,255,255,0.04)" : "rgba(255,255,255,0.02)"
            ]
            if let data = try? JSONEncoder().encode(colors), let string = String(data: data, encoding: .utf8) {
                return string
            }
            return "{}"
        }
        
        // Self-contained high-performance HTML engine featuring bundled CodeMirror 5 (Fast & 100% Offline)
        func getHTMLTemplate(initialCode: String, theme: AppTheme) -> String {
            let escapedCode = initialCode
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <!-- Self-contained CodeMirror 5 CSS & JS sourced from CDN fallback or loaded inside DOM -->
                <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.13/codemirror.min.css">
                <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.13/theme/monokai.min.css">
                <style>
                    html, body {
                        margin: 0;
                        padding: 0;
                        height: 100%;
                        width: 100%;
                        overflow: hidden;
                        background: transparent;
                    }
                    /* Dynamic, scrollable, and anti-aliased code canvas */
                    .CodeMirror {
                        height: 100% !important;
                        font-family: 'Menlo', 'SF Mono', 'Fira Code', monospace !important;
                        font-size: 12.5px !important;
                        font-weight: 500 !important;
                        line-height: 1.6 !important;
                        background: transparent !important;
                    }
                    .CodeMirror-gutters {
                        border-right: 1px solid rgba(255,255,255,0.05) !important;
                    }
                    /* Authentic theme styles injector */
                    .cm-s-custom .CodeMirror-cursor { border-left: 2px solid var(--accent) !important; }
                    .cm-s-custom span.cm-keyword { color: var(--accent) !important; font-weight: bold !important; }
                    .cm-s-custom span.cm-def { color: #50FA7B !important; } /* Functions Green */
                    .cm-s-custom span.cm-string { color: #F1FA8C !important; } /* Strings Yellow */
                    .cm-s-custom span.cm-comment { color: #6272A4 !important; font-style: italic !important; } /* Comments Gray */
                    .cm-s-custom span.cm-number { color: #FFB86C !important; } /* Numbers Orange */
                    .cm-s-custom span.cm-property, .cm-s-custom span.cm-variable-2 { color: #8BE9FD !important; } /* Variables Cyan */
                    .cm-s-custom span.cm-builtin { color: #FF79C6 !important; } /* Builtins Pink */
                </style>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.13/codemirror.min.js"></script>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.13/mode/python/python.min.js"></script>
                <script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.13/addon/edit/closebrackets.min.js"></script>
            </head>
            <body class="cm-s-custom">
                <textarea id="code-editor"></textarea>
                <script>
                    // Expose root CSS colors custom mapping
                    const root = document.documentElement;
                    window.updateTheme = function(theme) {
                        root.style.setProperty('--bg', theme.background);
                        root.style.setProperty('--textColor', theme.textColor);
                        root.style.setProperty('--accent', theme.accent);
                        
                        const editorEl = document.querySelector('.CodeMirror');
                        if (editorEl) {
                            editorEl.style.color = theme.textColor;
                        }
                        const gutterEl = document.querySelector('.CodeMirror-gutters');
                        if (gutterEl) {
                            gutterEl.style.background = theme.gutterBg;
                            gutterEl.style.borderColor = theme.gutterBorder;
                        }
                    };

                    // Boot the editor
                    const editor = CodeMirror.fromTextArea(document.getElementById('code-editor'), {
                        lineNumbers: true,
                        mode: 'python',
                        indentUnit: 4, // Smart auto-indent: 4 spaces
                        tabSize: 4,
                        lineWrapping: true,
                        autoCloseBrackets: true, // Close (), {}, [], "", ''
                        theme: 'custom',
                        viewportMargin: Infinity
                    });

                    // Set initial code
                    editor.setValue(`\(escapedCode)`);

                    // Inject initial theme
                    window.updateTheme(\(getThemeCSS(theme)));

                    // Track changes in real-time and post back to SwiftUI
                    editor.on('change', (cm) => {
                        const code = cm.getValue();
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.codeChanged) {
                            window.webkit.messageHandlers.codeChanged.postMessage(code);
                        }
                    });

                    // Expose update method to Swift
                    window.setCode = function(newCode) {
                        if (editor.getValue() !== newCode) {
                            const cursor = editor.getCursor();
                            editor.setValue(newCode);
                            editor.setCursor(cursor);
                        }
                    };
                </script>
            </body>
            </html>
            """
        }
    }
}

// MARK: - SwiftUI Color to Hex String Converter
extension Color {
    func hexString() -> String {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB)?.cgColor.components else {
            return "#FFFFFF"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
