# pidgin skills

Claude Code skills for [pidgin](https://pidgin.sh) — the service for sharing static artifacts (HTML, images, PDFs, plots, reports) by URL.

## Available skills

| Skill | Description |
|--|--|
| [`pidgin-share`](./pidgin-share) | Upload a local file to pidgin and get back a public unlisted URL on `<subdomain>.pidgin.sh`. |

## Install

Each skill lives in its own subdirectory. To install a skill into Claude Code, symlink (or copy) its directory under `~/.claude/skills/`.

For `pidgin-share`:

```bash
git clone https://github.com/pidgin-sh/skills.git ~/code/pidgin-skills
ln -s ~/code/pidgin-skills/pidgin-share ~/.claude/skills/pidgin-share
```

Use `cp -R` instead of `ln -s` if you prefer a copy. Restart Claude Code after installing.

## Prerequisites

You need a pidgin API key. Sign in at <https://pidgin.sh> with GitHub, create a key at <https://pidgin.sh/dashboard/keys>, and export it:

```bash
export PIDGIN_API_KEY=pdg_…
```

## License

MIT — see [LICENSE](./LICENSE).
