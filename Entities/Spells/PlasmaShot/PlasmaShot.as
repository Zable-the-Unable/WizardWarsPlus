#include "/Entities/Common/Attacks/Hitters.as"

void onInit(CBlob@ this)
{
	this.Tag("phase through spells");
    this.Tag("counterable");

	//default values
	this.set_f32("damage", 1.0f); 
	this.set_f32("move_Speed", 8.0f);
	this.set_Vec2f("target", Vec2f_zero);
	//^

    this.getShape().SetGravityScale(0);
	this.SetMapEdgeFlags( u8(CBlob::map_collide_none) | u8(CBlob::map_collide_nodeath) ); //dont collide with edge of the map

    if (isServer())
    {
		this.server_SetTimeToDie(10);
	}
    
	//burning sound	    
	if (isClient())
	{
		CSprite@ sprite = this.getSprite();

    	sprite.SetEmitSound("MolotovBurning.ogg");
    	sprite.SetEmitSoundVolume(5.0f);
    	sprite.SetEmitSoundPaused(false);
		sprite.getConsts().accurateLighting = false;
	}
}

void onTick(CSprite@ this) // note to glitch - this only runs on client, onTick is never called if blob is null
{
	this.ResetTransform();
    this.RotateBy(this.getBlob().getVelocity().getAngle() * -1,Vec2f_zero);
}

void onTick(CBlob@ this)
{
	Vec2f targetPos = this.get_Vec2f("target");
	if(targetPos == Vec2f_zero)
	{
		this.server_Die();
		return;
	}
	if(isClient())
	makeSmokeParticle(this, targetPos);

	Vec2f thisPos = this.getPosition();
	float standardSpeed = this.get_f32("move_Speed");

	Vec2f moveDir = targetPos - thisPos;
	float dist = moveDir.Length();

	Vec2f finalSpeed = moveDir;
	finalSpeed.Normalize();
	finalSpeed *= standardSpeed;

	if( dist > standardSpeed )
	{
		this.setVelocity(finalSpeed); //if farther away, use standard speed
	}
	else
	{
		this.setVelocity(moveDir); //if closer than needed, jump to that spot
	}

	if( dist < 2.0f )
	{
		explode(this);
	}
}

/// note (vam) -> I'm not touching these
void onCollision( CBlob@ this, CBlob@ blob, bool solid )
{
    if (solid)
    {
        explode(this);
		return;
    }

	if (blob is null) { return; }

	if(blob.getTeamNum() != this.getTeamNum() && blob.getName() != "mana_obelisk")
    {
		explode(this);
	}
}

void explode( CBlob@ this )
{
	CMap@ map = getMap();
	if (map is null)
	return;

	CBlob@[] attacked;
	map.getBlobsInRadius( this.getPosition(), 30.0f, @attacked );
	float damage = this.get_f32("damage");
	for (uint i = 0; i < attacked.size(); i++)
	{
		if(attacked[i] is null)
		{continue;}
		CBlob@ blob = attacked[i];

		CBlob@ caster = this.getDamageOwnerPlayer().getBlob();
		if(caster !is null && blob is caster)
		{
			this.server_Hit(blob,this.getPosition(),Vec2f_zero,damage,Hitters::water);
		}

		if(blob.getTeamNum() == this.getTeamNum())
		{continue;}

		float finalDamage = damage;

		if (blob.hasTag("barrier"))
		{
			finalDamage *= 2.0f;
		}
		else if (blob.getName() == "knight")
		{
    		finalDamage *= 0.8f;
            if (blob.hasTag("shielded"))
            {
                if(isClient())
                {this.getSprite().PlaySound("ShieldHit.ogg");}
                finalDamage *= 0.2;
            }
        }
		else if (!blob.hasTag("flesh")){ continue; }

		Vec2f attackNorm = blob.getPosition() - this.getPosition();
		attackNorm.Normalize();
		blob.AddForce(attackNorm*100);
        this.server_Hit(blob,this.getPosition(),Vec2f_zero,finalDamage,Hitters::water);
	}

	blast(this, 10); //boom effects

	this.server_Die();
}

bool doesCollideWithBlob( CBlob@ this, CBlob@ b )
{
	if(b is null){return false;}

	return 
	(
		b.getTeamNum() != this.getTeamNum()
		&& b.hasTag("barrier")//collides with enemy barriers
	); 
}

void makeSmokeParticle( CBlob@ this , Vec2f targetPos )
{
	if (this is null)
	{ return; }

	u8 teamNum = this.getTeamNum();
	Vec2f random = Vec2f(0,2.0f);
	random.RotateBy(XORRandom(360));

	string particleName = "MissileFire" + teamNum + ".png";

	CParticle@ p1 = ParticleAnimated( particleName , this.getPosition(), random/10, float(XORRandom(360)), 0.5f, 6, 0.0f, false );
	if ( p1 !is null)
	{
		p1.bounce = 0;
    	p1.fastcollision = true;
		p1.Z = 300.0f;
	}

	CParticle@ p2 = ParticleAnimated( particleName , targetPos, Vec2f_zero, float(XORRandom(360)), 0.5f, 6, 0.0f, false );
	if ( p2 !is null)
	{
		p2.bounce = 0;
    	p2.fastcollision = true;
		p2.Z = 300.0f;
		p2.frame = 3;
		p2.scale = 1.3f;
	}
}


Random _blast_r(0x10002);
void blast( CBlob@ this , int amount)
{
	if ( !isClient() )
		return;
	if ( this is null )
		return;

	this.getSprite().PlaySound("GenericExplosion1.ogg", 0.8f, 0.8f + XORRandom(10)/10.0f);

	Vec2f pos = this.getPosition();

	for (int i = 0; i < amount; i++)
    {
        Vec2f vel(_blast_r.NextFloat() * 3.0f, 0);
        vel.RotateBy(_blast_r.NextFloat() * 360.0f);

        CParticle@ p = ParticleAnimated("GenericBlast6.png", 
									pos, 
									vel, 
									float(XORRandom(360)), 
									1.5f, 
									2 + XORRandom(4), 
									0.0f, 
									false );
									
        if(p is null) continue; //bail if we stop getting particles
		
    	p.fastcollision = true;
        p.damping = 0.85f;
		p.Z = 200.0f;
		p.lighting = false;
    }
}
/// end (vam note)