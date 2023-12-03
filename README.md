# Combiner
Mod for Norns to turn 2x128 or 2x64 Grids into one virtual Grid

>"Over the course of their endless wars, the Cybertronian race has developed a frightful array of weapons, but the most powerful and versatile invention of all might be the power to physically merge multiple Cybertronians into a single form—this power might be unlocked through conventional Cybertronian science, or through the energies of a mystical artifact like the Enigma of Combination. The term combiner (sometimes capitalized, sometimes not) can be used to refer to both those rare Transformers who possess this ability and the composite machine they create"

[Transformers Wiki](https://tfwiki.net/wiki/Combiner)

### What it is
A Norns mod that takes two Grids and combines them to form one larger virtual Grid available to any script that supports that size.

### Requirements
- 2x64 Grids or 2x128 Grids. Let me know if it works with clones?
- Norns 231114

### How to use it
1. Install from the Maiden project manager (or `;install https://github.com/dstroud/combiner`)
2. Add like-sized Grids to **ports 3 and 4** in SYSTEM>>DEVICES>>GRID.
3. Enable the mod in SYSTEM>>MODS>>E3 (+ symbol) and restart.
4. Edit mod settings via SYSTEM>>MODS>>COMBINER>>K3. Grid 'a' is port 3 and 'b' is port 4. LED intensity may not be supported on all devices.
5. The virtual Grid will appear in appear to scripts on port 1 (default for most scripts).

### Notes
If this doesn't work with your a particular script, it's probably because that script is using `grid.devices` rather than `grid.vports`. Changing this should be a quick fix for script authors but if that's not possible for some reason, just let me know and I can probably find a workaround.
