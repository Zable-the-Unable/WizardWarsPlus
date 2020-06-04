#include "/Entities/Common/Attacks/Hitters.as";	   
#include "/Entities/Common/Attacks/LimitedAttacks.as";
#include "SpellCommon.as";

const int LIFETIME = 10;
const f32 SEARCH_RADIUS = 128.0f;
const f32 HOMING_FACTOR = 3.0f;
const f32 CORRECTION_FACTOR = 1.0f;
const int HOMING_DELAY = 15;	


void onInit(CBlob@ this)
{
	this.Tag("phase through spells");
    this.Tag('counterable');
    this.getShape().SetGravityScale(0);
    this.set_f32("targetAngle",0);
	this.SetMapEdgeFlags( u8(CBlob::map_collide_none) | u8(CBlob::map_collide_nodeath) ); //dont collide with edge of the map

    if(isServer())
    {this.server_SetTimeToDie(LIFETIME);}
    
	//burning sound	    
	if(isClient())
	{
		CSprite@ thisSprite = this.getSprite();
    	thisSprite.SetEmitSound("MolotovBurning.ogg");
    	thisSprite.SetEmitSoundVolume(5.0f);
    	thisSprite.SetEmitSoundPaused(false);
		thisSprite.getConsts().accurateLighting = false;
	}
}

void onTick( CBlob@ this)
{
	//trail
	if ( this.getTickSinceCreated() % 3 == 0 )
	{
		makeSmokeParticle(this);
	}
	
	//logic 
	CBlob@[] blobs;
    getMap().getBlobsInRadius(this.getPosition(),SEARCH_RADIUS,@blobs);
    CPlayer@ damageOwnerPlayer = this.getDamageOwnerPlayer();

    int index = closestBlobIndex(this,blobs,this.getDamageOwnerPlayer());
    if(index == -1) //if no target, accelerate normally.
	{
		Vec2f accel = this.getVelocity();
		accel.Normalize();
		this.AddForce(accel*0.2f);
		return;
	}

    CBlob@ target = blobs[index];

    int creaTicks = this.getTickSinceCreated();
    if( creaTicks >= HOMING_DELAY )//wait a bit before homing
    {
        Vec2f thisPos = this.getPosition();
        Vec2f targetPos = target.getPosition();
		Vec2f thisVel = this.getVelocity();
		thisVel.Normalize();
        Vec2f norm = targetPos - thisPos;
        norm.Normalize();
		norm -= (thisVel * CORRECTION_FACTOR);

        //Vec2f newVelocity = this.getVelocity() + (norm * HOMING_FACTOR);
        this.AddForce(norm*HOMING_FACTOR);
    }

    if(this.getDistanceTo(target) <= 5) //hit detection
    {
        if(target.getTeamNum() != this.getTeamNum())
        {
            float damage = 1.0f;
            if (target.getName() == "knight")
            {
                damage = 0.8f;
                if (target.hasTag("shielded"))
                {
                    if(isClient())
                    {this.getSprite().PlaySound("ShieldHit.ogg");}
                    damage = 0.2;
                }
            }
            this.server_Hit(target,target.getPosition(),this.getVelocity()*2,damage,Hitters::water);
			blast(this, 4);
            this.server_Die();
        }
    }
}

void onTick(CSprite@ this)
{
    this.ResetTransform();
    this.RotateBy(this.getBlob().getVelocity().getAngle() * -1,Vec2f_zero);
}

int closestBlobIndex(CBlob@ this, CBlob@[] blobs, CPlayer@ caster)
{
    f32 bestDistance = 99999999;
    int bestIndex = -1;

    for(int i = 0; i < blobs.length; i++){
		if (blobs[i] is null)
		{continue;}
        if ( this.getTeamNum() == blobs[i].getTeamNum() || (caster !is null && blobs[i] is caster.getBlob()) || !blobs[i].hasTag("flesh") )
		{continue;}
        f32 dist = this.getDistanceTo(blobs[i]);
        if(bestDistance > dist)
        {
            bestDistance = dist;
            bestIndex = i;
        }
    }
    return bestIndex;
}

void onCollision( CBlob@ this, CBlob@ blob, bool solid )
{
    if ( solid && (this.getTickSinceCreated() > (HOMING_DELAY * 2) ) )
    {
		blast(this, 4);
        this.server_Die();
    }

	if (blob is null)
	{return;}

	if (blob.hasTag("barrier"))
	{
		this.server_Hit(blob,blob.getPosition(),this.getVelocity(),2.4f,Hitters::water);
		blast(this, 4);
		this.server_Die();
	}
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

/*
void onCollision( CBlob@ this, CBlob@ blob, bool solid )
{	
	if ( this is null )
	{return;}

	if ( solid && this.getTickSinceCreated() > (HOMING_DELAY*3) )
	{
		Explode( this );
		this.server_Die();
		return;
	}
	
	if (blob !is null)
	{
		if ( (blob.hasTag("flesh") || blob.hasTag("kill other spells") || blob.hasTag("barrier")) && isEnemy(this, blob) )
		{
			f32 finalDamage = 1.0f;
			f32 extraDamage = 0.0f;
			if(blob.hasScript("BladedShell.as"))
			{finalDamage = 0.0f;}
			if(this.hasTag("extra_damage"))
			{extraDamage = 0.4f;}
			this.server_Hit(blob, blob.getPosition(), this.getVelocity(), (finalDamage + extraDamage) , Hitters::water, true);
			Explode( this );
			this.server_Die();
		}
	}
}
*/


void makeSmokeParticle( CBlob@ this )
{
	if (this is null)
	{ return; }
	if(!isClient()) return;

	const f32 rad = 1.0f;
	Vec2f random = Vec2f( XORRandom(128)-64, XORRandom(128)-64 ) * 0.015625f * rad;
	CParticle@ p = ParticleAnimated( "MissileFire1.png", this.getPosition()+random, Vec2f(0,0), float(XORRandom(360)), 0.5f, 6, 0.0f, false );
	if ( p !is null)
	{
		p.bounce = 0;
    	p.fastcollision = true;
		p.Z = 300.0f;
	}
}


/*
void makeSmokePuff(CBlob@ this, const f32 velocity = 1.0f, const int smallparticles = 10, const bool sound = true)
{
	if (this is null)
	{ return; }
	if ( !isClient() )
		return;
	
		f32 randomness = (XORRandom(32) + 32)*0.015625f * 0.5f + 0.75f;
		Vec2f vel = getRandomVelocity( -90, velocity * randomness, 360.0f );
		makeSmokeParticle(this, vel);
}
*/


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
        Vec2f vel(_blast_r.NextFloat() * 2.5f, 0);
        vel.RotateBy(_blast_r.NextFloat() * 360.0f);

        CParticle@ p = ParticleAnimated("GenericBlast6.png", 
									pos, 
									vel, 
									float(XORRandom(360)), 
									1.0f, 
									2 + XORRandom(4), 
									0.0f, 
									false );
									
        if(p is null) return; //bail if we stop getting particles
		
    	p.fastcollision = true;
        p.scale = 0.5f + _blast_r.NextFloat()*0.5f;
        p.damping = 0.85f;
		p.Z = 200.0f;
		p.lighting = false;
    }
}