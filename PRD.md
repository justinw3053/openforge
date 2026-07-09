# Product Requirement Document (PRD): Syndicate 3.0 Native macOS Socratic IDE (Production-Grade)

## 1. Core Objective
Transform the Syndicate 3.0 Python curriculum from flat Jupyter Notebooks into a premium, standalone macOS application designed for an adult developer. The app acts as a dedicated, fully offline, AI-powered Socratic IDE for learning Generative AI architecture from first principles. It replaces high-friction web technologies (Pyodide, Flask, PyWebView) with high-performance, native Apple Silicon technologies: SwiftUI, asynchronous subprocess execution via Swift's `Process` API, and direct integration with local Ollama model daemons and Metal-accelerated Local RAG.

---

## 2. Terminology & Branding Update
*   **The folksy partner-buddy mentor:** Named **Carl** (formerly Sebastian).
*   **Aesthetic & UX:** "The Forge" — premium, dark-themed, translucent macOS native style (San Francisco typography, SF Symbols, standard sidebar-detail-inspector panels).

---

## 3. High-Level Architecture

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

---

## 4. Key Modules & Functional Specifications

### A. The Syllabus Tree (Left Sidebar)
*   **Source Data:** The `/content/` directory which recursively contains the Syndicate 3.0 playbook folders (`phase_0_prep` up to `phase_10_syndicate`).
*   **Hierarchy Display:**
    *   **Phase Prep (Phase 0):** Dynamically unfolds into 8 individual, sequentially sorted sub-phase playbooks (e.g., `p0_env`, `p1_accumulators`, `p1_5_linalg`, ..., `p4_functions`).
    *   **Phases 1–10:** Displayed as standard, chronological, main-curriculum milestones.
*   **Robust Sorting Engine:** To prevent lexicographical sorting bugs (e.g., Phase 10 placing before Phase 1), the engine parses directory names and sub-phase filenames using a regex-based float key extractor (`dir_float`, `file_float`) to guarantee correct chronological flow.

### B. The Discovery Lab (Center Stage Pane)
*   **Interactive Lecture Display:** A premium, native markdown rendering component (e.g., Swift's native Markdown rendering or a highly optimized `WKWebView` with zero external assets) that loads the Markdown explanation blocks parsed dynamically from the active notebook cells.
*   **The Code Stage:** A native text editor panel with syntax highlighting displaying the starter code of the active exercise.
*   **Active Lab Syncing:** Selecting a lesson writes the starter code out into a workspace file named `active_lab.py` inside `/Users/justin/python-ai-academy/`.
*   **Hybrid External IDE Support (State Hash Lock):** The app runs an asynchronous `FSEvents` directory watcher on `active_lab.py` to support external editing in VS Code/Vim.
    *   **Race & Feedback Mitigation:** To prevent infinite write-read loop events, cursor/history loss, and coalescing window race conditions:
        1. **Strict Path Filtering:** The file watcher strictly filters file system events, only processing events where `eventPath == active_lab.py`. Changes to unrelated files are ignored.
        2. **Debounced Saves:** SwiftUI's automatic disk writes are debounced with a 1.5-second delay after the user stops typing to prevent competing write events.
        3. **State Hash Matching:** The app computes and stores a SHA-256 hash of SwiftUI's disk writes. On file watcher events, if the file's current hash matches our memory lock, the event is safely suppressed.
        4. **Non-Destructive Conflict UX:** If an external modification is detected by the file watcher while the local SwiftUI text buffer has unsaved, active modifications, the app displays a non-destructive conflict modal prompting: *"File modified externally. Would you like to Keep My Changes or Load Disk Version?"*, ensuring zero developer code loss.

### C. The Verification Loop (Asynchronous Subprocess)
*   **Isolated Execution:** Clicking "Verify" or "Run Tests" executes the user's code asynchronously via Swift's `Process` API, targeting the local workspace interpreter: `/Users/justin/python-ai-academy/.venv/bin/python`.
*   **Runtime Construction:** Since Syndicate 3.0 cells are completely self-contained, the Swift app writes the active cell's code directly to `verify_lab.py` and executes it.
*   **Responsiveness, Unbuffered Streams & Detach Safety:**
    *   **Main Thread Isolation:** Execution is dispatched onto a background serial `DispatchQueue` so the SwiftUI main thread remains responsive.
    *   **Unbuffered Outputs:** Python is invoked with the `-u` flag (`PYTHONUNBUFFERED=1`) to prevent output buffering, ensuring real-time log printing in the console tray.
    *   **Chronological Logging:** To prevent scrambled output, Swift redirects standard error to the standard output pipe (`process.standardError = process.standardOutput`) to enforce perfect, chronological, single-stream log serialization.
    *   **EOF Detach:** Swift's `FileHandle.readabilityHandler` streams execution logs. If the incoming data block length is `0` (indicating EOF), the handler is immediately set to `nil` to prevent 100% CPU lock spinning.
    *   **UI Thread Safety:** All SwiftUI state modifications from the background stream thread are strictly dispatched onto the `@MainActor`.
    *   **Process Group Watchdog:** To prevent student-coded infinite loops or orphaned child subprocesses from draining resources, the Swift app executes the process under a new **POSIX Process Group**. A **5-second watchdog timer** runs in parallel. If execution times out:
        1. Swift sends a `SIGTERM` signal to the process group (`-pgid`).
        2. If the group is still active after a 500ms grace period, a forceful `SIGKILL` is sent to the group to clean up all parent and child processes.
        3. A clean Socratic hint is displayed: *"Execution halted: CPU timeout exceeded. Check your loop boundaries."*

### D. The Comms Array (Right Panel)
*   **AI Engine API:** Queries the local Ollama API (`http://127.0.0.1:11434`) via asynchronous HTTP requests. It provides a native dropdown in the UI allowing the developer to switch models dynamically. 
    *   Using the loopback IP literal `127.0.0.1` bypasses DNS resolution entirely, avoiding active VPN or missing `/etc/hosts` resolution delays.
*   **Socratic Context Compiler:** When chatting or upon a verification failure, the prompt sent to Ollama dynamically packages:
    1. Active lesson objective & instructions.
    2. The developer's current code (`active_lab.py`).
    3. The execution output or stderr trace.
    4. Truncated conversation history (last 10 turns for prefill optimization).
*   **Carl's Long-Term Memory Ledger:** Uses a local student profile file `.pi/memory.txt` (or `.pi/Learning_Memory.md`). 
    *   Carl has the ability to append to this file dynamically. When Carl outputs structured tags (e.g., `<memory_update>Add: Student mastered linalg matrix multiplication after 2 failed attempts.</memory_update>`), the Swift app parses the tags, appends the notes to the local memory ledger, and loads this profile into future system context frames.

### E. Fully Offline Local RAG (Offline Study Mode)
*   **Integration Target:** A persistent, localized ChromaDB database stored in standard system application directories: `~/Library/Application Support/Syndicate/chroma_db`. This dynamically resolves the path across all users, avoiding hardcoded personal folders.
*   **The Persistent Python RAG Daemon:** Spawning a new Python process on every chat turn to load PyTorch/MPS (Metal Performance Shaders) for embedding queries adds 2–3 seconds of startup latency. To ensure a snappy <10ms experience, the SwiftUI app spawns a single, persistent Python RAG daemon on application boot.
*   **Pristine IPC via TCP Loopback Sockets:** To completely bypass the macOS 104-character Unix Domain Socket path length limit and permission restrictions, communication with the daemon occurs over a local **TCP Loopback Socket** (binding to `127.0.0.1` on port `0` to get an ephemeral free port). 
    *   The dynamically allocated port is passed to the Python daemon as a command-line argument on boot.
    *   Requests use a serialized JSON-RPC 2.0 protocol with unique request-response sequence IDs.
    *   All internal Python warnings/logs are redirected strictly to `sys.stderr` to keep the TCP data channel pristine.
*   **100% Offline Embedding Generation:** To eliminate heavy on-demand Hugging Face model downloads (which would fail on a plane or offline), the RAG daemon queries **Ollama's local `/api/embeddings` endpoint** (using a local embedding model like `nomic-embed-text`) to generate search vectors. This ensures the app operates with zero network requirements and avoids bundling heavy SentenceTransformers inside the Python environment.
*   **Model Gating & Load Indicators:**
    *   On application startup, the app queries Ollama's `/api/tags` to verify both the chat model and embedding model are present, displaying an interactive warn panel if models are missing before the developer goes offline.
    *   Sets a generous 60-second connection timeout specifically for the first-token model-loading phase (cold-starts), polling `/api/show` to display a *"Carl is waking up (loading model into unified memory)..."* UI progress indicator.
*   **Zombie Process Prevention (Orphan Watchdog):** To prevent background daemons from remaining active if the SwiftUI app crashes or is force-quit:
    1. **EOF Monitoring:** If the connection socket closes, the Python daemon instantly exits.
    2. **Orphan Monitor Thread:** The daemon runs a lightweight background thread that checks `os.getppid() == 1` (indicating it has been orphaned and adopted by launchd). Upon detection, the daemon cleanly closes its connections and exits.

---

## 5. Security & System Configurations
*   **macOS App Sandboxing:** STRICTLY DISABLED (`com.apple.security.app-sandbox = NO`) in the entitlements configuration. This is mandatory to allow execution of external `.venv/bin/python` interpreters and access to `/Users/justin/RAG/` directories.
*   **Distribution Gatekeeping:** To distribute outside the Mac App Store safely, sign the application with a valid Apple Developer ID and submit it for Apple Notarization (`altool`/`notarytool`).

---

## 6. Edge Cases & Error States
1. **Ollama Offline:** If Ollama is not running on local port 11434, display a clean native warning banner: *"Ollama daemon offline. Launch Ollama to activate Carl."*
2. **Missing Virtual Environment:** If `/Users/justin/python-ai-academy/.venv/` does not exist, display an onboard gating screen offering to automatically initialize the virtual environment and install requirements.
3. **Infinite Code Loops:** Captured by the 5-second watchdog kill-timer, printing a clean Socratic hint: *"Execution halted: CPU timeout exceeded. Check your loop boundaries."*
4. **Simultaneous External/Internal Saves:** The file watcher suppresses self-saves using the SHA-256 State Hash Lock. For actual conflicts (external save occurs while local editor has unsaved changes), display the non-destructive conflict modal (defined in Section 4B) to let the user choose between Keeping Local Changes or Loading the Disk Version. This guarantees zero developer code loss.
