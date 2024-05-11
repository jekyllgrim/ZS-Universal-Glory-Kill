# Simple universal glory kill for GZDoom

This minimod/library adds a universal "glory kill" mechanic to GZDoom.

### Features:

* Any monster, when killed, goes into a "glory kill state" where it flashes blue and red. This affects all monsters, so this is compatible with mods, but it can lead to weird issues if actors that aren't monsters have the `bIsMonster` flag in their definitions (may happen in some mods).

* Approach the monster and press the Use key to perform glory kill.

* Monsters killed this way will drop ammo for any weapons currently loaded in the game.
  
  * Ammo drops are selected based on whatever weapons are assigned to player's slots, so they are compatible with weapon mods.
  
  * The *number* of ammo drops is calculated based on the killed monster's original health, clamped between 4 and 20.
  
  * The *types* of ammo dropped are weighted based on the weapon's slot. The weights are listed in the static `ammoDropWeights` array in the  `GloryKillController` class.

### Contents:

* `GloryKillFist` — a  weapon that utilizes sprites of the Fist weapon from Doom (sprites not included) that performs the glory kill animation. Can be modified however you like to change the visuals, however, the weapon that performs the kill MUST obtain a pointer to an instance of `GloryKillController` in the killed monster's inventory and call `DoGloryKill(<pointer to player pawn>)` on it. In `GloryKillFist` this is done with `StartGloryKillAnimation()` and `A_KillVictim()` functions.

* `GloryKillHandler` — an event handler that adds `GloryKillController` into the inventory of any killed actor if the actor has the `bIsMonster` flag (assumed to be a monster).

* `GloryKillController` — this is a Powerup-based class that handles the glory kill behavior. It spawns a visual flash (see `GloryKillFlash`), and when the owner of the powerup (the monster) is killed via `DoGloryKill()`, it'll build an array of valid ammo drops and spawn them. It also spawns some blood actors (see `GloryKillBlood`).

* `GloryKillFlash` — spawned on top of a monster when they're in the glory kill state. Copies the monster's sprites and flashes in red/blue. Its `Used()` virtual is used to detect when the player presses Use next to the monster, so this is the only mechanically relevant component.

* `GloryKillBlood` — an actor that looks like regular Blood but also spawns some trails behind itself. Spawned only by glory kills. Will respect the monster's `BloodColor` property and should work in any GZDoom-based game that uses the Blood actor. Can be modified however you like.

### License

MIT License. Do whatever you want with it, just copy my LICENSE.txt file into your project.
