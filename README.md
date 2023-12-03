# Combiner
Mod for Norns to turn 2x128 or 2x64 Grids into 1 virtual Grid

>"Over the course of their endless wars, the Cybertronian race has developed a frightful array of weapons, but the most powerful and versatile invention of all might be the power to physically merge multiple Cybertronians into a single form—this power might be unlocked through conventional Cybertronian science, or through the energies of a mystical artifact like the Enigma of Combination. The term combiner (sometimes capitalized, sometimes not) can be used to refer to both those rare Transformers who possess this ability and the composite machine they create"

[Transformers Wiki](https://tfwiki.net/wiki/Combiner)

### What it is
A Norns mod that takes 2 Grids and combines them to form 1 larger virtual Grid available to scripts.

### Requirements
2x64 Grids or 2x128 Grids. Probably works with clones but I haven't tested.

### How to use it
1. Install from the Maiden project manager (or `;install https://github.com/dstroud/combiner`)
2. Add your Grids as ports *3 and 4* in SYSTEM>>DEVICES>>GRID.
3. Enable the mod in SYSTEM>>MODS>>E3 (+ symbol) and restart.
4. Edit mod settings via SYSTEM>>MODS>>COMBINER>>K3. *(WIP- just works with 2x128 right now)*
5. *"Virtual grid 128/256"* will appear in appear to scripts as port 1 (default for `grid.connect()`).

### Notes
- If this doesn't work with your a script, it's probably because that script is using `grid.devices` rather than `grid.vports`. Changing this should be a quick fix for script authors but if there's a reason that's not possible, let me know.
