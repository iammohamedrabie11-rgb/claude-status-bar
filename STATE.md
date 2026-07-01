# Per-session state contract

Claude Sessions is stateless in process; all cross-session state lives on disk as **one JSON file per
Claude Code session**, written by the hooks and read by the app. This file documents that shape — it is
the **contract** the menu-bar reader and the upcoming features (N status items, color allocator, iTerm2
tab tint) depend on, so the field names below are stable.

## Location & keying

```
~/.claude/sessions-bar/state.d/<session_id>.json
```

- **One file per session,** keyed by the Claude Code `session_id` (e.g. `7b339349-…`). The filename
  (minus `.json`) is the canonical id; the reader keys off the filename.
- Written **atomically** (`<file>.<pid>.tmp` then `rename`) so the reader never sees a torn file.
- **Writers:** `hooks/lifecycle.js` (SessionStart seeds the file, SessionEnd removes it) and
  `hooks/update.js` (rewrites the file on every status event). **Reader:** `Sources/main.swift`
  (`Session.init(json:)`), which re-parses a file only when its mtime changes.

## Fields

| Field | Type | Meaning |
|---|---|---|
| `state` | string | `idle` \| `thinking` \| `tool` \| `permission` \| `done` |
| `label` | string | Human-readable status (e.g. `Thinking…`, `Editing`, `Awaiting permission`) |
| `tool` | string | Tool name on tool events (write-only; reader uses `label`) |
| `project` | string | `basename(cwd)` — the repo/dir name |
| `git_branch` | string | Current git branch of `cwd`; `""` when not a git repo (detached HEAD → short SHA) |
| `entrypoint` | string | `CLAUDE_CODE_ENTRYPOINT`: `cli`, `claude-desktop`, … |
| `term_program` | string | `TERM_PROGRAM` for CLI sessions (`Apple_Terminal`, `iTerm.app`, …) |
| `tty` | string | iTerm2 session's controlling tty (`/dev/ttysNNN`), for the tab-tint escape; `""` when not iTerm2/unknown |
| `iterm_session_id` | string | `ITERM_SESSION_ID` (stable per-tab id) for iTerm2 sessions; `""` otherwise |
| `transcript` | string | Path to the session transcript `.jsonl` |
| `pid` | number | The session's `claude` process (`process.ppid`); drives liveness via `kill(pid,0)`. `0` = legacy file |
| `started` | bool | `true` once the session had real activity (a prompt/tool); seeded `false` on a merely-opened session |
| `startedAt` | number | Unix seconds the current turn began (`0` = no active turn) |
| `ts` | number | Unix seconds of the last write |
| `sessionId` | string | Echo of `session_id` (write-only; the reader uses the filename) |

## Lifecycle & liveness

- **SessionStart** seeds an idle file (`started:false`) and launches the app.
- **update.js** rewrites the file on each event (`prompt`/`pre`/`post`/`notify`/`permreq`/`stop`),
  setting `started:true`. `git_branch` is recomputed once per turn (on `prompt`) and carried over on
  other events so per-tool-call events never shell out (keeps hooks lightweight).
- **SessionEnd** removes the file (and, for an iTerm2 session, resets that tab's color first).
- **iTerm2 tab tint:** `tty` + `iterm_session_id` are captured once at SessionStart (only when
  `TERM_PROGRAM === "iTerm.app"`) and carried forward on later events (sticky, like `git_branch`). The app
  reads `tty` and writes the tab-color escape to it, tinting the tab to the session's accent — **Orange mode
  only** (skipped in System/monochrome theme). Both fields are optional and default `""`; absent/empty ⇒ no
  tint, and nothing else in the contract changes.
- The app reaps files **per-file**: a session whose `pid` is dead (`kill(pid,0)` fails) has its file
  deleted; legacy `pid:0` files fall back to an idle+age prune. Multiple concurrent files are supported —
  the app aggregates them and (today) renders the single highest-priority "frontmost" session.
