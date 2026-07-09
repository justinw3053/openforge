# OpenForge: Native macOS Socratic IDE

OpenForge is a premium, standalone, local-first macOS application designed as an AI-powered Socratic IDE for learning Generative AI and Python from first principles. Built natively in **SwiftUI** and powered by local, metal-accelerated **Ollama** models and **ChromaDB**, the app runs completely bare-metal and **100% offline**, allowing developers to study and write code on a plane or without an internet connection.

---

## 🧭 The Vision
Rather than an external, noisy browser chat panel, OpenForge embeds your folksy mentor and buddy—**Carl**—directly inside a highly responsive, custom-tailored macOS desktop workspace. 

Carl acts as a peer programmer who guides you step-by-step using plain-spoken physical analogies, clear blueprints, and folksy Southern encouragement. He keeps his foot down on writing code yourself, unless you explicitly trigger the "drop the rules" bypass command to have him swing the hammer directly.

---

## 🏗️ High-Performance Architecture

```
+-----------------------------------------------------------------------------+
|                            SwiftUI Native macOS App                         |
|  +-------------------+  +----------------------------+  +----------------+  |
|  |  Syllabus Sidebar |  |    The Forge (Editor)      |  |  Comms Array   |  |
|  |  (Notebook list)  |  |  (Markdown + Active Code)  |  |  (Carl Chat)   |  |
|  +-------------------+  +----------------------------+  +----------------+  |
+--------------------------------------|---------------------------|----------+
                                       |                           |
                  Subprocess IPC       v                           v   Local HTTP
          +--------------------------------------+            +------------------+
          |      Python CLI Helper Bridge        |            |   Local Ollama   |
          | (Parses notebooks, verifies code)    |            | (Llama/Qwen/etc.)|
          +--------------------------------------+            +------------------+
                            |
                            v
                    Local Venv Setup
                  (active_lab.py, tests)
```

1. **Vibrant Liquid Glass UI (SwiftUI):** Rejects default, gray-on-gray system panels for a translucent, wallpaper-reflective design backed by macOS’s native `.behindWindow` material layers. 
2. **Asynchronous Subprocess Executor (POSIX Process Groups):** Code verification scripts are written to `verify_lab.py` and compiled via Swift's `Process` targeting your local `.venv/bin/python` asynchronously. Infinite student loops are captured by a 5-second watchdog which sends `SIGTERM/SIGKILL` to the entire POSIX Process Group (`-pgid`), preventing zombie resource leaks.
3. **Pristine TCP Loopback RAG Daemon (Microsecond Lookups):** Spawns a background Python RAG client on app launch. Swift binds to an ephemeral port on `127.0.0.1` and establishes high-speed JSON-RPC communication, bypassing macOS's 104-character Unix Domain Socket (UDS) path length limits. The daemon queries local Ollama embeddings and searches your local ChromaDB persistent collection completely offline.
4. **Self-Terminating Orphan Watchdogs:** Both background Python processes (the Flask content engine and the RAG daemon) run active background watchdogs checking `os.getppid() == 1`. If the parent Swift app is terminated (even forcefully via Xcode's "Stop" `SIGKILL`), both servers instantly self-terminate in under 500ms, immediately freeing up local ports and sockets.

---

## ✨ Features
* **Bento Grid 2.0 Card Sheets:** Beautifully structured stages bordered by thin system strokes and soft shadows, appearing like physical sheets of paper resting on a wooden desk.
* **Prefers-Color-Scheme LaTeX Rendering:** Embedded Transparent `WKWebView` wrapping `marked.js` and **MathJax 3.0**. Dynamic CSS media queries automatically flip body text from high-contrast Slate Charcoal (`#1E293B`) in Light Mode to a glowing off-white (`#F1F5F9`) in Dark Mode, ensuring perfect, razor-sharp mathematical legibility under all system settings.
* **Elastic Spring Hover Physics:** Sidebar playbook nodes, buttons, and send triggers are equipped with custom hover sensors (`.onHover`) and elastic spring animations (`.spring(response: 0.22, dampingFraction: 0.65)`).
* **UserDefaults State Preservation:** Remembers your last-selected local model across app runs.
* **Instant Apple Silicon VRAM Unload (`keep_alive: 0`):** Switching models in the dropdown instantly sends an unload POST request to Ollama, immediately freeing up your Mac's unified VRAM before loading the new weights.
* **Invisible Memory ledger syncing:** Automatically parses Carl's responses for `<memory_update>` tags, writes the progress milestones to `.pi/memory.txt` in the background, and strips the tags in real-time to keep Carl's self-reflection invisible.

---

## 🚀 How to Run It

### Prerequisites:
1. Ensure you have **Xcode Command Line Tools** active on your Mac.
2. Install and launch the local **Ollama** daemon, ensuring you have at least one coding model (e.g. `qwen2.5-coder:7b`) and an embedding model (`nomic-embed-text`) downloaded.

### Run stand-alone:
You can build and run the entire application natively from your command-line with a single command:
```bash
swift run
```
*(The Swift compiler will compile your resources, boot both background Python daemons silently, and present your translucent liquid-glass window instantly.)*

### Run in Xcode:
To open and run inside Xcode:
1. Open the project folder in Xcode:
   ```bash
   open OpenForge.xcodeproj
   ```
2. Press **`Cmd + R`** (or click **Play**) to compile, run, and attach the Xcode debugger.

*(Note: macOS App Sandboxing is strictly disabled in `OpenForge.entitlements` to allow direct execution of your workspace `.venv/bin/python` interpreter and read-access to your local RAG directories).*
