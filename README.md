# claude-skills

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for CLI tools by [LouLouLibs](https://github.com/LouLouLibs).

## Skills

| Skill        | Tool                                                                  | Purpose                              |
|--------------|-----------------------------------------------------------------------|--------------------------------------|
| `xlcat`      | [xl-cli-tools](https://github.com/LouLouLibs/xl-cli-tools)           | View and analyze Excel files         |
| `xlset`      | [xl-cli-tools](https://github.com/LouLouLibs/xl-cli-tools)           | Edit cells in Excel files            |
| `xldiff`     | [go-xldiff](https://github.com/LouLouLibs/go-xldiff)                 | Diff two Excel sheets                |
| `esync-setup`| [esync](https://github.com/LouLouLibs/esync)                         | Set up file synchronization          |

## Installation

Clone the repo and symlink the skills you want into `~/.claude/skills/`:

```bash
git clone https://github.com/LouLouLibs/claude-skills.git
cd claude-skills

# Install all skills
for skill in skills/*/; do
  ln -s "$(pwd)/$skill" ~/.claude/skills/"$(basename "$skill")"
done

# Or install one at a time
ln -s "$(pwd)/skills/xlcat" ~/.claude/skills/xlcat
```

Skills are available immediately in new Claude Code sessions.

## License

MIT
