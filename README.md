# My AI Skills

Personal AI agent skill library for Cursor IDE. Contains 105 expert-level skills and working rules that sync across any machine.

## Quick Setup (New Machine)

### Windows (PowerShell)

```powershell
git clone https://github.com/KieuTuanKien/my-ai-skills.git
cd my-ai-skills
.\scripts\setup.ps1
```

### Linux / macOS

```bash
git clone https://github.com/KieuTuanKien/my-ai-skills.git
cd my-ai-skills
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### Install rules to a specific project

```powershell
# Windows
.\scripts\setup.ps1 -ProjectPath "D:\MyProject"

# Linux/macOS
./scripts/setup.sh /path/to/my-project
```

## What's Included

### Skills (105 total)

| Group | Count | Categories |
|-------|-------|-----------|
| AI Research (Orchestra) | 85 | Model Architecture, Tokenization, Fine-Tuning, Interpretability, Data Processing, Post-Training, Safety, Distributed Training, Infrastructure, Optimization, Evaluation, Inference, MLOps, Agents, RAG, Prompt Engineering, Observability, Multimodal, Emerging, Paper Writing, Ideation |
| Trading & Finance | 10 | Trading Bot, Market Data, Technical Analysis, Backtesting, Risk Management, ML Trading, DL Trading, Elliott Wave, Wyckoff, Advanced Algorithms |
| Engineering | 5 | Industrial Automation, Electrical, Mechanical, Construction, PLC/SCADA |
| Energy & Solar | 5 | PV Solar, BESS/BMS, EMS, Microgrid, Solar Project Management |

### Rules

| Rule | Purpose |
|------|---------|
| `ai-research-skills.mdc` | Skill registry - tells AI which skill to read for each task |
| `working-principles.mdc` | Working principles - planning, evidence-based, multi-option, challenge |

## Adding New Skills

1. Create a folder in `skills/your-skill-name/`
2. Add `SKILL.md` with the standard format
3. Update `rules/ai-research-skills.mdc` to register the new skill
4. Commit and push
5. Run `setup.ps1` on other machines to sync

## Updating Skills

```powershell
# After editing skills locally, sync back to repo
.\scripts\sync-to-repo.ps1

# On other machines, pull and re-setup
git pull
.\scripts\setup.ps1
```

## File Structure

```
my-ai-skills/
├── README.md
├── skills/
│   ├── axolotl/SKILL.md
│   ├── trading-bot-python/SKILL.md
│   ├── pv-solar-system/SKILL.md
│   ├── ems-energy-management/SKILL.md
│   └── ... (105 skills)
├── rules/
│   ├── ai-research-skills.mdc
│   └── working-principles.mdc
└── scripts/
    ├── setup.ps1       # Windows installer
    └── setup.sh        # Linux/macOS installer
```
