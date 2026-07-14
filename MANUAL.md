# Odysseus - Complete User and Deployment Manual

Version 1.0 | Self-Hosted AI Workspace

---

## Table of Contents

1. [What is Odysseus?](#what-is-odysseus)
2. [System Requirements](#system-requirements)
3. [Installation - Linux / WSL2 (Recommended)](#installation---linux)
4. [Installation - Windows](#installation---windows)
5. [Installation - Manual](#installation---manual)
6. [First Login and Initial Setup](#first-login-and-initial-setup)
7. [Configuring Your AI Models](#configuring-your-ai-models)
8. [Features Guide](#features-guide)
   - Chat
   - Agent
   - Deep Research
   - Documents
   - Compare
   - Cookbook (Model Manager)
   - Memory and Skills
   - Email
   - Calendar and Notes
   - Gallery
9. [Settings Reference](#settings-reference)
10. [Deployment - Production / LAN / Docker](#deployment)
11. [Troubleshooting](#troubleshooting)

---

## What is Odysseus?

Odysseus is a self-hosted AI workspace that runs entirely on your own computer.
It is the private, local alternative to ChatGPT and Claude.ai. Your data never
leaves your machine. You connect it to whatever AI model you already have running
(Ollama, LM Studio, vLLM, or a cloud API like OpenAI/Anthropic/OpenRouter).

Core capabilities:
- Chat with any local or cloud AI model
- Run autonomous agents that use tools (web, files, shell, code)
- Conduct multi-step deep research with auto-generated reports
- Write and edit documents with AI assistance
- Manage persistent memory that grows with use
- Read and triage email with AI
- Sync calendars via CalDAV
- Download and serve local models via the Cookbook

---

## System Requirements

Odysseus runs on Linux, macOS, and Windows. Pick whichever you run daily.

Minimum:
- Linux (Ubuntu/Debian, Fedora, Arch), macOS, or Windows 10/11 (64-bit)
- Python 3.11 or newer (3.12 recommended)
- 4 GB RAM
- 2 GB free disk space (plus model storage if using local models)

Recommended:
- A 64-bit OS you already use
- Python 3.12
- 8+ GB RAM
- An Ollama install with at least one model downloaded
- tmux (Linux/macOS, for Cookbook background model downloads/serves)
- Git (for the agent shell tool and Cookbook)

Optional for local AI (GPU acceleration):
- NVIDIA GPU with 8+ GB VRAM for running models via Ollama (Linux/WSL2 for vLLM/SGLang)
- Ollama installed and running: https://ollama.com/download

---

## Installation - Linux

### One-Command Install (Recommended)

From a terminal in the Odysseus folder:

```bash
./start-linux.sh
```

The launcher will:
- Find a Python 3.11+ interpreter
- Create a virtual environment in `venv/`
- Install all required packages (takes a few minutes on first run)
- Run first-time setup (creates the database, config files, and admin account)
- Optionally start a local ChromaDB for vector memory
- Open your browser to http://localhost:7000

Safe to re-run after updates; it skips work that is already done.

Environment overrides (optional):
- `ODYSSEUS_PORT=7001 ./start-linux.sh` - use a different port
- `ODYSSEUS_HOST=0.0.0.0 ./start-linux.sh` - expose on your LAN/Tailscale (keep AUTH_ENABLED=true)
- `ODYSSEUS_NO_OPEN=1 ./start-linux.sh` - do not auto-open a browser (SSH/headless)
- `ODYSSEUS_NO_CHROMA=1 ./start-linux.sh` - skip the local ChromaDB bootstrap

If the launcher reports a missing system tool, install it once:

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y python3 python3-venv python3-pip tmux

# Fedora / RHEL
sudo dnf install -y python3 python3-devel tmux

# Arch
sudo pacman -S --noconfirm python tmux
```

### Run as a background service (starts on boot)

```bash
sudo ./install-service.sh
```

This auto-detects your user and repo path, installs a systemd unit, and enables
Odysseus to start on boot. Check it with `systemctl status odysseus-ui` and read
logs with `journalctl -u odysseus-ui -f`.

---

## Installation - Windows

### One-Click Install

1. Open the Odysseus folder
2. Double-click `INSTALL.bat`
3. The installer will:
   - Check your Python version
   - Create a virtual environment
   - Install all required packages (takes 2-5 minutes on first run)
   - Install PDF viewer support (PyMuPDF)
   - Run first-time setup (creates database, config files, admin account)
   - Create a desktop shortcut called "Odysseus AI"
   - Open your browser to http://localhost:7000

After the first install, use the desktop shortcut or `START.bat` to launch.

### If the installer prompts for a password

On first run, setup.py may ask you to create an admin username and password.
Enter your chosen credentials. These are stored locally only.

If you want to pre-set them without prompts, create a `.env` file in the
Odysseus folder with:

```
ODYSSEUS_ADMIN_USER=yourusername
ODYSSEUS_ADMIN_PASSWORD=yourpassword
```

Then run the installer. Delete these lines from `.env` after the first run.

---

## Installation - Manual

If you prefer step-by-step control:

```powershell
# 1. Open PowerShell in the Odysseus folder

# 2. Create a virtual environment with Python 3.12
py -3.12 -m venv venv

# 3. Activate it
venv\Scripts\Activate.ps1

# 4. Install dependencies
pip install -r requirements.txt
pip install PyMuPDF          # PDF viewer (optional but recommended)

# 5. Run first-time setup
python setup.py

# 6. Start the server
python -m uvicorn app:app --host 127.0.0.1 --port 7000
```

Then open http://localhost:7000 in your browser.

---

## First Login and Initial Setup

1. Open http://localhost:7000 in your browser
2. Log in with the admin credentials you set during install
   (default username: admin, password was shown in the terminal during setup)
3. You will land on the main Chat page
4. Open Settings (gear icon or Ctrl+Shift+U) to configure your AI model

### Essential first-time settings

Go to Settings > Model Endpoints and add your AI provider:

**If using Ollama (local):**
- Name: Ollama
- Base URL: http://localhost:11434/v1
- No API key needed
- Click Refresh to see your downloaded models
- Set one as the Default Model

**If using OpenAI:**
- Name: OpenAI
- Base URL: https://api.openai.com/v1
- API Key: your OpenAI API key
- Default model: gpt-4o (recommended)

**If using OpenRouter (access to many models):**
- Name: OpenRouter
- Base URL: https://openrouter.ai/api/v1
- API Key: your OpenRouter key
- Default model: any model from their catalog

---

## Configuring Your AI Models

Odysseus separates models by role. Set each in Settings > Models:

| Role | Purpose | Recommendation |
|------|---------|----------------|
| Default Model | All chat and agent tasks | Your best local model or GPT-4o |
| Utility Model | Summarization, auto-naming | A fast, small model |
| Research Model | Deep Research runs | Your most capable model |
| Task Model | Scheduled automation | A reliable mid-size model |
| Vision Model | Analyzing images/PDFs | A multimodal model (e.g. llava) |

If you only have one model, set it as Default and leave the others blank.
Odysseus will fall back to the Default for everything.

### Ollama model recommendations (by hardware)

8 GB VRAM:
- gemma2:9b (general chat, fast)
- llama3.1:8b (good balance)
- mistral:7b (fast, capable)

16 GB VRAM:
- gemma2:27b (strong, recommended)
- llama3.1:70b-q4 (excellent quality)
- qwen2.5:14b (strong reasoning)

32 GB+ VRAM:
- llama3.1:70b (best open-source quality)
- qwen2.5:72b (top-tier reasoning)
- mixtral:8x7b (good for long context)

CPU only (slow but works):
- phi3:mini (very fast on CPU)
- gemma2:2b (lightweight)

---

## Features Guide

### Chat

The main interface. Type a message and press Enter (or Shift+Enter for newline).

Key features:
- **Attach files**: Click the paperclip icon. Supports PDF, images, text, Office docs
- **Web search**: Type your question, the agent will search the web if needed
- **Code execution**: The agent can write and run code
- **Sessions**: Each conversation is saved. Use the sidebar to switch sessions
- **Incognito mode**: Start a session that won't be saved (padlock icon)
- **Presets**: Save system prompts and settings as presets for quick reuse

Keyboard shortcuts:
- Ctrl+K: Search sessions
- Ctrl+B: Toggle sidebar
- Ctrl+Alt+N: New session
- Escape: Cancel generation

### Agent

The agent is Chat with tools enabled. It can:
- Search the web and read pages
- Read and write files on your computer
- Run shell commands (with your approval)
- Use MCP servers (external integrations)
- Manage memory, notes, calendar events

Enable agent mode by clicking the robot/tool icon in the message bar.

Agent settings (Settings > Agent):
- Max Rounds: how many tool-call cycles per message (default 20)
- Max Tool Calls: safety cap on total tool invocations (0 = unlimited)
- Stream Timeout: how long to wait for a slow model response

### Deep Research

Deep Research runs an autonomous multi-round search and synthesis loop.
It searches the web, reads sources, and writes a comprehensive report.

How to use:
1. Click the flask/research icon in the chat bar, or go to the Research tab
2. Type your research question
3. Optionally review the research plan before starting
4. Watch the progress: Planning > Searching > Reading > Analyzing > Writing
5. The final report appears as a formatted document with citations

Research works best when:
- Your research model is your most capable model
- A web search provider is configured (SearXNG, Brave, or DuckDuckGo)
- You give specific, detailed questions rather than vague ones

Research settings (Settings > Research):
- Research Model: set to your best model
- Max Tokens: 16384 (default, increase for longer reports)
- Run Timeout: 1800 seconds (30 min, enough for deep runs)
- Extraction Concurrency: 3 parallel URL reads (safe default)

### Documents

A full markdown/HTML/CSV editor with AI assistance.

Features:
- Multi-tab editor
- Syntax highlighting
- AI can suggest edits, rewrite sections, or expand paragraphs
- Export to HTML or copy as Markdown

Use cases:
- Drafting reports from research
- Writing documentation
- Long-form content that benefits from AI assistance

### Compare

Side-by-side model comparison tool.

How to use:
1. Go to Compare from the sidebar
2. Select two or more models
3. Type a prompt
4. See each model's response side by side
5. Enable Blind Mode to evaluate without knowing which model is which

Useful for:
- Testing which model handles your specific use cases better
- Evaluating quality of local models vs. cloud models
- Finding the best model for a particular task type

### Cookbook (Model Manager)

Manages local model downloads and serving.
Only relevant if you want to serve models directly through Odysseus
rather than via Ollama.

Main tabs:
- What Fits?: scans your GPU/CPU, recommends models that will run well
- Download: browse and download models from Hugging Face
- Serve: launch a downloaded model as an API server
- Dependencies: install llama.cpp, vLLM, or SGLang runtimes

Note: On Windows, vLLM and SGLang require WSL2. For local GPU serving on
Windows, Ollama is the recommended and easiest path.

### Memory and Skills

**Memory** is a persistent fact store. The agent writes notes about you and
your preferences as you use it. Over time it remembers your context.

- View and manage memories: click the brain icon or go to /memory
- Import/export: backup your memory to JSON
- Search: semantic search over all memories
- The agent auto-reads relevant memories before each response

**Skills** are reusable instructions the agent has learned or you have taught it.
- A skill is a SKILL.md file the agent can invoke
- Skills auto-save when the agent learns a repeatable workflow
- Manage skills in Settings > Skills
- The agent auto-injects up to 3 relevant skills per request

### Email

Connect IMAP/SMTP email accounts for AI triage.

Setup (Settings > Email):
1. Add account with IMAP host, port, username, and password
2. Set AI triage options: urgency detection, auto-tagging, auto-summary
3. The agent can draft replies on your behalf

Limitations:
- Requires IMAP/SMTP with password auth
- Microsoft/Outlook OAuth is not yet supported (use an app password or
  a non-Microsoft provider)

### Calendar and Notes

**Calendar**: CalDAV sync to Radicale, Nextcloud, Apple, or Fastmail.
- Add calendars in Settings > Calendar
- Import .ics files
- The agent can create and read events

**Notes**: Quick markdown notes with reminders.
- Create notes from any chat message
- Set reminders via browser notification, email, or ntfy
- The agent can create, read, and complete notes and tasks

### Gallery

Image library for generated and uploaded images.

- Upload images for vision analysis
- Generate images if an image generation endpoint is configured
- Edit images with the built-in editor (crop, annotate, transform)
- Signatures: save reusable image stamps

---

## Settings Reference

Access via: Settings (gear icon) or Ctrl+Shift+U

### Model Endpoints
Add, edit, enable/disable LLM providers. Each endpoint has:
- Base URL: the API root (e.g. http://localhost:11434/v1)
- API Key: required for cloud providers, blank for local
- Models: refreshed list of available models

### Models
Assign models to roles (Default, Utility, Research, Task, Vision).
Set fallbacks for each role.

### Research
Key settings for Deep Research quality:
- Research Model: your best model for research tasks
- Max Tokens: maximum tokens per research report generation (default 16384)
- Run Timeout: maximum wall-clock time for one research run (default 1800s)
- Extraction Timeout: timeout per URL fetch+extract (default 90s)
- Planning Timeout: timeout for the planning LLM call (default 90s)
- Query Timeout: timeout for query generation (default 90s)
- Extraction Concurrency: parallel URL reads (default 3)

### Agent
- Max Rounds: tool-call cycles per turn (default 20)
- Max Tool Calls: hard cap on tool uses (0 = unlimited)
- Input Token Budget: context passed to agent (default 6000)
- Stream Timeout: generation timeout (default 300s)

### Search
Configure web search for chat and research:
- Provider: searxng (self-hosted), brave (API key), duckduckgo (free), tavily, serper
- Result Count: search results per query (default 5; increase for research depth)
- SafeSearch: strict / moderate / off
- Research Search Provider: override for research specifically

### Security
- AUTH_ENABLED: require login (default true, keep enabled)
- LOCALHOST_BYPASS: skip auth for loopback (only for local dev, keep false)
- SECURE_COOKIES: enable when behind HTTPS proxy

---

## Deployment

### Local only (default)

The default setup binds to 127.0.0.1:7000. Only your machine can reach it.
This is the safest configuration and requires no extra setup.

### LAN access (other devices on your network)

1. Edit `.env` in the Odysseus folder:
   ```
   APP_BIND=0.0.0.0
   APP_PORT=7000
   ```
2. Keep `AUTH_ENABLED=true`
3. Restart Odysseus
4. Other devices access: http://YOUR_PC_IP:7000

Find your PC IP:
```powershell
ipconfig | findstr IPv4
```

### Tailscale (secure remote access)

1. Install Tailscale on both machines: https://tailscale.com
2. Set APP_BIND=0.0.0.0 in .env
3. Access via your Tailscale IP: http://100.x.y.z:7000

### Docker (includes ChromaDB, SearXNG, ntfy)

Docker gives you the full stack with vector memory and web search bundled:

```bash
cp .env.example .env
docker compose up -d --build
```

Services started:
- Odysseus on port 7000
- ChromaDB (vector memory) on port 8100
- SearXNG (private web search) on port 8080
- ntfy (push notifications) on port 8091

### Running as a Windows Service (always-on)

To run Odysseus as a Windows background service:

1. Install NSSM: https://nssm.cc/download
2. Open an admin PowerShell:
```powershell
nssm install Odysseus "C:\path\to\Odysseus\venv\Scripts\python.exe"
nssm set Odysseus AppParameters "-m uvicorn app:app --host 127.0.0.1 --port 7000"
nssm set Odysseus AppDirectory "C:\path\to\Odysseus"
nssm set Odysseus DisplayName "Odysseus AI Workspace"
nssm start Odysseus
```
3. Odysseus now starts automatically with Windows

---

## Troubleshooting

### App won't start / port in use
```
Error: address already in use
```
Change the port: edit `.env` and set `APP_PORT=7001`, then restart.
Or find and stop the process using port 7000:
```powershell
netstat -ano | findstr :7000
taskkill /PID <pid> /F
```

### "PDF file could not be opened - not installed"
PyMuPDF is not installed. Run:
```powershell
venv\Scripts\pip install PyMuPDF
```
Then restart Odysseus. (Already fixed in this installation.)

### No models showing / model dropdown empty
1. Make sure Ollama is running: `ollama serve`
2. Make sure you have at least one model: `ollama list`
3. In Odysseus Settings > Model Endpoints, click Refresh on the Ollama endpoint
4. Check the Base URL is correct: http://localhost:11434/v1

### ChromaDB warnings on startup
```
VectorRAG init failed: ChromaDB is not reachable at localhost:8100
```
This is non-critical. Odysseus uses keyword search as fallback.
To enable full vector memory, run ChromaDB via Docker:
```
docker run -p 8100:8000 chromadb/chroma
```
Or use the full Docker Compose stack.

### Deep Research produces no results / search unavailable
1. Configure a search provider in Settings > Search
2. For SearXNG: start it via Docker Compose or set SEARXNG_INSTANCE in .env
3. For DuckDuckGo: no API key needed, works out of the box
4. For Brave Search: get a free API key at https://brave.com/search/api/

### Research reports are too short
See the "Output Quality Recommendations" section below or in your notes.

### Slow responses from local models
- Use a smaller model for utility tasks, larger for research/chat
- Increase the stream timeout in Settings > Agent if responses are cut off
- Make sure your Ollama context window is set correctly (see quality notes)

### Login screen won't accept credentials
- Username is case-sensitive
- Password was printed to the terminal during first-time setup
- To reset: delete `data/auth.json` and re-run `python setup.py`

### Error: "chromadb-client conflicts with embedded ChromaDB"
```powershell
venv\Scripts\pip uninstall chromadb-client -y
venv\Scripts\pip install --force-reinstall chromadb
```

---

*Generated by Claude Code for Vincent S. Pereira*
*Odysseus project: https://github.com/pewdiepie-archdaemon/odysseus*
