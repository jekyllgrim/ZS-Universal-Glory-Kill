version "4.12"

class GloryKillFist : Weapon
{
	Weapon prevWeapon;
	GloryKillController victim;
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
			gf.victim = victimController;
			gf.victimOfs = posOfs;
			ppawn.player.readyweapon = gf;
			ppawn.player.SetPSprite(PSP_WEAPON, gf.FindState("Ready"));
			ppawn.player.cheats |= CF_TOTALLYFROZEN;
			ppawn.A_Face(victimController.owner, 0, 0, z_ofs: victimController.owner.default.height*0.5);
			ppawn.A_Stop();
		}
	}

	override void DoEffect()
	{
		if (owner && victim && victim.owner)
		{
			owner.SetOrigin(victim.owner.pos + victimOfs, true);
		}
	}

	override void DetachFromOwner()
	{
		if (owner && owner.player)
		{
			owner.player.pendingweapon = prevWeapon;
			owner.player.cheats &= ~CF_INSTANTWEAPSWITCH;
			owner.player.cheats &= ~CF_TOTALLYFROZEN;
		}
		Super.DetachFromOwner();
	}

	States
	{
	Select:
		TNT1 A 0 { return ResolveState("Ready"); }
		wait;
	Deselect:
		TNT1 A 0 A_Lower();
		wait;
	Fire:
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
		GFIS B 0
		{
			if (invoker.victim)
			{
				invoker.victim.DoGloryKill();
			}
		}
		GFIS BBBBBBBBBB 1
		{
			A_OverlayOffset(OverlayID(), 5, 10, WOF_ADD);
			A_OverlayScale(OverlayID(), -0.015, -0.015, WOF_ADD);
		}
		TNT1 A 0 
		{ 
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

	Default
	{
		Powerup.Duration -5;
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
		owner.A_SetTics(-1);
	}

	// The glory kill visuals. This snaps the monster
	// from being frozen in the first state of Death,
	// sends it to XDeath (if available) and spawns some
	// blood.
	void DoGloryKill()
	{
		if (!owner) return;
		effectTics = 0;

		// Everything below in this function is visual-only
		// and can be redone in any way you like:
		let st = owner.FindState("XDeath");
		if (st)
		{
			owner.SetState(st);
		}
		FSpawnParticleParams bp;
		bp.color1 = (owner.bloodcolor != 0)? owner.bloodcolor : gameinfo.defaultbloodcolor;
		bp.startalpha = 1.0;
		bp.lifetime = 35;
		for (int i = 50; i > 0; i--)
		{
			bp.size = frandom[bp](10, 20);
			bp.pos = owner.pos + (frandom[bp](-owner.radius, owner.radius), frandom[bp](-owner.radius, owner.radius), frandom(owner.default.height*0.2, owner.default.height*0.8));
			bp.vel.xy = (frandom[bp](-8, 8), frandom[bp](-8, 8));
			bp.vel.z = frandom[bp](5, 8);
			bp.accel.z = -(owner.GetGravity());
			bp.accel.xy = -(bp.vel.xy * 0.05);
			bp.sizestep = -(bp.size / bp.lifetime);
			Level.SpawnParticle(bp);
		}
	}

	override void EndEffect()
	{
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