# MacroForge

**MacroForge** is a macro-first action bar addon for **Ascension: Conquest of Azeroth (CoA)** and **WotLK 3.3.5**-class clients.

It focuses on what matters for deep, custom gameplay:

- **Create, move, and configure custom bars**
- **State-reactive layouts** — stealth, possession, vehicles, stances/forms, talent specs, and more
- **Editable per-button macros**
- **Drag a power or item onto a bar** to auto-create a macro
- **Lean runtime** — Cast/Mirror/XP/Rep bars, flyouts, and heavy editor libraries are not loaded until you open the config UI

Companion package (LoadOnDemand):

| Folder | Role |
|--------|------|
| `MacroForge` | Core bars, states, macros, combat path |
| `MacroForge_GUI` | Editor + AceGUI options (loads on first open) |

Slash commands: **`/macroforge`** or **`/mf`**.

---

## Install

1. Copy **both** folders into `Interface/AddOns/`:
   - `MacroForge`
   - `MacroForge_GUI`
2. Enable both in the addon list (GUI is LoadOnDemand; it still must be present and enabled).
3. `/reload`.

If you are upgrading from the **Neuron** CoA package:

- Profiles migrate automatically from `NeuronProfilesDB` → `MacroForgeProfilesDB`
- Disable or remove the old `Neuron` / `Neuron_GUI` folders after the first successful login to avoid double bars

---

## Credits & lineage

MacroForge stands on the shoulders of two major open-source projects:

### Ion Action Bars
**Connor H. Chenoweth** created the original *Ion Action Bars* architecture (secure state bars, multi-state buttons, and the overall design that still powers this code). Work prior to 2017 is his.

### Neuron
**Britt W. Yazel** continued and modernized Ion as **[Neuron](https://github.com/brittyazel/Neuron)** for retail World of Warcraft — Ace3 integration, UI polish, ongoing maintenance, and the community packaging/localization pipeline. MacroForge is **inspired by and derived from** that codebase.

### This fork (MacroForge)
**Fyrhtu** maintains this **Ascension CoA / WotLK 3.3.5** oriented fork: CoA multi-spec and form support, memory-focused trimming, LoadOnDemand editor, and a rebrand that reflects the macro-centric design.

License: **MIT** (see `LICENSE`). Please keep attribution for Britt W. Yazel and Connor H. Chenoweth when redistributing.

Upstream Neuron (retail, still under active development):  
https://github.com/brittyazel/Neuron

This repository:  
https://github.com/Fyrhtu/ion-neuron-coa

---

## Development

The git root is the `MacroForge` package itself. The LoadOnDemand GUI lives in `MacroForge_GUI/` and is installed as a **sibling** AddOn (not nested under `MacroForge/` at runtime).

```bash
# Example install target (adjust path)
export NEURON_INSTALL_DIR="/path/to/Interface/AddOns/MacroForge"
make install   # installs MacroForge + MacroForge_GUI
```

Helpful in-game tools: **BugGrabber**, **BugSack**, `/eventtrace`, `/framestack`.

---

## Disclaimer

MacroForge is **not** official Neuron and is **not** a drop-in replacement for the retail CurseForge Neuron package. It targets Ascension CoA and similar 3.3.5-based clients, with a deliberately smaller feature surface focused on custom macro bars and state paging.
