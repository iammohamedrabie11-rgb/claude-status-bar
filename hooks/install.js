#!/usr/bin/env node
// Installs the Claude Sessions hooks into ~/.claude/settings.json (merging, never
// clobbering existing hooks) and copies update.js to ~/.claude/sessions-bar/.
// Re-runnable: existing Claude Sessions hooks are stripped before re-adding.
//
// Preview/dry-run: set CLAUDE_SESSIONS_PREVIEW_OUT=<path> to compute the merged settings and
// write them to <path> ONLY — no script copies, no legacy cleanup, no backup, and the real
// ~/.claude/settings.json is left untouched. Used to preview the exact hook diff before writing.

const fs = require("fs");
const os = require("os");
const path = require("path");
const cp = require("child_process");

const home = os.homedir();
const sbDir = path.join(home, ".claude", "sessions-bar");
const MARKER = sbDir; // every hook command we add points inside this dir
const updateDest = path.join(sbDir, "update.js");
const lifecycleDest = path.join(sbDir, "lifecycle.js");
const settingsPath = path.join(home, ".claude", "settings.json");
// Pin the stable Homebrew node symlink, never the versioned Cellar path (process.execPath
// resolves the symlink, so a `brew upgrade node` would move that path and break every hook).
const STABLE_NODE = ["/opt/homebrew/bin/node", "/usr/local/bin/node"].find((p) => fs.existsSync(p));
const node = STABLE_NODE || process.execPath;

// Preview mode: compute-and-write-elsewhere, skipping all filesystem side effects below.
const PREVIEW_OUT = process.env.CLAUDE_SESSIONS_PREVIEW_OUT || "";

if (!PREVIEW_OUT) {
  // Retire the old 0.0.2 background watcher LaunchAgent on upgrade (0.0.3+ self-quits).
  const OLD_AGENT_LABEL = "com.muhammed.claude-sessions.watcher";
  const oldAgentPlist = path.join(home, "Library", "LaunchAgents", OLD_AGENT_LABEL + ".plist");
  try { cp.execSync(`launchctl bootout gui/${process.getuid()}/${OLD_AGENT_LABEL}`, { stdio: "ignore" }); } catch {}
  if (fs.existsSync(oldAgentPlist)) { fs.rmSync(oldAgentPlist); console.log("Removed old desktop watcher LaunchAgent."); }

  fs.mkdirSync(sbDir, { recursive: true });
  fs.rmSync(path.join(sbDir, "watcher.sh"), { force: true });
  // Retire pre-multi-session artifacts (single global state + empty liveness markers).
  fs.rmSync(path.join(sbDir, "state.json"), { force: true });
  fs.rmSync(path.join(sbDir, "sessions.d"), { recursive: true, force: true });
  fs.copyFileSync(path.join(__dirname, "update.js"), updateDest);
  fs.copyFileSync(path.join(__dirname, "lifecycle.js"), lifecycleDest);
}

const cmd = (evt) => `${node} ${updateDest} ${evt}`;
const life = (evt) => `${node} ${lifecycleDest} ${evt}`;

let settings = {};
if (fs.existsSync(settingsPath)) {
  settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  if (!PREVIEW_OUT) {
    const bak = settingsPath + ".bak-claude-sessions";
    if (!fs.existsSync(bak)) fs.copyFileSync(settingsPath, bak);
  }
}
settings.hooks = settings.hooks || {};

const stripOurs = (arr) =>
  (arr || [])
    .map((entry) => ({
      ...entry,
      hooks: (entry.hooks || []).filter((h) => !(h.command || "").includes(MARKER)),
    }))
    .filter((entry) => (entry.hooks || []).length > 0);

const addUnmatched = (evt, command) => {
  settings.hooks[evt] = stripOurs(settings.hooks[evt]);
  settings.hooks[evt].push({ hooks: [{ type: "command", command }] });
};
const addMatched = (evt, command) => {
  settings.hooks[evt] = stripOurs(settings.hooks[evt]);
  settings.hooks[evt].push({ matcher: "*", hooks: [{ type: "command", command }] });
};

// Status hooks (drive the animation/label)
addUnmatched("UserPromptSubmit", cmd("prompt"));
addMatched("PreToolUse", cmd("pre"));
addMatched("PostToolUse", cmd("post"));
addUnmatched("Notification", cmd("notify"));
addMatched("PermissionRequest", cmd("permreq"));
addUnmatched("Stop", cmd("stop"));
// Lifecycle hooks (launch the app on open; the app quits itself when no longer needed)
addUnmatched("SessionStart", life("start"));
addUnmatched("SessionEnd", life("end"));

const outPath = PREVIEW_OUT || settingsPath;
fs.writeFileSync(outPath, JSON.stringify(settings, null, 2) + "\n");
if (PREVIEW_OUT) {
  console.log("Preview written to", outPath, "— real settings.json left untouched.");
} else {
  console.log("Installed Claude Sessions hooks into", settingsPath);
  console.log("Scripts:", updateDest, "and", lifecycleDest);
  console.log("Backup (first run only):", settingsPath + ".bak-claude-sessions");
}
