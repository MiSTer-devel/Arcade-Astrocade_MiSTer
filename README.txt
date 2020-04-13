---------------------------------------------------------------------------------
-- 
-- Arcade version of Astrocade for MiSTer - Mike Coates
--
-- V 1.0 30/03/2020
-- V 1.1 06/04/2020
-- 
------------------------------------------------------------------------------------
-- From FPGA implementation of the Bally Astrocade based on a project by MikeJ et al
------------------------------------------------------------------------------------
--
-- Notes (on what does and doesn't work!)
--
-- Overall
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
-- Sound uses samples, originally from mame but modified to closer match the hardware
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
-- No SC-01A speech chip implemented.
---------------------------------------------------------------------------------

                                *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide a correct ROM file.

Find this zip file somewhere. You need to find the file exactly as required.
Do not rename other zip files even if they also represent the same game - they are not compatible!
The name of zip is taken from M.A.M.E. project, so you can get more info about
hashes and contained files there.
