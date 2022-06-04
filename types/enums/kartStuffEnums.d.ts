// SRB2kart - kartstuff
/** @compileMembersOnly */
declare enum Kartstuff {
    // Basic gameplay things
    k_position, // Used for Kart positions, mostly for deterministic stuff
    k_oldposition, // Used for taunting when you pass someone
    k_positiondelay, // Used for position number, so it can grow when passing/being passed
    k_prevcheck, // Previous checkpoint distance; for p_user.c (was "pw_pcd")
    k_nextcheck, // Next checkpoint distance; for p_user.c (was "pw_ncd")
    k_waypoint, // Waypoints.
    k_starpostwp, // Temporarily stores player waypoint for... some reason. Used when respawning and finishing.
    k_starpostflip, // the last starpost we hit requires flipping?
    k_respawn, // Timer for the DEZ laser respawn effect
    k_dropdash, // Charge up for respawn Drop Dash

    k_throwdir, // Held dir of controls; 1 = forward, 0 = none, -1 = backward (was "player->heldDir")
    k_lapanimation, // Used to show the lap start wing logo animation
    k_laphand, // Lap hand gfx to use; 0 = none, 1 = :ok_hand:, 2 = :thumbs_up:, 3 = :thumps_down:
    k_cardanimation, // Used to determine the position of some full-screen Battle Mode graphics
    k_voices, // Used to stop the player saying more voices than it should
    k_tauntvoices, // Used to specifically stop taunt voice spam
    k_instashield, // Instashield no-damage animation timer
    k_enginesnd, // Engine sound number you're on.

    k_floorboost, // Prevents Sneaker sounds for a breif duration when triggered by a floor panel
    k_spinouttype, // Determines whether to thrust forward or not while spinning out; 0 = move forwards, 1 = stay still

    k_drift, // Drifting Left or Right, plus a bigger counter = sharper turn
    k_driftend, // Drift has ended, used to adjust character angle after drift
    k_driftcharge, // Charge your drift so you can release a burst of speed
    k_driftboost, // Boost you get from drifting
    k_boostcharge, // Charge-up for boosting at the start of the race
    k_startboost, // Boost you get from start of race or respawn drop dash
    k_jmp, // In Mario Kart, letting go of the jump button stops the drift
    k_offroad, // In Super Mario Kart, going offroad has lee-way of about 1 second before you start losing speed
    k_pogospring, // Pogo spring bounce effect
    k_brakestop, // Wait until you've made a complete stop for a few tics before letting brake go in reverse.
    k_waterskip, // Water skipping counter
    k_dashpadcooldown, // Separate the vanilla SA-style dash pads from using pw_flashing
    k_boostpower, // Base boost value, for offroad
    k_speedboost, // Boost value smoothing for max speed
    k_accelboost, // Boost value smoothing for acceleration
    k_boostangle, // angle set when not spun out OR boosted to determine what direction you should keep going at if you're spun out and boosted.
    k_boostcam, // Camera push forward on boost
    k_destboostcam, // Ditto
    k_timeovercam, // Camera timer for leaving behind or not
    k_aizdriftstrat, // Let go of your drift while boosting? Helper for the SICK STRATZ you have just unlocked
    k_brakedrift, // Helper for brake-drift spark spawning

    k_itemroulette, // Used for the roulette when deciding what item to give you (was "pw_kartitem")
    k_roulettetype, // Used for the roulette, for deciding type (currently only used for Battle, to give you better items from Karma items)

    // Item held stuff
    k_itemtype, // KITEM_ constant for item number
    k_itemamount, // Amount of said item
    k_itemheld, // Are you holding an item?

    // Some items use timers for their duration or effects
    //k_thunderanim,			// Duration of Thunder Shield's use animation
    k_curshield, // 0 = no shield, 1 = thunder shield
    k_hyudorotimer, // Duration of the Hyudoro offroad effect itself
    k_stealingtimer, // You are stealing an item, this is your timer
    k_stolentimer, // You are being stolen from, this is your timer
    k_sneakertimer, // Duration of the Sneaker Boost itself
    k_growshrinktimer, // > 0 = Big, < 0 = small
    k_squishedtimer, // Squished frame timer
    k_rocketsneakertimer, // Rocket Sneaker duration timer
    k_invincibilitytimer, // Invincibility timer
    k_eggmanheld, // Eggman monitor held, separate from k_itemheld so it doesn't stop you from getting items
    k_eggmanexplode, // Fake item recieved, explode in a few seconds
    k_eggmanblame, // Fake item recieved, who set this fake
    k_lastjawztarget, // Last person you target with jawz, for playing the target switch sfx
    k_bananadrag, // After a second of holding a banana behind you, you start to slow down
    k_spinouttimer, // Spin-out from a banana peel or oil slick (was "pw_bananacam")
    k_wipeoutslow, // Timer before you slowdown when getting wiped out
    k_justbumped, // Prevent players from endlessly bumping into each other
    k_comebacktimer, // Battle mode, how long before you become a bomb after death
    k_sadtimer, // How long you've been sad

    // Battle Mode vars
    k_bumper, // Number of bumpers left
    k_comebackpoints, // Number of times you've bombed or gave an item to someone; once it's 3 it gets set back to 0 and you're given a bumper
    k_comebackmode, // 0 = bomb, 1 = item
    k_wanted, // Timer for determining WANTED status, lowers when hitting people, prevents the game turning into Camp Lazlo
    k_yougotem, // "You Got Em" gfx when hitting someone as a karma player via a method that gets you back in the game instantly

    // v1.0.2+ vars
    k_itemblink, // Item flashing after roulette, prevents Hyudoro stealing AND serves as a mashing indicator
    k_itemblinkmode, // Type of flashing: 0 = white (normal), 1 = red (mashing), 2 = rainbow (enhanced items)
    k_getsparks, // Disable drift sparks at low speed, JUST enough to give acceleration the actual headstart above speed
    k_jawztargetdelay, // Delay for Jawz target switching, to make it less twitchy
    k_spectatewait, // How long have you been waiting as a spectator
    k_growcancel, // Hold the item button down to cancel Grow

    NUMKARTSTUFF,
}
