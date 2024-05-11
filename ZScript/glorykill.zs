class GloryKillFist : Weapon
{
	Weapon prevWeapon;
	GloryKillController victimController;
	Actor victim;
	Vector3 victimOfs;

	Default
	{
		+Weapon.CHEATNOTWEAPON
	}

	static void StartGloryKillAnimation(PlayerPawn ppawn, GloryKillController victimController, Vector3 posOfs)
	{
		Weapon curw = ppawn.player.readyweapon;
		let gf = GloryKillFist(ppawn.GiveInventoryType('GloryKillFist'));
		if (gf)
		{
			gf.prevWeapon = curw;
			gf.victimController = victimController;
			gf.victim = victimController.owner;
			gf.victimOfs = posOfs;
			ppawn.player.readyweapon = gf;
			ppawn.player.SetPSprite(PSP_WEAPON, gf.FindState("Ready"));
			ppawn.player.cheats |= CF_TOTALLYFROZEN;
			ppawn.A_Face(victimController.owner, 0, 0, z_ofs: victimController.owner.default.height*0.5);
			ppawn.A_Stop();
			Level.SetFrozen(true);
			gf.victim.bNoTimeFreeze = true;
			gf.victimController.gloryflash.bNoTimeFreeze = true;
		}
	}

	action void A_KillVictim()
	{
		if (invoker.victimController)
		{
			invoker.victimController.DoGloryKill(self);
		}
	}

	override void DoEffect()
	{
		if (owner && victim)
		{
			owner.SetOrigin(victim.pos + victimOfs, true);
		}
	}

	// Unfreezes the player and re-selects their
	// current weapon:
	override void DetachFromOwner()
	{
		if (owner && owner.player)
		{
			owner.player.pendingweapon = prevWeapon;
			owner.player.cheats &= ~CF_INSTANTWEAPSWITCH;
			owner.player.cheats &= ~CF_TOTALLYFROZEN;
			owner.bNoTimeFreeze = owner.default.bNoTimeFreeze;
		}
		Level.SetFrozen(false);
		if (victim)
		{
			victim.bNoTimeFreeze = victim.default.bNoTimeFreeze;
		}
		Super.DetachFromOwner();
	}

	States
	{
	// Select, Deselect and Fire states are dummy,
	// they're defined simply because weapons can't
	// be defined without them:
	Select:
		TNT1 A 0 A_Raise();
		wait;
	Deselect:
		TNT1 A 0 A_Lower();
		wait;
	Fire:
	// This is the actual attack animation.
	// As an example, this uses tuned-up
	// Fist animation. The only important
	// mechanical bit is A_KillVictim; the rest
	// can be modified as you like:
	Ready:
		TNT1 A 0 A_OverlayPivot(OverlayID(), 0.2, 0.8);
		GFIS AAA 1 
		{
			A_OverlayRotate(OverlayID(), 3, WOF_ADD);
			A_OverlayOffset(OverlayID(), -5, 5, WOF_ADD);
		}
		GFIS AAAAAAA 1 
		{
			A_OverlayRotate(OverlayID(), 0.5, WOF_ADD);
			A_OverlayOffset(OverlayID(), -1, 1, WOF_ADD);
		}
		GFIS BBBBBB 1
		{
			let psp = player.FindPSprite(OverlayID());
			psp.bInterpolate = true;
			psp.rotation *= 0.3;
			psp.x += 20;
			psp.y = Clamp(psp.y - 8, WEAPONTOP, WEAPONBOTTOM);
		}
		GFIS B 0 A_KillVictim(); //<-- IMPORTANT! this is where the actual killing happens
		GFIS BBBBBBBBBB 1
		{
			A_OverlayOffset(OverlayID(), 5, 10, WOF_ADD);
			A_OverlayScale(OverlayID(), -0.015, -0.015, WOF_ADD);
		}
		TNT1 A 0 
		{ 
			// This ends the animation and removes the weapon:
			A_TakeInventory(invoker.GetClass(), invoker.amount);
		}
		stop;
	}
}

// This gives all monsters a controller upon death:
class GloryKillHandler : EventHandler
{
	override void WorldThingDied(worldEvent e)
	{
		let t = e.thing;
		if (t && t.bISMONSTER && t.bSHOOTABLE)
		{
			t.GiveInventory('GloryKillController', 1);
		}
	}
}

// Controls the actual effects:
class GloryKillController : Powerup
{
	Actor gloryflash;
	const MAXWEAPONSLOTS = 10;
	State painstate;

	// Drop weights per slot
	// adjust as necessary:
	static const int ammoDropWeights[] =
	{
		0,	//empty
		20,	//slot 1
		20,	//slot 2
		20,	//slot 3
		15,	//slot 4
		5,	//slot 5
		15,	//slot 6
		10,	//slot 7
		10,	//slot 8
		5,	//slot 9
		5	//slot 10 (actual slot 0)
	};

	Default
	{
		Powerup.Duration -4;
	}

	override void InitEffect()
	{
		Super.InitEffect();
		if (!owner) return;
		painstate = owner.FindState("Pain");
	}

	override void Tick()
	{
		Super.Tick();
		if (!owner) return;
		if (!gloryflash)
		{
			gloryflash = Spawn('GloryKillFlash', owner.pos);
			gloryflash.master = owner;
		}
		// Although the monster is stuck
		// in its death state, I want its
		// sprite to be its pain sprite:
		if (painstate)
		{
			owner.sprite = painstate.sprite;
			owner.frame = painstate.frame;
		}
		owner.A_SetTics(-1);
	}

	// The glory kill visuals. This snaps the monster
	// from being frozen in the first state of Death,
	// sends it to XDeath (if available) and spawns some
	// blood.
	void DoGloryKill(Actor killer)
	{
		if (!owner) return;
		effectTics = 1;

		// Everything below in this function is visual-only
		// and can be redone in any way you like:

		// move monster to XDeath, if present:
		let st = owner.FindState("XDeath"); 
		if (st)
		{
			owner.SetState(st);
		}

		for (int i = 10; i > 0; i--)
		{
			bool spawned; Actor b;
			[spawned, b] = owner.A_SpawnItemEx("GloryKillBlood",
				xofs: frandom[bdrop](0, owner.radius),
				zofs: owner.height * frandom[bdrop](0.25, 0.9),
				xvel: frandom[bdrop](4, 10),
				zvel: frandom[bdrop](7, 12),
				angle: frandom[bdrop](0, 360),
				flags: SXF_USEBLOODCOLOR|SXF_SETTARGET);
			if (spawned && b)
			{
				b.scale *= frandom[bdrop](0.35, 1.5);
				b.bNoTimeFreeze = true;
			}
		}

		if (!killer || !killer.player) return;
		array < class<Ammo> > ammoClasses; //ammo classes to drop
		BuildAmmoArray(killer.player.mo, ammoClasses);
		while (ammoClasses.Size() > 0)
		{
			let amcls = ammoClasses[ammoClasses.Size()-1];
			if (!amcls) continue;
			let amDrop = Spawn(amcls, owner.pos + (0,0,owner.height*0.5));
			amDrop.Vel3DFromAngle(frandom[add](5,11), frandom[add](0,360), frandom[add](-15, -75));
			ammoClasses.Pop();
		}
	}

	void BuildAmmoArray(PlayerPawn killer, out array < class<Ammo> > ammoClasses)
	{
		array < GloryAmmoDropData > ammoDropData;
		WeaponSlots wslots = killer.player.weapons;
		// Iterate over weapon slots, NOT inventory:
		for (int i = 1; i <= MAXWEAPONSLOTS; i++)
		{
			// Slot 10 is selected with number 0,
			// so remap 10 to 0 if we reached it:
			int sn = i >= MAXWEAPONSLOTS ? 0 : i;
			// Get how many weapons are in this slot:
			int size = wslots.SlotSize(sn);
			if (size <= 0) continue;

			// Iterate over all weapons in this slot:
			for (int s = 0; s < size; s++)
			{
				class<Weapon> weap = wslots.GetWeapon(sn, s);
				if (weap)
				{
					// Push ammotype1 into data:
					class<Ammo> am1 = GetDefaultByType(weap).ammotype1;
					class<Ammo> am2 = GetDefaultByType(weap).ammotype2;
					let d = GloryAmmoDropData.Create(am1, ammoDropWeights[i]);
					ammoDropData.Push(d);
					// Same for ammotype2 if it's not identical:
					if (am2 && am2 != am1)
					{
						d = GloryAmmoDropData.Create(am2, ammoDropWeights[i]);
						ammoDropData.Push(d);
					}
				}
			}
		}

		int totalWeight;
		// Delete duplicate ammo types and only push
		// unique ones into ammoClasses:
		for (int i = ammoDropData.Size()-1; i >= 0; i--)
		{
			let adata = ammoDropData[i];
			if (!adata) continue;
			let am = adata.ammotype;
			if (!am || ammoClasses.Find(am) != ammoClasses.Size())
			{
				adata.Destroy();
				ammoDropData.Delete(i);
			}
			else
			{
				ammoClasses.Push(am);
				totalWeight += adata.weight; //add its weight to total weight value:
				Console.Printf("\ckPreliminary array\c-: Pushing \cy%s\c- (weight: \cd%d\c-)", am.GetClassName(), adata.weight);
			}
		}

		// Clear ammoClasses array. We'll now refill it from ammoDropData
		// and do the actual weighing:
		ammoClasses.Clear();
		// The number of drops is NOT affected by weight but is
		// determined by monster's original health. The weight
		// only determines chances of specific ammo types to drop:
		int drops = Clamp(owner.GetMaxHealth() / 50, 4, 20);
		// Safety to make sure this doesn't freeze:
		int maxIterations = 64;
		Console.Printf("\ckDrops:\c- size \cd%d\c- (monster health: \cd%d\c-)", drops, owner.GetMaxHealth());
		while (drops && maxIterations)
		{
			foreach (adata : ammoDropData)
			{
				// Roll chance and compare it to weight:
				double chance = random[add](0, totalWeight) * frandom[add](0.0, 1.0);
				Console.Printf("\ckFinal roll:\c- Rolling for \cy%s\c- | Roll: \cd%d\c- (required: \cd%d\c-) -- %s", adata.ammotype.GetClassName(), chance, adata.weight, chance <= adata.weight? "\cdSuccess" : "\cgFail");
				// If it fit the weight, push it into the ammoClasses array:
				if (chance <= adata.weight)
				{
					ammoClasses.Push(adata.ammotype);
					drops--;
					if (drops <= 0)
					{
						break;
					}
				}
			}
			maxIterations--;
		}

		// We're done. The ammoClasses array's size is now equal to 'drops'
		// declared above, and it's filled with ammo types in accordance
		// with their weights.
	}

	override void EndEffect()
	{
		// Destroy flash and unfreeze the monster's animation:
		if (gloryflash)
		{
			gloryflash.Destroy();
		}
		if (owner)
		{
			owner.A_SetTics(1);
		}
		Super.EndEffect();
	}
}

class GloryAmmoDropData play
{
	class<Ammo> ammotype;
	int weight;

	static GloryAmmoDropData Create(class<Ammo> ammotype, int weight)
	{
		let d = new('GloryAmmoDropData');
		d.ammoType = ammotype;
		d.weight = weight;
		return d;
	}
}

class HellKnight1 : HellKnight replaces HellKnight
{
	Default
	{
		BloodColor "green";
	}
}

class GloryKillBlood : Blood
{
	color particleBloodColor;

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (!target) return;
		Color bc = target.bloodcolor;
		Color dbc = gameinfo.defaultbloodcolor;
		particleBloodColor = (bc.r != 0 || bc.g != 0 || bc.b != 0)? bc : dbc;
		//Console.Printf("Target bloodColor: \cd%d %d %d\c- | DefaultBloodColor: \cd%d %d %d\c- | Particle blood color: \cd%d %d %d\c-",
			bc.r, bc.g, bc.b,
			dbc.r, dbc.g, dbc.b,
			particleBloodColor.r, particleBloodColor.g, particleBloodColor.b);
	}

	override void Tick()
	{
		Super.Tick();
		if (isFrozen() || !self || !self.curstate) return;

		FSpawnParticleParams bp;
		TextureID tex = curstate.GetSpriteTexture(0);
		double p = 4;
		bp.pos = pos + (frandom[gkb](-p,p), frandom[gkb](-p,p), frandom[gkb](-p,p));
		bp.color1 = particleBloodColor;
		bp.texture = curstate.GetSpriteTexture(0);
		bp.size = TexMan.GetSize(tex) * scale.x * 2;
		bp.lifetime = 18;
		bp.startalpha = 1;
		bp.fadestep = -1;
		bp.vel.z = -1;
		bp.flags = SPF_REPLACE|SPF_NOTIMEFREEZE;
		bp.style = STYLE_Stencil;
		Level.SpawnParticle(bp);
	}
}

// This both handles the visuals AND functions as
// the usable object the player can activate to do
// the glory kill:
class GloryKillFlash : Actor
{
	Default
	{
		+SOLID
		+BRIGHT
		Renderstyle 'Shaded';
		alpha 0.7;
	}

	override bool Used(Actor user)
	{
		if (user.player && master)
		{
			let gc = GloryKillController(master.FindInventory('GloryKillController'));
			if (gc)
			{
				// Extend the controller's duration just to make sure it doesn't 
				// run out mid-animation (it'll be removed automatically at the
				// end anyway):
				gc.effectTics = 1000;
				GloryKillFist.StartGloryKillAnimation(user.player.mo, gc, Level.Vec3Diff(master.pos, user.pos));
			}
		}
		return false;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		if (master)
		{
			A_SetSize(master.radius, master.default.height);
		}
	}

	override void Tick()
	{
		if (!master)
		{
			Destroy();
			return;
		}

		sprite = master.sprite;
		frame = master.frame;
		scale = master.scale;
		angle = master.angle;
		roll = master.roll;
		bROLLSPRITE = master.bROLLSPRITE;
		bROLLCENTER = master.bROLLCENTER;
		spriteoffset = master.spriteoffset;
		worldOffset = master.worldOffset;
		bSPRITEFLIP = master.bSPRITEFLIP;
		bXFLIP = master.bXFLIP;
		bYFLIP = master.bYFLIP;
		bFORCEYBILLBOARD = master.bFORCEYBILLBOARD;
		bFORCEXYBILLBOARD = master.bFORCEXYBILLBOARD;
		bFLOATBOB = master.bFLOATBOB;
		FloatBobPhase = master.FloatBobPhase;
		FloatBobStrength = master.FloatBobStrength;
		// these 4 are CRITICALLY important to make sure
		// the copy also has the same sprite clipping
		// as the original actor:
		bIsMonster = master.bIsMonster;
		bCorpse = master.bCorpse;
		bFloorclip = master.bFloorclip;
		bSpecialFloorclip = master.bSpecialFloorclip;
		SetOrigin(master.pos, true);

		double fac = 0.5 + 0.5 * sin(360.0 * Level.mapTime / TICRATE);
		int R = round(255 * fac);
		int B = round(-255 * fac + 255);
		SetShade(color(r, 0, b));
	}
}