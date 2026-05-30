# Hermes bundled skills (share/hermes-agent/skills). Keys match skill directory names.
{
  claude-code = {
    description = "Delegate coding to Claude Code CLI (features, PRs).";
    category = "autonomous-ai-agents";
  };
  codex = {
    description = "Delegate coding to OpenAI Codex CLI (features, PRs).";
    category = "autonomous-ai-agents";
  };
  hermes-agent = {
    description = "Configure, extend, or contribute to Hermes Agent.";
    category = "autonomous-ai-agents";
  };
  kanban-codex-lane = {
    description = "Codex CLI as an isolated Kanban implementation lane.";
    category = "autonomous-ai-agents";
  };
  opencode = {
    description = "Delegate coding to OpenCode CLI (features, PR review).";
    category = "autonomous-ai-agents";
  };
  architecture-diagram = {
    description = "Dark-themed SVG architecture/cloud/infra diagrams as HTML.";
    category = "creative";
  };
  ascii-art = {
    description = "ASCII art: pyfiglet, cowsay, boxes, image-to-ascii.";
    category = "creative";
  };
  ascii-video = {
    description = "ASCII video: convert video/audio to colored ASCII MP4/GIF.";
    category = "creative";
  };
  baoyu-article-illustrator = {
    description = "Article illustrations: type × style × palette consistency.";
    category = "creative";
  };
  baoyu-comic = {
    description = "Knowledge comics (知识漫画): educational, biography, tutorial.";
    category = "creative";
  };
  baoyu-infographic = {
    description = "Infographics: 21 layouts x 21 styles (信息图, 可视化).";
    category = "creative";
  };
  claude-design = {
    description = "Design one-off HTML artifacts (landing, deck, prototype).";
    category = "creative";
  };
  comfyui = {
    description = "Generate images, video, and audio with ComfyUI.";
    category = "creative";
  };
  ideation = {
    description = "Generate project ideas via creative constraints.";
    category = "creative";
  };
  design-md = {
    description = "Author/validate/export Google's DESIGN.md token spec files.";
    category = "creative";
  };
  excalidraw = {
    description = "Hand-drawn Excalidraw JSON diagrams (arch, flow, seq).";
    category = "creative";
  };
  humanizer = {
    description = "Humanize text: strip AI-isms and add real voice.";
    category = "creative";
  };
  manim-video = {
    description = "Manim CE animations: 3Blue1Brown math/algo videos.";
    category = "creative";
  };
  p5js = {
    description = "p5.js sketches: gen art, shaders, interactive, 3D.";
    category = "creative";
  };
  pixel-art = {
    description = "Pixel art w/ era palettes (NES, Game Boy, PICO-8).";
    category = "creative";
  };
  popular-web-designs = {
    description = "54 real design systems (Stripe, Linear, Vercel) as HTML/CSS.";
    category = "creative";
  };
  pretext = {
    description = "Creative browser demos with @chenglou/pretext text layout.";
    category = "creative";
  };
  sketch = {
    description = "Throwaway HTML mockups: 2-3 design variants to compare.";
    category = "creative";
  };
  songwriting-and-ai-music = {
    description = "Songwriting craft and Suno AI music prompts.";
    category = "creative";
  };
  touchdesigner-mcp = {
    description = "Control a running TouchDesigner instance via twozero MCP.";
    category = "creative";
  };
  jupyter-live-kernel = {
    description = "Iterative Python via live Jupyter kernel (hamelnb).";
    category = "data-science";
  };
  kanban-orchestrator = {
    description = "Decomposition playbook for Kanban orchestrator profiles.";
    category = "devops";
  };
  kanban-worker = {
    description = "Pitfalls and edge cases for Hermes Kanban workers.";
    category = "devops";
  };
  webhook-subscriptions = {
    description = "Webhook subscriptions: event-driven agent runs.";
    category = "devops";
  };
  dogfood = {
    description = "Exploratory QA of web apps: find bugs, evidence, reports.";
    category = null;
  };
  himalaya = {
    description = "Himalaya CLI: IMAP/SMTP email from terminal.";
    category = "email";
  };
  minecraft-modpack-server = {
    description = "Host modded Minecraft servers (CurseForge, Modrinth).";
    category = "gaming";
  };
  pokemon-player = {
    description = "Play Pokemon via headless emulator + RAM reads.";
    category = "gaming";
  };
  codebase-inspection = {
    description = "Inspect codebases w/ pygount: LOC, languages, ratios.";
    category = "github";
  };
  github-auth = {
    description = "GitHub auth setup: HTTPS tokens, SSH keys, gh CLI login.";
    category = "github";
  };
  github-code-review = {
    description = "Review PRs: diffs, inline comments via gh or REST.";
    category = "github";
  };
  github-issues = {
    description = "Create, triage, label, assign GitHub issues via gh or REST.";
    category = "github";
  };
  github-pr-workflow = {
    description = "GitHub PR lifecycle: branch, commit, open, CI, merge.";
    category = "github";
  };
  github-repo-management = {
    description = "Clone/create/fork repos; manage remotes, releases.";
    category = "github";
  };
  native-mcp = {
    description = "MCP client: connect servers, register tools (stdio/HTTP).";
    category = "mcp";
  };
  gif-search = {
    description = "Search/download GIFs from Tenor via curl + jq.";
    category = "media";
  };
  heartmula = {
    description = "HeartMuLa: Suno-like song generation from lyrics + tags.";
    category = "media";
  };
  songsee = {
    description = "Audio spectrograms/features (mel, chroma, MFCC) via CLI.";
    category = "media";
  };
  spotify = {
    description = "Spotify: play, search, queue, manage playlists and devices.";
    category = "media";
  };
  youtube-content = {
    description = "YouTube transcripts to summaries, threads, blogs.";
    category = "media";
  };
  evaluating-llms-harness = {
    description = "lm-eval-harness: benchmark LLMs (MMLU, GSM8K, etc.).";
    category = "mlops";
  };
  weights-and-biases = {
    description = "W&B: log ML experiments, sweeps, model registry, dashboards.";
    category = "mlops";
  };
  huggingface-hub = {
    description = "HuggingFace hf CLI: search/download/upload models, datasets.";
    category = "mlops";
  };
  llama-cpp = {
    description = "llama.cpp local GGUF inference + HF Hub model discovery.";
    category = "mlops";
  };
  obliteratus = {
    description = "OBLITERATUS: abliterate LLM refusals (diff-in-means).";
    category = "mlops";
  };
  serving-llms-vllm = {
    description = "vLLM: high-throughput LLM serving, OpenAI API, quantization.";
    category = "mlops";
  };
  audiocraft-audio-generation = {
    description = "AudioCraft: MusicGen text-to-music, AudioGen text-to-sound.";
    category = "mlops";
  };
  segment-anything-model = {
    description = "SAM: zero-shot image segmentation via points, boxes, masks.";
    category = "mlops";
  };
  dspy = {
    description = "DSPy: declarative LM programs, auto-optimize prompts, RAG.";
    category = "mlops";
  };
  obsidian = {
    description = "Read, search, create, and edit notes in the Obsidian vault.";
    category = "note-taking";
  };
  airtable = {
    description = "Airtable REST API via curl. Records CRUD, filters, upserts.";
    category = "productivity";
  };
  google-workspace = {
    description = "Gmail, Calendar, Drive, Docs, Sheets via gws CLI or Python.";
    category = "productivity";
  };
  linear = {
    description = "Linear: manage issues, projects, teams via GraphQL + curl.";
    category = "productivity";
  };
  maps = {
    description = "Geocode, POIs, routes, timezones via OpenStreetMap/OSRM.";
    category = "productivity";
  };
  nano-pdf = {
    description = "Edit PDF text/typos/titles via nano-pdf CLI (NL prompts).";
    category = "productivity";
  };
  notion = {
    description = "Notion API + ntn CLI: pages, databases, markdown, Workers.";
    category = "productivity";
  };
  ocr-and-documents = {
    description = "Extract text from PDFs/scans (pymupdf, marker-pdf).";
    category = "productivity";
  };
  powerpoint = {
    description = "Create, read, edit .pptx decks, slides, notes, templates.";
    category = "productivity";
  };
  teams-meeting-pipeline = {
    description = "Operate the Teams meeting summary pipeline via Hermes CLI.";
    category = "productivity";
  };
  godmode = {
    description = "Jailbreak LLMs: Parseltongue, GODMODE, ULTRAPLINIAN.";
    category = "red-teaming";
  };
  arxiv = {
    description = "Search arXiv papers by keyword, author, category, or ID.";
    category = "research";
  };
  blogwatcher = {
    description = "Monitor blogs and RSS/Atom feeds via blogwatcher-cli tool.";
    category = "research";
  };
  llm-wiki = {
    description = "Karpathy's LLM Wiki: build/query interlinked markdown KB.";
    category = "research";
  };
  polymarket = {
    description = "Query Polymarket: markets, prices, orderbooks, history.";
    category = "research";
  };
  research-paper-writing = {
    description = "Write ML papers for NeurIPS/ICML/ICLR: design→submit.";
    category = "research";
  };
  openhue = {
    description = "Control Philips Hue lights, scenes, rooms via OpenHue CLI.";
    category = "smart-home";
  };
  xurl = {
    description = "X/Twitter via xurl CLI: post, search, DM, media, v2 API.";
    category = "social-media";
  };
  debugging-hermes-tui-commands = {
    description = "Debug Hermes TUI slash commands: Python, gateway, Ink UI.";
    category = "software-development";
  };
  hermes-agent-skill-authoring = {
    description = "Author in-repo SKILL.md: frontmatter, validator, structure.";
    category = "software-development";
  };
  hermes-s6-container-supervision = {
    description = "Modify or debug the s6-overlay supervision tree in the Docker image.";
    category = "software-development";
  };
  node-inspect-debugger = {
    description = "Debug Node.js via --inspect + Chrome DevTools Protocol CLI.";
    category = "software-development";
  };
  plan = {
    description = "Plan mode: write markdown plan to .hermes/plans/, no exec.";
    category = "software-development";
  };
  python-debugpy = {
    description = "Debug Python: pdb REPL + debugpy remote (DAP).";
    category = "software-development";
  };
  requesting-code-review = {
    description = "Pre-commit review: security scan, quality gates, auto-fix.";
    category = "software-development";
  };
  spike = {
    description = "Throwaway experiments to validate an idea before build.";
    category = "software-development";
  };
  subagent-driven-development = {
    description = "Execute plans via delegate_task subagents (2-stage review).";
    category = "software-development";
  };
  systematic-debugging = {
    description = "4-phase root cause debugging: understand bugs before fixing.";
    category = "software-development";
  };
  test-driven-development = {
    description = "TDD: enforce RED-GREEN-REFACTOR, tests before code.";
    category = "software-development";
  };
  writing-plans = {
    description = "Write implementation plans: bite-sized tasks, paths, code.";
    category = "software-development";
  };
  yuanbao = {
    description = "Yuanbao (元宝) groups: @mention users, query info/members.";
    category = null;
  };
  icloud-calendar = {
    description = "Read and write iCloud Calendar via CalDAV (vdirsyncer + khal).";
    category = null;
  };
}
