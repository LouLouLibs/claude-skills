# claude-skills

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for CLI tools by [LouLouLibs](https://github.com/LouLouLibs).

## Skills

### Data

| Skill | Tool | Purpose |
|-------|------|---------|
| `dtcat` | [dt-cli-tools](https://github.com/LouLouLibs/dt-cli-tools) | View and analyze tabular data files (CSV, Parquet, Arrow, JSON, Excel, ...) |
| `dtdiff` | [dt-cli-tools](https://github.com/LouLouLibs/dt-cli-tools) | Diff two tabular data files |
| `dtfilter` | [dt-cli-tools](https://github.com/LouLouLibs/dt-cli-tools) | Filter and query tabular data files |
| `nclq` | [nclq](https://github.com/LouLouLibs/nclq) | Query Nickel (.ncl) files |
| `wrds-download` | [wrds-download](https://github.com/LouLouLibs/wrds-download) | Download WRDS data (Go) |
| `wrds-download-py` | [wrds-download](https://github.com/LouLouLibs/wrds-download) | Download WRDS data (Python/uv) |

### Excel (legacy)

These skills use [xl-cli-tools](https://github.com/LouLouLibs/xl-cli-tools), which is deprecated in favor of [dt-cli-tools](https://github.com/LouLouLibs/dt-cli-tools).

| Skill | Tool | Purpose |
|-------|------|---------|
| `xlcat` | [xl-cli-tools](https://github.com/LouLouLibs/xl-cli-tools) | View and analyze Excel files |
| `xlset` | [xl-cli-tools](https://github.com/LouLouLibs/xl-cli-tools) | Edit cells in Excel files |
| `xlfilter` | [xl-cli-tools](https://github.com/LouLouLibs/xl-cli-tools) | Filter and query Excel data |
| `xldiff` | [go-xldiff](https://github.com/LouLouLibs/go-xldiff) | Diff two Excel sheets |

### Workflow

| Skill | Purpose |
|-------|---------|
| `esync-setup` | Set up [esync](https://github.com/LouLouLibs/esync) file synchronization |
| `julia-release` | Tag Julia package versions and update registry |
| `debug-remote-pipeline` | Debug remote Snakemake pipelines via SSH |

## Installation

```bash
git clone https://github.com/LouLouLibs/claude-skills.git
cd claude-skills
bash install.sh
```

Or install individual skills:

```bash
ln -s "$(pwd)/skills/dtcat" ~/.claude/skills/dtcat
```

Skills are available immediately in new Claude Code sessions.

## License

MIT
