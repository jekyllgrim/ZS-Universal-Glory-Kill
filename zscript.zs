version "4.12"

class Fist_ : Fist
{
	override void DoEffect()
	{
		Super.DoEffect();
		if (!owner || !owner.player) return;

		let weap = owner.player.readyweapon;
		if (!weap || weap != self) return;

		let psp = owner.player.FindPSPrite(PSP_WEAPON);
		if (!psp) return;
		let glorystate = FindState('GloryKill');
		if (!glorystate) return;

		if (InStateSequence(psp.curstate, glorystate))
		{}

		else if ((owner.player.cmd.buttons & BT_USE) && !(owner.player.oldbuttons & BT_USE))
		{
			let gktracer = new('GloryKillTracer');
			gktracer.Trace((owner.pos.xy, owner.player.viewz), cursector, (AngleToVector(owner.angle, cos(owner.pitch)), -sin(owner.pitch)), 80 + owner.radius * 2, TRF_ALLACTORS);
			if (gktracer.canGloryKill)
			{
				let v = gktracer.results.HitActor;
				if (v)
				{
					let gc = GloryKillController(v.FindInventory('GloryKillController'));
					if (gc)
					{
						gc.DoGloryKill();
					}
					psp.SetState(glorystate);
				}
			}
		}
	}

	States
	{
	GloryKill:
		PUNG BC 4;
		PUNG D 5;
		PUNG C 4;
		PUNG B 5;
		TNT1 A 0 { return ResolveState("Ready"); } //NOT goto
	}
}

class GloryKillTracer : LineTracer
{
	bool canGloryKill;

	override ETRaceStatus TraceCallBack()
	{
		if (results.HitType == TRACE_HitActor)
		{
			Console.Printf("hit %s", results.HitActor.GetClassName());
			let gc = GloryKillController(results.HitActor.FindInventory('GloryKillController'));
			if (gc)
			{
				Console.Printf("%s can be glorykilled", results.HitActor.GetClassName());
				canGloryKill = true;
				return TRACE_Stop;
			}
		}
		return TRACE_Skip;
	}
}

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

class GloryKillController : Powerup
{
	Actor gloryflash;

	Default
	{
		Powerup.Duration -5;
	}

	override void InitEffect()
	{
		Super.InitEffect();
		if (owner)
		{
			owner.bSHOOTABLE = false;
			owner.height = owner.default.height;
		}
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

	void DoGloryKill()
	{
		if (!owner) return;
		let st = owner.FindState("XDeath");
		if (st)
		{
			owner.SetState(st);
		}
		for (int i = 10; i > 0; i--)
		{
			owner.SpawnBlood(owner.pos, frandom[gc](0,360), 100);
		}
		effectTics = 0;
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
			owner.height = owner.deathheight;
		}
		Super.EndEffect();
	}
}

class GloryKillFlash : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		Renderstyle 'Shaded';
		+BRIGHT
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