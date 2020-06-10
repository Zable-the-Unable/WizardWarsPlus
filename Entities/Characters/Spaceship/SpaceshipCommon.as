// Runner Common

shared class RunnerMoveVars
{
	//flying vars
	f32 flySpeed;  //target vel
	f32 flySpeedInAir;
	f32 flyFactor;

	//jumping vars
	f32 jumpMaxVel;
	f32 jumpStart;
	f32 jumpMid;
	f32 jumpEnd;
	f32 jumpFactor;
	s32 jumpCount; //internal counter
	s32 fallCount; //internal counter only moving down

	//vaulting vars
	bool canVault;

	//scale the entire movement
	f32 overallScale;

	//force applied while... stopping
	f32 stoppingForce;
	f32 stoppingForceAir;
	f32 stoppingFactor;

	// moved from tags...
	bool walljumped;
	s32 walljumped_side;
	s32 wallrun_length;
	f32 wallrun_start;
	f32 wallrun_current;
	bool wallclimbing;
	bool wallsliding;
};

namespace Walljump
{
	enum WalljumpSide
	{
		NONE,
		LEFT,
		JUMPED_LEFT,
		RIGHT,
		JUMPED_RIGHT,
		BOTH
	};
}
