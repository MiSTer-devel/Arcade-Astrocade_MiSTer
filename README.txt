---------------------------------------------------------------------------------
-- 
-- Arcade version of Astrocade for MiSTer
--
-- V 1.0 Mike Coates 30/03/2020
-- 
------------------------------------------------------------------------------------
-- From FPGA implementation of the Bally Astrocade based on a project by MikeJ et al
------------------------------------------------------------------------------------
--
-- Notes (on what does and doesn't work!)
--
-- Overall
--
-- Flickers a lot on HDMI output - looks better if you enable the HQ2x setting
-- (looks fine on direct video to arcade monitor)
--
-- P2 controls not tested for anything
--
-- Extra Bases
-- -----------
-- This usually uses a trackball, but at the moment it is set up to use an analogue 
-- joystick for player 1 only. 
--
-- Seawolf II
-- ----------
-- This normally uses two periscopes which send their position to the game, again this
-- is setup to use an analogue joystick for player one. You can turn the fake sight for
-- player two on and off via a fake dip switch setting. 
--
-- No sound (yet) since it uses discrete logic
-- 
-- Space Zap
-- ---------
-- Player one controls are setup using up/down/left/right - the real hardware uses 
-- buttons for these, not joystick controls, but should be playable.
--
-- Wizard of Wor
-- -------------
-- Controls are setup in two ways as the game has a unique joystick with two leaves
-- in each direction, so if you move it a little way, the player turns to face and shoot
-- that way. If you move it further, then the player moves that way.
--
-- n.b. fake dipswitch settings to select Digital or Analogue controls
-- digital is implemented as directions and two fire buttons. (as per Mame)
-- analogue should do the same as the real game.
--
-- No SC-01A speech chip implemented.
--
-- Robby Roto
-- ----------
-- setup using digital joystick
--
-- Gorf
-- ----
-- (mra file text included below, since it doesn't work!)
--
-- When it initially draws the screen, it sets all colours to black, so doesn't 
-- show anything, but forcing some fake colours shows some things being drawn in
-- the correct place, and some being drawn at random addresses - which causes it 
-- to reset, since it can overwrite ram. It also changes the registers for the 
-- magic write so it does inverse or double size when it draws. some of the code
-- was trying to correct different reasons I thought this was happening, and is
-- probably not required when the actual cause be discovered!
--
-- No SC-01A speech chip implemented.
-- Controls / dips not tested
---------------------------------------------------------------------------------

                                *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide a correct ROM file.

Find this zip file somewhere. You need to find the file exactly as required.
Do not rename other zip files even if they also represent the same game - they are not compatible!
The name of zip is taken from M.A.M.E. project, so you can get more info about
hashes and contained files there.

-----------------------------------------------
-- Gorf mra file for those who wish to debug --
-----------------------------------------------

<misterromdescription>
	<name>Gorf</name>
	<mameversion>0126</mameversion>
	<mratimestamp>202003130000</mratimestamp>
	<year>1983</year>
	<manufacturer>Bally</manufacturer>
	<category>Space</category>
	<rbf>astrocade</rbf>
	<switches default="00,00,03,FF">
		<dip bits="12"    name="Debug overlay" ids="Off,On"/>
		<dip bits="16"    name="Cabinet" ids="Cocktail,Upright"/>
		<dip bits="17"    name="Service" ids="On,Off"/>
		<dip bits="25,26" name="Coinage" ids="1c/5cr,1c/3cr,2c/1cr,1c/1cr"/>
                <dip bits="27"    name="language" ids="Foreign,English"/>
                <dip bits="28"    name="Lives"   ids="3,2"/>
                <dip bits="29"    name="Bonus"   ids="None,Mission 5"/>
                <dip bits="30"    name="Freeplay" ids="On,Off"/>
                <dip bits="31"    name="demo sound" ids="On,Off"/>
	</switches>
	<rom index="1">
		<part>04</part>
	</rom>  
	<rom index="0" zip="gorf.zip" md5="cf4fe2ecfdc33a1dd4ee9e000a1c7bc2" type="nonmerged">
		<part name="gorf-a.bin"/>
		<part name="gorf-b.bin"/>
		<part name="gorf-c.bin"/>
		<part name="gorf-d.bin"/>
		<part name="gorf-e.bin"/>
		<part name="gorf-f.bin"/>
		<part name="gorf-g.bin"/>
		<part name="gorf-h.bin"/>
	</rom>
</misterromdescription>
