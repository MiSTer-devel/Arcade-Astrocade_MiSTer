---------------------------------------------------------------------------------
-- 
-- Arcade version of Astrocade for MiSTer - Mike Coates
--
-- V 1.0 30/03/2020
-- V 1.1 06/04/2020
-- V 1.2 03/05/2020
-- V 1.3 13/09/2020 - Memory changes for Cabinet version
--                  - Sound chip now matches documentation (and sounds better)
-- V 1.4 18/10/2020 - WOW Speech added - Reggs
-- V 1.5 24/10/2020 - Gorf Program 1 added as an option (includes speech) - Reggs
-- V 1.6 16/02/2022 - Add Gorf audio option for cabinet or screens
-- V 1.7 27/04/2022 - Tidy up audio mixing, fix glitch on gorf cabinet mode
-- V 1.8 06/07/2023 - Colour pallette changed to 24 bit 
--                    Sparkle circuit changed (removed all custom colour hacks)
--                    Add lamp support for cabinet mode              
--                    Fix missing word (near) in Gorf program 1
--                    Fix samples in DDRAM error
-- V 1.9 13/07/2023   Fix star positions to match PCB
--                    Make sparkle look more like real PCB
--                    Fix missing word (annihilate) in Gorf program 1
-- V 2.0 24/04/2024   Add Freeplay for Space Zap
--                    Improve sound mixing
--
------------------------------------------------------------------------------------
-- From FPGA implementation of the Bally Astrocade based on a project by MikeJ et al
------------------------------------------------------------------------------------
--
-- Important info regarding Frame Buffer (FB)
--
-- Depending upon the setting of FB when this core is built, the samples (for Seawolf II, 
-- Gorf with speech and Wizard of Wor with speech) will use DDRAM or SDRAM. 
--
-- If FB is not defined, then the games will work on a bare DE10-Nano as they do not 
-- need SDRAM for any purpose but the screen will not rotate - this only affects Gorf
--
-- IF FB is defined then the DDRAM is used for the screen rotation for HDMI otuput so 
-- the samples will use SDRAM instead.
--
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
-- is setup to use an analogue joystick for player one. You can turn the sight for
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
-- analogue should work the same as the real game.
--
-- SC-01A speech implemented using full sentences recorded as samples
--
-- Robby Roto
-- ----------
-- setup using digital joystick
--
-- Gorf
-- ----
-- SC-01A speech implemented using words recorded as samples
-- Sound options 
--      Stereo will play voice samples on both channels
--      Cabinet will play one channel through top speaker, other channel or voice samples
--          through bottom speaker. (as per original hardware) 
---------------------------------------------------------------------------------

                                *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide the
correct ROMs.

To simplify the process .mra files are provided in the releases folder, that
specifies the required ROMs with checksums. The ROMs .zip filename refers to the
corresponding file of the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for
information on how to setup and use the environment.

Quickreference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/_Arcade/mame/<mame rom>.zip
/_Arcade/hbmame/<hbmame rom>.zip
