# pidgin skills

Cross-agent skills for [pidgin](https://pidgin.sh) — the service for sharing static artifacts (HTML, images, PDFs, plots, reports) by URL.

These skills follow the [Agent Skills specification](https://agentskills.io) and work with Claude Code, Cursor, Codex, Gemini CLI, OpenCode, Windsurf, and [50+ other coding agents](https://github.com/vercel-labs/skills#supported-agents).

## Available skills

| Skill | Description |
|--|--|
| [`pidgin-share`](./skills/pidgin-share) | Upload a local file to pidgin and get back a public unlisted URL on `<subdomain>.pidgin.sh`. |

## Install

Use the [`skills`](https://github.com/vercel-labs/skills) CLI — it auto-detects which agents you have installed and writes to the right paths:

```bash
npx skills add pidgin-sh/skills
```

To install globally (available to all projects) instead of per-project:

```bash
npx skills add pidgin-sh/skills -g
```

To target a specific agent:

```bash
npx skills add pidgin-sh/skills -a claude-code -g
```

Run `npx skills add pidgin-sh/skills --list` to preview without installing.

## Prerequisites

You need a pidgin API key. Sign in at <https://pidgin.sh> with GitHub, create a key at <https://pidgin.sh/dashboard/keys>, and export it:

```bash
export PIDGIN_API_KEY=pdg_…
```

## License

MIT — see [LICENSE](./LICENSE).
