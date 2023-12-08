# Combiner

>*"Over the course of their endless wars, the Cybertronian race has developed a frightful array of weapons, but the most powerful and versatile invention of all might be the power to physically merge multiple Cybertronians into a single form—this power might be unlocked through conventional Cybertronian science, or through the energies of a mystical artifact like the Enigma of Combination.*"
[Transformers Wiki](https://tfwiki.net/wiki/Combiner)

### What it is
A Norns mod to combine two Grids into a single virtual Grid

### Requirements
- 2x64 Grids or 2x128 Grids (or clone such as NeoTrellis)
- Norns 231114

### How to use it
1. Install from the Maiden project manager (or `;install https://github.com/dstroud/combiner`)
2. Add like-sized Grids to **ports 3 and 4** in SYSTEM>>DEVICES>>GRID.
3. Enable the mod in SYSTEM>>MODS>>E3 (+ symbol) and restart.
4. The virtual Grid will appear to scripts on port 1 (default for most scripts).
5. Grid rotation and LED intensity can be changed via SYSTEM>>MODS>>COMBINER>>K3. Grid 'a' is port 3 and 'b' is port 4. 

### Notes
- LED intensity does not seem to be supported on all Grids.
- If using a NeoTrellis, each device must have a unique name+serial in SYSTEM>>DEVICES>>GRID. This may require editing your .ino file and re-uploading the firmware.
- If this doesn't work with your a particular script, it's probably because that script is using `grid.devices` rather than `grid.vports`. Changing this should be a quick fix for script authors but if that's not possible for some reason, just let me know and I can probably find a workaround.
- If your settings don't seem to be saved after a rebood, it's probably because you have some other mod installed (such as `grid-settings`) that is setting Grid rotation/intensity. Disable.
