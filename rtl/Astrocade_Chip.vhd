--
-- A simulation model of Bally Astrocade hardware
-- Copyright (c) MikeJ - Nov 2004
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.fpgaarcade.com
--
-- Email support@fpgaarcade.com
--
-- Revision list
--
-- version 003 spartan3e release
-- version 001 initial release
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

library UNISIM;
  use UNISIM.Vcomponents.all;

entity BALLY_IO is
  port (
    I_MXA             : in    std_logic_vector(15 downto  0);
    I_MXD             : in    std_logic_vector( 7 downto  0);
    O_MXD             : out   std_logic_vector( 7 downto  0);
    O_MXD_OE_L        : out   std_logic;

    -- cpu control signals
    I_M1_L            : in    std_logic; -- not on real chip
    I_RD_L            : in    std_logic;
    I_IORQ_L          : in    std_logic;
    I_RESET_L         : in    std_logic;

    -- no pots - student project ? :)

    -- switches
    O_SWITCH          : out   std_logic_vector( 7 downto 0); -- O_SWITCH_COL, -- Goes to PS2_if from bally IO and is called I_COL in PS2_if
    I_SWITCH          : in    std_logic_vector( 7 downto 0);

	O_speech_17			: out   std_logic_vector( 7 downto 0); -- Data byte out to UART in Bally Top
	O_speech_trigger	: out   std_logic; -- Speech trigger out to SC01\UART in Bally Top
	ACKREQ				: in    std_logic; -- Acknowledge phoneme or request data from SC01 or UART

	
	BTN0				: in    std_logic; 
	BTN1				: in    std_logic; 
	BTN2				: in    std_logic; 
	BTN3				: in    std_logic; 

	
	BTN_NORTH         	: in    std_logic;
	BTN_EAST         	: in    std_logic;
	BTN_SOUTH         	: in    std_logic;
	BTN_WEST 			: in    std_logic;

	Switch_2			: in    std_logic; -- Demo sounds DIP switch
	Switch_3			: in    std_logic; -- Service mode DIP switch

    -- audio
    O_AUDIO           : out   std_logic_vector( 7 downto 0);
    -- clks
    I_CPU_ENA         : in    std_logic;
    I_PIX_ENA         : in    std_logic; -- real chip doesn't get pixel clock
    ENA               : in    std_logic;
    CLK               : in    std_logic
    );
end;

architecture RTL of BALLY_IO is
  --  Signals
  type  array_8x8             is array (0 to 7) of std_logic_vector(7 downto 0);
  type  array_4x8             is array (0 to 3) of std_logic_vector(7 downto 0);
  type  array_3x8             is array (0 to 2) of std_logic_vector(7 downto 0);
  type  array_4x4             is array (0 to 3) of std_logic_vector(3 downto 0);

  type  array_bool8           is array (0 to 7) of boolean;

  signal cs                   : std_logic;
  signal snd_ld               : array_bool8;
  signal r_snd                : array_8x8 := (x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00");
  signal r_pot                : array_4x8 := (x"00",x"00",x"00",x"00");
  signal mxd_out_reg          : std_logic_vector(7 downto 0) := x"00";

  signal io_read              : std_logic;
  signal switch_read          : std_logic;
  -- audio
  signal master_ena           : std_logic;
  signal master_cnt           : std_logic_vector(7 downto 0);
  signal master_osc_freq          : std_logic_vector(7 downto 0);

  signal vibrato_cnt          : std_logic_vector(18 downto 0);
  signal vibrato_ena          : std_logic;

  signal poly15               : std_logic_vector(15 downto 0):= "0000000000000000";
  signal counter_up 			: std_logic_vector(5 downto 0) := "000000";
  signal counter	 			: std_logic := '0';
--  signal w_XNOR		 			: std_logic := '0';

--  signal poly17               : std_logic_vector(16 downto 0);
  signal noise_gen            : std_logic_vector(7 downto 0);

  signal tone_gen             : array_3x8 := (others => (others => '0'));
  signal tone_gen_op          : std_logic_vector(2 downto 0);
--  signal fire_sig				   : std_logic_vector (0 downto 0); -- Temp fire
--  signal test_press           : std_logic_vector(1024 downto 0);-- := "0000000";

--  signal coin_1          		: std_logic;
--  signal coin_2						: std_logic;
--  signal P1_Start					: std_logic;
--  signal P2_Start					: std_logic;
	
  
begin


  p_chip_sel             : process(I_CPU_ENA, I_MXA)
  begin
    cs <= '0';
    if (I_CPU_ENA = '1') then -- cpu access
      if (I_MXA(7 downto 4) = "0001") then
        cs <= '1';
      end if;
    end if;
  end process;
  --
  -- registers
  --
  p_reg_write_blk_decode : process(I_CPU_ENA, I_RD_L, I_M1_L, I_IORQ_L, cs, I_MXA) -- no m1 gating on real chip ?
  begin
    -- these writes will last for several cpu_ena cycles, so you
    -- will get several load pulses
    snd_ld <= (others => false);
    if (I_CPU_ENA = '1') then
      if (I_RD_L = '1') and (I_IORQ_L = '0') and (I_M1_L = '1') and (cs = '1') then
        -- snd_ld(0) <= (I_MXA( 3 downto 0) = x"0") or ((I_MXA(10 downto 8) = "000") and (I_MXA(3 downto 0) = x"8"));

        -- snd_ld(1) <= (I_MXA( 3 downto 0) = x"1") or ((I_MXA(10 downto 8) = "001") and (I_MXA(3 downto 0) = x"8"));

        -- snd_ld(2) <= (I_MXA( 3 downto 0) = x"2") or ((I_MXA(10 downto 8) = "010") and (I_MXA(3 downto 0) = x"8"));

        -- snd_ld(3) <= (I_MXA( 3 downto 0) = x"3") or ((I_MXA(10 downto 8) = "011") and (I_MXA(3 downto 0) = x"8"));

        -- snd_ld(4) <= (I_MXA( 3 downto 0) = x"4") or ((I_MXA(10 downto 8) = "100") and (I_MXA(3 downto 0) = x"8"));

        -- snd_ld(5) <= (I_MXA( 3 downto 0) = x"5") or ((I_MXA(10 downto 8) = "101") and (I_MXA(3 downto 0) = x"8"));

        -- snd_ld(6) <= (I_MXA( 3 downto 0) = x"6") or ((I_MXA(10 downto 8) = "110") and (I_MXA(3 downto 0) = x"8"));

        -- snd_ld(7) <= (I_MXA( 3 downto 0) = x"7") or ((I_MXA(10 downto 8) = "111") and (I_MXA(3 downto 0) = x"8"));





        snd_ld(0) <= ( I_MXA( 3 downto 0) = x"0") ;

        snd_ld(1) <= ( I_MXA( 3 downto 0) = x"1") ;

        snd_ld(2) <= ( I_MXA( 3 downto 0) = x"2") ;

        snd_ld(3) <= ( I_MXA( 3 downto 0) = x"3") ;

        snd_ld(4) <= ( I_MXA( 3 downto 0) = x"4") ;

        snd_ld(5) <= ( I_MXA( 3 downto 0) = x"5") ;

        snd_ld(6) <= ( I_MXA( 3 downto 0) = x"6") ;

        snd_ld(7) <= ( I_MXA( 3 downto 0) = x"7") ;




      end if;
    end if;
  end process;

  p_reg_write_blk        : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (I_RESET_L = '0') then -- don't know if reset does reset the sound
        r_snd <= (others => (others => '0'));
      else
        for i in 0 to 7 loop
          if snd_ld(i) then r_snd(i) <= I_MXD; end if;
        end loop;
      end if;
    end if;
  end process;


-- SC01
-- ACKREQ: 0 = Acknowledge receipt, 1 = Ready
-- STROBE - Latching occurs on rising edge of Strobe signal
-- MC14539B must be BUFFA1/B=1 : BUFFA0/A=0 IORQ=0 to select ACKREQ
-- BUFFA0 and A1 are just buffered  A0 A1 from CPU same as I_MXA(0)&(1)
	-- speech : process
	-- begin
    -- wait until rising_edge(CLK);
	
	-- if (ENA = '1') then
			-- if ACKREQ = '0' then --x"17" Speech -- In on port 17 
			-- O_speech_17 (7 downto 0) <= I_MXA(15 downto 8); -- 6 bits wide SC01 inputs from U24 74LS367  Tristate non inverting buffer (Speech is in 6 bits 13 downto 8 only !)

-- --			if I_MXA(0) = '0' and I_MXA(1) = '1' and ACKREQ = '0' then -- ACKREQ = 1 means ready
				-- O_speech_trigger <= '1'; -- High speak
				-- else 
				-- O_speech_trigger <= '0'; -- Low Dont speak
			-- end if;
	-- end if;
	-- end process;





  p_reg_read             : process
  begin
    wait until rising_edge(CLK);

    if (ENA = '1') then
-- 		mxd_out_reg <= x"00"; -- Speech okay better than xFF
 		mxd_out_reg <= x"FF"; -- Force everything to off

-- 		mxd_out_reg (3) <= '1'; -- For some reason I have to do this otherwise I get a crash ! = 8




--      if (I_MXA(4 downto 3)) = "10" then  -- means 1(0)111 If is below 17 so Keypad ports x17 to x10 from PS2
--        mxd_out_reg <= I_SWITCH(7 downto 0); 
--		end if;
	  -- Put my inputs in here
		if (I_IORQ_L = '0') and (I_RD_L = '0') and I_M1_L = '1' then -- READ -- I_M1_L is not on real chip but how do I know if its an INTACK without it?




-- Schematic controls ALL OF them

		-- 1	L UP				110 	S10 S11		 	Pin 06 SO X0 goes to S10=1 S11=1 
		-- 2	L Down				111 	S10 S11			Pin 11 Y1 Y1 goes to S10=1 S11=1 
		-- 3	L Left				112		S12 S13
		-- 4	L Right				113		S12 S13
		-- 5	L Move				114		S06 S07
		-- 6								
		-- 7	
		-- 8	R UP				120		S10 S11
		-- 9	R Down				121		S10 S11
		-- 10	R Left				122		S12 S13
		-- 11	R Right				123		S12 S13
		-- 12	R Fire				124		S06 S07		Not on Gorf
		-- 13	
		-- 14	
		-- 15	
		-- 16	Coin 1				100		S10 S11
		-- 17	Coin 2				101		S10 S11
		-- 18	Coin 3				106		S16 S17		Not on Gorf
		-- 19	Test				102		S12 S13		
		-- 20 	Slam				103		S12 S13
		-- 21	Sel 1 Plr			104		S06 S07

		-- 22	Sel 2 Plr			105		S06 S07
		--							115		Ground		Lamps?
		--							125		Ground		Lamps?
		--							135		Bonus	
		
		-- 8 dip switches
		-- 1						130		S10 S11 
		-- 2						131		S10 S11	
		-- 3						132		S12 S13
		-- 4						133		S12 S13
		-- 5						134		S06 S07
		-- 6						135
		-- 7						136		S16 S17
		-- 8						137		S16 S17	Grounded
		-- x						107 	S16 S17 Jumper to ground

		
		-- 18						106 	S16 S17
		-- 06						115		S16 S17
		-- 13						125		S16 S17


	-- cd4099_device &outlatch(CD4099(config, "outlatch")); // MC14099B on game board at U6
	-- outlatch.q_out_cb<0>().set(FUNC(astrocde_state::coin_counter_w<0>));
	-- outlatch.q_out_cb<1>().set(FUNC(astrocde_state::coin_counter_w<1>));
	-- outlatch.q_out_cb<2>().set(FUNC(astrocde_state::sparkle_w<0>));
	-- outlatch.q_out_cb<3>().set(FUNC(astrocde_state::sparkle_w<1>));
	-- outlatch.q_out_cb<4>().set(FUNC(astrocde_state::sparkle_w<2>));
	-- outlatch.q_out_cb<5>().set(FUNC(astrocde_state::sparkle_w<3>));
	-- outlatch.q_out_cb<6>().set(FUNC(astrocde_state::gorf_sound_switch_w));
	-- outlatch.q_out_cb<7>().set_output("lamp6");

	-- cd4099_device &lamplatch(CD4099(config, "lamplatch")); // MC14099B on game board at U7
	-- lamplatch.q_out_cb<0>().set_output("lamp0");
	-- lamplatch.q_out_cb<1>().set_output("lamp1");
	-- lamplatch.q_out_cb<2>().set_output("lamp2");
	-- lamplatch.q_out_cb<3>().set_output("lamp3");
	-- lamplatch.q_out_cb<4>().set_output("lamp4");
	-- lamplatch.q_out_cb<5>().set_output("lamp5");
	-- lamplatch.q_out_cb<6>().set_nop(); // n/c
	-- lamplatch.q_out_cb<7>().set_output("lamp7");



-- MAME
	-- static INPUT_PORTS_START( gorf )				-- X0010
	-- PORT_START("P1HANDLE")
	-- PORT_BIT( 0x01, IP_ACTIVE_LOW, IPT_COIN1 )
	-- PORT_BIT( 0x02, IP_ACTIVE_LOW, IPT_COIN2 )
	-- PORT_SERVICE( 0x04, IP_ACTIVE_LOW )
	-- PORT_BIT( 0x08, IP_ACTIVE_LOW, IPT_TILT )
	-- PORT_BIT( 0x10, IP_ACTIVE_LOW, IPT_START1 )
	-- PORT_BIT( 0x20, IP_ACTIVE_LOW, IPT_START2 )
	-- PORT_DIPNAME( 0x40, 0x40, DEF_STR( Cabinet ) )      PORT_DIPLOCATION("JU:1")    /* Jumper */
	-- PORT_DIPSETTING(    0x40, DEF_STR( Upright ) )
	-- PORT_DIPSETTING(    0x00, DEF_STR( Cocktail ) )
	-- PORT_DIPNAME( 0x80, 0x80, "Speech" )                PORT_DIPLOCATION("JU:2")    /* Jumper */
	-- PORT_DIPSETTING(    0x00, DEF_STR( Off ) )
	-- PORT_DIPSETTING(    0x80, DEF_STR( On ) )

	-- PORT_START("P2HANDLE")						-- X0011
	-- PORT_BIT( 0x01, IP_ACTIVE_LOW, IPT_JOYSTICK_UP ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x02, IP_ACTIVE_LOW, IPT_JOYSTICK_DOWN ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x04, IP_ACTIVE_LOW, IPT_JOYSTICK_LEFT ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x08, IP_ACTIVE_LOW, IPT_JOYSTICK_RIGHT ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x10, IP_ACTIVE_LOW, IPT_BUTTON1 ) PORT_COCKTAIL
	-- PORT_BIT( 0xe0, IP_ACTIVE_LOW, IPT_UNUSED )

	-- PORT_START("P3HANDLE")						-- X0012
	-- PORT_BIT( 0x01, IP_ACTIVE_LOW, IPT_JOYSTICK_UP ) PORT_8WAY
	-- PORT_BIT( 0x02, IP_ACTIVE_LOW, IPT_JOYSTICK_DOWN ) PORT_8WAY
	-- PORT_BIT( 0x04, IP_ACTIVE_LOW, IPT_JOYSTICK_LEFT ) PORT_8WAY
	-- PORT_BIT( 0x08, IP_ACTIVE_LOW, IPT_JOYSTICK_RIGHT ) PORT_8WAY
	-- PORT_BIT( 0x10, IP_ACTIVE_LOW, IPT_BUTTON1 )
	-- PORT_BIT( 0x60, IP_ACTIVE_LOW, IPT_UNUSED )
	-- PORT_BIT( 0x80, IP_ACTIVE_HIGH, IPT_CUSTOM ) PORT_CUSTOM_MEMBER(DEVICE_SELF, astrocde_state, votrax_speech_status_r, nullptr)

	-- PORT_START("P4HANDLE")						-- X0013
	-- PORT_DIPNAME( 0x01, 0x01, DEF_STR( Coin_A ) )       PORT_DIPLOCATION("S1:1")
	-- PORT_DIPSETTING(    0x00, DEF_STR( 2C_1C ) )
	-- PORT_DIPSETTING(    0x01, DEF_STR( 1C_1C ) )
	-- PORT_DIPNAME( 0x06, 0x06, DEF_STR( Coin_B ) )       PORT_DIPLOCATION("S1:2,3")
	-- PORT_DIPSETTING(    0x04, DEF_STR( 2C_1C ) )
	-- PORT_DIPSETTING(    0x06, DEF_STR( 1C_1C ) )
	-- PORT_DIPSETTING(    0x02, DEF_STR( 1C_3C ) )
	-- PORT_DIPSETTING(    0x00, DEF_STR( 1C_5C ) )
	-- PORT_DIPNAME( 0x08, 0x08, DEF_STR( Language ) )     PORT_DIPLOCATION("S1:4")
	-- PORT_DIPSETTING(    0x08, DEF_STR( English ) )
	-- PORT_DIPSETTING(    0x00, "Foreign (NEED ROM)" )    /* "Requires A082-91374-A000" */
	-- PORT_DIPNAME( 0x10, 0x00, "Lives per Credit" )      PORT_DIPLOCATION("S1:5")
	-- PORT_DIPSETTING(    0x10, "2" )
	-- PORT_DIPSETTING(    0x00, "3" )
	-- PORT_DIPNAME( 0x20, 0x20, DEF_STR( Bonus_Life ) )   PORT_DIPLOCATION("S1:6")
	-- PORT_DIPSETTING(    0x00, DEF_STR( None ) )
	-- PORT_DIPSETTING(    0x20, "Mission 5" )
	-- PORT_DIPNAME( 0x40, 0x40, DEF_STR( Free_Play ) )    PORT_DIPLOCATION("S1:7")
	-- PORT_DIPSETTING(    0x40, DEF_STR( Off ) )
	-- PORT_DIPSETTING(    0x00, DEF_STR( On ) )
	-- PORT_DIPNAME( 0x80, 0x80, DEF_STR( Demo_Sounds ) )  PORT_DIPLOCATION("S1:8")
	-- PORT_DIPSETTING(    0x00, DEF_STR( Off ) )
	-- PORT_DIPSETTING(    0x80, DEF_STR( On ) )
-- INPUT_PORTS_END


-- 
-- x14	Keypad
-- x15	Keypad
-- x16	Keypad
-- x17	Keypad

-- x1C	Player 1 POT 1
-- x1D	Player 1 POT 2
-- x1E	Player 1 POT 3
-- x1F	Player 1 POT 4



-----------------------------------------------------------------------
-- A '1' below = OFF 
-----------------------------------------------------------------------
---- Player handle 1
	-- static INPUT_PORTS_START( gorf )				-- X0010
	-- PORT_START("P1HANDLE")
	-- PORT_BIT( 0x01, IP_ACTIVE_LOW, IPT_COIN1 )
	-- PORT_BIT( 0x02, IP_ACTIVE_LOW, IPT_COIN2 )
	-- PORT_SERVICE( 0x04, IP_ACTIVE_LOW )
	-- PORT_BIT( 0x08, IP_ACTIVE_LOW, IPT_TILT )
	-- PORT_BIT( 0x10, IP_ACTIVE_LOW, IPT_START1 )
	-- PORT_BIT( 0x20, IP_ACTIVE_LOW, IPT_START2 )
	-- PORT_DIPNAME( 0x40, 0x40, DEF_STR( Cabinet ) )      PORT_DIPLOCATION("JU:1")    /* Jumper */
	-- PORT_DIPSETTING(    0x40, DEF_STR( Upright ) )
	-- PORT_DIPSETTING(    0x00, DEF_STR( Cocktail ) )
	-- PORT_DIPNAME( 0x80, 0x80, "Speech" )                PORT_DIPLOCATION("JU:2")    /* Jumper */
	-- PORT_DIPSETTING(    0x00, DEF_STR( Off ) )
	-- PORT_DIPSETTING(    0x80, DEF_STR( On ) )
	
	
--			if (I_MXA(15 downto 0)) = x"10" then -- x10 Player handle 1
			if (I_MXA(7 downto 0)) = x"10" then -- x10 Player handle 1
					mxd_out_reg (0) <= not BTN1; 			-- x1	Coin 1

					mxd_out_reg (1) <= '1';					-- x2	Coin 2

					mxd_out_reg (2) <= not Switch_3;		-- x4 	Service Mode 1=Off 0=On		Mame says active low - On 3A Up is + 3.3v, Down is off Ground

					mxd_out_reg (3) <= '1';					-- x8 	TILT						Mame says active low

					mxd_out_reg (4) <= not BTN3;			-- x10	Start P1 FROM FX2 LEFT
					
					mxd_out_reg (5) <= not BTN2;			-- x20	Start P2 FROM FX2 RIGHT
					
					mxd_out_reg (6) <= '1';					-- x40 	1 = Upright \ 0 = Cocktail (Goes upside down and will also use a different controller port)
					mxd_out_reg (7) <= '1';					-- X80 	Speech 1=ON 0=Off
			end if;
-----------------------------------------------------------------------
---- Player handle 2 -- Cocktail Unused

	-- PORT_START("P2HANDLE")						-- X0011
	-- PORT_BIT( 0x01, IP_ACTIVE_LOW, IPT_JOYSTICK_UP ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x02, IP_ACTIVE_LOW, IPT_JOYSTICK_DOWN ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x04, IP_ACTIVE_LOW, IPT_JOYSTICK_LEFT ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x08, IP_ACTIVE_LOW, IPT_JOYSTICK_RIGHT ) PORT_8WAY PORT_COCKTAIL
	-- PORT_BIT( 0x10, IP_ACTIVE_LOW, IPT_BUTTON1 ) PORT_COCKTAIL
	-- PORT_BIT( 0xe0, IP_ACTIVE_LOW, IPT_UNUSED )

			if (I_MXA(7 downto 0)) = x"11" then -- x11 Player handle 2
					mxd_out_reg <= x"FF";
			end if;

-----------------------------------------------------------------------
	-- PORT_START("P3HANDLE")						-- X0012
	-- PORT_BIT( 0x01, IP_ACTIVE_LOW, IPT_JOYSTICK_UP ) PORT_8WAY
	-- PORT_BIT( 0x02, IP_ACTIVE_LOW, IPT_JOYSTICK_DOWN ) PORT_8WAY
	-- PORT_BIT( 0x04, IP_ACTIVE_LOW, IPT_JOYSTICK_LEFT ) PORT_8WAY
	-- PORT_BIT( 0x08, IP_ACTIVE_LOW, IPT_JOYSTICK_RIGHT ) PORT_8WAY
	-- PORT_BIT( 0x10, IP_ACTIVE_LOW, IPT_BUTTON1 )
	-- PORT_BIT( 0x60, IP_ACTIVE_LOW, IPT_UNUSED )
	-- PORT_BIT( 0x80, IP_ACTIVE_HIGH, IPT_CUSTOM ) PORT_CUSTOM_MEMBER(DEVICE_SELF, astrocde_state, votrax_speech_status_r, nullptr) -- This changed at some point in Mame as the Votrax ready register wasn't there!

			if (I_MXA(7 downto 0)) = x"12" then -- x12 Player handle 3

				mxd_out_reg (0) <= not BTN_NORTH;	-- UP				1
				mxd_out_reg (1) <= not BTN_SOUTH;	-- Down				2
				mxd_out_reg (2) <= not BTN_WEST;	-- Left				3
				mxd_out_reg (3) <= not BTN_EAST;	-- Right 			4

-- PMOD 4 button board
				mxd_out_reg (4) <= not BTN0;		-- Fire	/ Trigger	5
				mxd_out_reg (5) <= '1';				-- Unused Line 124 X2 Right Fire, open in Gorf schematic / Mame testmode has it lit so Im setting to 1
				mxd_out_reg (6) <= '1';				-- Unused Line 125 Y2 / Mame testmode has it lit so Im setting to 1
				mxd_out_reg (7) <= ACKREQ;			-- Votrax SC01 Ready 	; Bit 7 is a 1 when SC01 is ready, thanks David Turner :)

			end if;

-----------------------------------------------------------------------
	-- PORT_START("P4HANDLE")						-- X0013
	-- PORT_DIPNAME( 0x01, 0x01, DEF_STR( Coin_A ) )       PORT_DIPLOCATION("S1:1")
	-- PORT_DIPSETTING(    0x00, DEF_STR( 2C_1C ) )
	-- PORT_DIPSETTING(    0x01, DEF_STR( 1C_1C ) )
	-- PORT_DIPNAME( 0x06, 0x06, DEF_STR( Coin_B ) )       PORT_DIPLOCATION("S1:2,3")
	-- PORT_DIPSETTING(    0x04, DEF_STR( 2C_1C ) )
	-- PORT_DIPSETTING(    0x06, DEF_STR( 1C_1C ) )
	-- PORT_DIPSETTING(    0x02, DEF_STR( 1C_3C ) )
	-- PORT_DIPSETTING(    0x00, DEF_STR( 1C_5C ) )
	-- PORT_DIPNAME( 0x08, 0x08, DEF_STR( Language ) )     PORT_DIPLOCATION("S1:4")
	-- PORT_DIPSETTING(    0x08, DEF_STR( English ) )
	-- PORT_DIPSETTING(    0x00, "Foreign (NEED ROM)" )    /* "Requires A082-91374-A000" */
	-- PORT_DIPNAME( 0x10, 0x00, "Lives per Credit" )      PORT_DIPLOCATION("S1:5")
	-- PORT_DIPSETTING(    0x10, "2" )
	-- PORT_DIPSETTING(    0x00, "3" )
	-- PORT_DIPNAME( 0x20, 0x20, DEF_STR( Bonus_Life ) )   PORT_DIPLOCATION("S1:6")
	-- PORT_DIPSETTING(    0x00, DEF_STR( None ) )
	-- PORT_DIPSETTING(    0x20, "Mission 5" )
	-- PORT_DIPNAME( 0x40, 0x40, DEF_STR( Free_Play ) )    PORT_DIPLOCATION("S1:7")
	-- PORT_DIPSETTING(    0x40, DEF_STR( Off ) )
	-- PORT_DIPSETTING(    0x00, DEF_STR( On ) )
	-- PORT_DIPNAME( 0x80, 0x80, DEF_STR( Demo_Sounds ) )  PORT_DIPLOCATION("S1:8")
	-- PORT_DIPSETTING(    0x00, DEF_STR( Off ) )
	-- PORT_DIPSETTING(    0x80, DEF_STR( On ) )
	
-- Player handle 4 -- GB Dip Switches
			if (I_MXA(7 downto 0)) = x"13" then -- 10011  x13 Player handle 4
				mxd_out_reg (0) <= '1';		--Switch 	1	-- x1	Coin A   0=2C-1C 	1=1C-1C (Switch 1)
				mxd_out_reg (1) <= '1';		--Switch	2	-- x2	Coin B	1c-1c 2c-1c 1c-3C 1c-5c
				mxd_out_reg (2) <= '1';		--Switch	3	-- x4 	Coin B
				mxd_out_reg (3) <= '1';		--Switch	4	-- x8 	Lang  English 1  0 Foreign
				mxd_out_reg (4) <= '1';		--Switch	5	-- x10	Lives per Credit 1,2,3
				mxd_out_reg (5) <= '0';		--Switch	6	-- x20	Bonus Life Mission 5, OFF = No bonus, On = Bonus given
				mxd_out_reg (6) <= '1';		--Switch	7	-- x40 	X3 Line 136, Free Play 	1=Free play 0=Coin play -- This changes becuase dependant on other switch settings
--				mxd_out_reg (7) <= '1';		--Switch	8	-- x80 	Demo Sounds 1=On  0=Off
				mxd_out_reg (7) <= not Switch_2;		--Switch	8	-- x80 	Demo Sounds 1=On  0=Off
			end if;


-----------------------------------------------------------------------------------------------------------------------------------------------------------
---- Speech
-----------------------------------------------------------------------------------------------------------------------------------------------------------

-- Below works for YASUX but is wrong as I'm not sending data back read from the port
-- When I read the port I'm supposed to send data back when the SC01 or YASUX is ready
-- Don;t think that I can use both interfaces at the same time either as they're at different speeds

-- From David Turner Speech
-- ;*******************************************************************************
-- ; Get speech status
-- ;*******************************************************************************
-- GSPST	in	a,($12)			; Bit 7 is a 1 when chip is ready
	-- bit	7,a	
	-- jr	z,GSPST			; Loop if not ready
	-- ret

-- 12 4 Patent example, Don't understand!
-- 13 5
-- 14 6
-- 15 7
-- 16 8
-- 17 9

-- SC01
-- ACKREQ: 0 = Acknowledge receipt, 1 = Ready (see above!)
-- STROBE - Latching occurs on rising edge of Strobe signal
-- MC14539B must be BUFFA1/B=1 : BUFFA0/A=0 IORQ=0 to select ACKREQ
-- BUFFA0 and A1 are just buffered  A0 A1 from CPU same as I_MXA(0)&(1)

-- In real Gorf 4 Switch banks are selected based on BuffA0 and BuffA1 - 00 01 10 11 in to 4 x MC14539B Muxes
-- With speech Mame reads in xEF = 11101111
-- Routine to deal with having no MC14539B
--		if ACKREQ = '1' then --x"17" Speech -- In on port 17 ///// Test for x"0017" DOESN'T WORK !
	if (I_CPU_ENA = '1') then
			if (I_MXA(7 downto 0)) = x"17" then --x"17" Speech -- In on port 17 
				O_speech_trigger <= '1'; -- High speak
				O_speech_17 (7 downto 0) <= I_MXA(15 downto 8); -- 6 bits wide SC01 inputs from U24 74LS367  Tristate non inverting buffer (Speech is in 6 bits 13 downto 8 only !)

--												Schematic JR
				mxd_out_reg (0) <= '1';--			Z3	130    x1	X0 Line 106, always 1
				mxd_out_reg (1) <= '0';--			W3	131 -- x2	X1 Line 116, always 0
				mxd_out_reg (2) <= '0';--			Z3	132	-- x4 	X2 Line 126, always 0
				mxd_out_reg (3) <= '0';--			W3	133	-- x8 	X3 Line 136, Free Play 	1=Free play 0=Coin play 
				mxd_out_reg (4) <= '1';--			Z3	134	-- x10	Y0 Line 107, always 1
				mxd_out_reg (5) <= '0';--			W3	135	-- x20	Y1 Line 117, always 0
				mxd_out_reg (6) <= '1';--			Z3	136	-- x40 	Coin Play Free Play
				mxd_out_reg (7) <= '0';--			W3	137	-- x80 	Y3 Line 137, DIP 8, Demo Sounds during game over 0=On  1=Off, (forcing 0 on)

				else 
				O_speech_trigger <= '0'; -- Low Dont speak

			end if;
	end if;
-----------------------------------------------------------------------


			if (I_MXA(7 downto 0)) = x"1c" then -- 
					mxd_out_reg <= x"ff"; -- Pots
			end if;

			if (I_MXA(7 downto 0)) = x"1d" then -- 
					mxd_out_reg <= x"ff"; -- Pots
			end if;
			if (I_MXA(7 downto 0)) = x"1e" then -- 
					mxd_out_reg <= x"ff"; -- Pots
			end if;
			if (I_MXA(7 downto 0)) = x"1f" then -- 
					mxd_out_reg <= x"ff"; -- Pots
			end if;
      end if;


	end if; -- End ENA
	end process;




  p_decode_read          : process(I_MXA, I_IORQ_L, I_RD_L, io_read)
  begin
    -- we will return 0 for x18-1b
    io_read <= '0';
    switch_read <= '0';
    if (I_MXA(7 downto 4) = "0001") then -- = Reads everything below x1F
      if (I_IORQ_L = '0') and (I_RD_L = '0') then
--      if (I_IORQ_L = '0') and (I_RD_L = '0') and I_M1_L = '1' then
        io_read <= '1'; -- io read means read everything below 1f
--        if (I_MXA(3) = '0') then -- switch read specifically means read the keypad Below x17 read the keypad
---- 10111 = x17
--          switch_read <= '1';
        end if;

    end if;
  end process;



  --
  p_mxd_oe               : process(mxd_out_reg, io_read)
  begin
    O_MXD <= x"00";
    O_MXD_OE_L <= '1';
    if (io_read = '1') then -- io read means read everything below 1f Note pots are 1f - 1c 
-- O_MXD <= "00101100"; -- Forcing DIPSWITCH continuously WORKS !!
      O_MXD <= mxd_out_reg; -- 
      O_MXD_OE_L <= '0';
    end if;
  end process;
  


  -- p_pots                 : process
  -- begin
    -- wait until rising_edge(CLK);
    -- if (ENA = '1') then
      -- -- return FF when not plugged in
      -- r_pot(0) <= x"FF";
      -- r_pot(1) <= x"FF";
      -- r_pot(2) <= x"FF";
      -- r_pot(3) <= x"FF";
    -- end if;
  -- end process;
  -- read switches 10-17, pots 1c - 1f
  -- port 7  6  5  4  3  2  1  0
  -- x10           tg rt lt dn up | player 1
  -- x11           tg rt lt dn up | player 2
  -- x12           tg rt lt dn up | player 3
  -- x13           tg rt lt dn up | player 4
  -- x14        =  +  -  x  /  %  | keypad (right most col, bit 0 top)
  -- x15        .  3  6  9  ch v  | keypad
  -- x16        0  2  5  8  ms ^  | keypad
  -- x17        ce 1  4  7  mr c  | keypad (left most col)

  -- write
  -- x10 master osc
  -- x11 tone a freq
  -- x12 tone b freq
  -- x13 tone c freq
  -- x14 vibrato (7..2 value, 1..0 freq)
  -- x15 noise control, tone c volume
  --       bit 5 high to enable noise into mix
  --       bit 4 high for noise mod, low for vibrato
  --       bit 3..0 tone c vol
  -- x16 tone b volume, tone a volume (7..4 b vol, 3..0 a vol)
  -- x17 noise volume (vol 7..4), 7..0 for master osc modulation


	-- 2+4 or 6 bit up counter as per patent and mame = 7 bit counter = x3F or max 63
	six_bit_up_counter : process
	begin
    wait until rising_edge(CLK);
		if (ENA = '1') then
			if (I_CPU_ENA = '1') then
				counter_up <= counter_up + '1';
			end if;
		end if;

		if counter_up = "111111" then 
			counter <= '1';
			else 
			counter <= '0'; 
		end if;
	end process;




  -- p_noise_gen            : process
    -- variable poly17_zero : std_logic;
  -- begin
    -- -- most probably not correct polynomial
    -- wait until rising_edge(CLK);
    -- if (ENA = '1') then
      -- if (I_CPU_ENA = '1') then
        -- poly17_zero := '0';
        -- if (poly17 = "00000000000000000") then poly17_zero := '1'; end if;
        -- poly17 <= poly17(15 downto 0) & (poly17(16) xor poly17(2) xor poly17_zero);
      -- end if;
    -- end if;
  -- end process;
  -- noise_gen <= poly17(7 downto 0);

  p_noise_gen            : process
    variable poly15_zero : std_logic;
  begin
    -- Correct polynomial same as Mame 12/8/2019
    wait until rising_edge(CLK);
    if (ENA = '1') then
		if (I_CPU_ENA = '1') then
			if counter = '1' then 
				poly15_zero := '0';
				poly15_zero := not (poly15(14) xor poly15(13));
				poly15 <= (poly15(14 downto 0) & poly15_zero); -- MSBit is ignored and all bytes are concatenated and shifted left with updated LSBit
			end if;
		end if;
    end if;
  end process;
  noise_gen <= poly15(7 downto 0); -- 1496 Noise generator



  -- p_vibrato_osc          : process
  -- begin
    -- wait until rising_edge(CLK);
    -- if (ENA = '1') then
      -- -- cpu clock period 0.558730s us

      -- -- 00 toggle output every  18.5 mS bet its 32768 clocks
      -- -- 01 toggle output every  37   mS
      -- -- 10 toggle output every  74   mS
      -- -- 11 toggle output every 148   mS

      -- -- bit 15 every 32768 clocks
      -- if (I_CPU_ENA = '1') then
        -- vibrato_cnt <= vibrato_cnt + "1";
        -- vibrato_ena <= '0';
        -- case r_snd(4)(1 downto 0) is
          -- when "00" => vibrato_ena <= vibrato_cnt(15);
          -- when "01" => vibrato_ena <= vibrato_cnt(16);
          -- when "10" => vibrato_ena <= vibrato_cnt(17);
          -- when "11" => vibrato_ena <= vibrato_cnt(18);
          -- when others => null;
        -- end case;
      -- end if;
    -- end if;
  -- end process;

-- Nutting = The speed of modulation is set by the Vibrato Speed Register (upper 2 bits of output port $14): 00 for fastest and 11 for slowest.*/
  p_vibrato_osc          : process -- Vibrato Low Frequency Oscilator 1484
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      -- cpu clock period 0.558730s us

      -- 00 toggle output every  18.5 mS bet its 32768 clocks
      -- 01 toggle output every  37   mS
      -- 10 toggle output every  74   mS
      -- 11 toggle output every 148   mS

      -- bit 15 every 32768 clocks
      if (I_CPU_ENA = '1') then
        vibrato_cnt <= vibrato_cnt + "1";
        vibrato_ena <= '0';
        case r_snd(4)(1 downto 0) is -- 1482 VFReg - Low two bits connect here 1482 a & b
          when "00" => vibrato_ena <= vibrato_cnt(9); -- vibrato_ena here = astrocde 13-bit vibrato clock
          when "01" => vibrato_ena <= vibrato_cnt(10);
          when "10" => vibrato_ena <= vibrato_cnt(11);
          when "11" => vibrato_ena <= vibrato_cnt(12);
          when others => null;
        end case;
      end if;
    end if;
  end process;



  -- p_master_osc_freq          : process(vibrato_ena, r_snd, noise_gen)
    -- variable mux : std_logic_vector(7 downto 0);
  -- begin
    -- mux := (others => '0'); -- default
    -- if (r_snd(5)(4) = '1') then -- use noise
      -- mux := noise_gen and r_snd(7);
    -- else
      -- if (vibrato_ena = '1') then
-- --        mux := r_snd(4)(7 downto 2) & "00";
       -- mux := r_snd(4)(7 downto 0);
-- --        mux := r_snd(4)(7 downto 6) & r_snd(4)(5 downto 0);
      -- else
        -- mux := (others => '0');
      -- end if;
    -- end if;
    -- -- add modulation to master osc freq
    -- master_osc_freq <= r_snd(0) + mux;
    -- -- Arcadian mag claims that the counter is preset to the modulation value
    -- -- when the counter hits the master osc reg value.
    -- -- The patent / system descriptions describes an adder ....
  -- end process;

  p_master_osc_freq          : process(vibrato_ena, r_snd, noise_gen)
    variable mux : std_logic_vector(7 downto 0);
  begin
    mux := (others => '0'); -- default

-- If bit 4 of output port 15H (r_snd(5) is set to 1, the master oscillator
-- frequency will be modulated by noise. The amount of modulation will be
-- set by the 8-bit noise volume register (1492), output port 17H (r_snd(7)).

-- Mux = 1474
    if (r_snd(5)(4) = '1') then -- use noise \\ Bit 4 is the Multiplexer Register 1476 x15 snd_ld(5) \\ D4: Mux source (0=vibrato, 1=noise)
	-- 14/8/2019  Hadn't worked (noise) because as well as all of the other issues this is NEGATIVE logic ! i.e. A Not!
     mux := not (noise_gen and r_snd(7)); -- x17	r_snd(7) Noise Volume Register 1492 -- This line is equivalent to AND gate 1494


-- If bit 4 of output port $15 is set to 0, the frequency of the master oscillator will be modulated by a constant value to give a vibrato effect. 
-- The amount of modulation will be set by the vibrato depth register (the first 6 bits of output port $14, VIBRA). 
-- The speed of modulation is set by the vibrato speed register (upper 2 bits of output port $14): 00 for fastest and 11 for slowest.
	else
		if (vibrato_ena = '1') then -- 1486 Vibrato System
			mux := r_snd(4)(7 downto 2) & "00"; -- r_snd(4)(7 downto 2) = Vibrato Register 1488 \ Bits 0 &1 = Vibrato Frequency register 1482 \ These connect to Low Frequency Oscilator 1484 \ + "00" When r_snd(5)(4)=0
		end if;
         mux := (others => '0');
    end if;
    -- add modulation to master osc freq
	-- Nuttings says -- Frequency modulation is accomplished by adding a modulation value (This is mux) to the contents of port $10 (TONMO) 
	-- and sending the result to the master oscillator frequency generator.
    master_osc_freq <= r_snd(0) + mux; -- r_snd(0) 1472 Master Oscillator Register \ This is adder 1478
    -- Arcadian mag claims that the counter is preset to the modulation value
    -- when the counter hits the master osc reg value.
    -- The patent / system descriptions describes an adder ....
  end process;



  p_master_osc           : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (I_CPU_ENA = '1') then -- 1.789 Mhz base clock
        master_ena <= '0';
        if (master_cnt = "00000000") then
          master_cnt <= master_osc_freq;
          master_ena <= '1';
        else
          master_cnt <= master_cnt - "1";
        end if;
      end if;
    end if;
  end process;

  p_tone_gen             : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (I_CPU_ENA = '1') then -- 1.789 Mhz base clock

        for i in 0 to 2 loop
          if (master_ena = '1') then
            if (tone_gen(i) = "00000000") then
              tone_gen(i) <= r_snd(i + 1); -- load
              tone_gen_op(i) <= not tone_gen_op(i);
            else
              tone_gen(i) <= tone_gen(i) - '1';
            end if;
          end if;
        end loop;
      end if;
    end if;
  end process;

  p_op_mixer             : process
    variable vol : array_4x4;
    variable sum01 : std_logic_vector(4 downto 0);
    variable sum23 : std_logic_vector(4 downto 0);
    variable sum : std_logic_vector(5 downto 0);
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (I_CPU_ENA = '1') then
        vol(0) := "0000";
        vol(1) := "0000";
        vol(2) := "0000";
        vol(3) := "0000";

        if (tone_gen_op(0) = '1') then vol(0) := r_snd(6)(3 downto 0); end if; -- A
        if (tone_gen_op(1) = '1') then vol(1) := r_snd(6)(7 downto 4); end if; -- B
        if (tone_gen_op(2) = '1') then vol(2) := r_snd(5)(3 downto 0); end if; -- C
        -- if (r_snd(5)(4) = '1') then -- noise enable
          -- if (noise_gen(0) = '1') then vol(3) := r_snd(5)(7 downto 4); end if; -- noise
        -- end if;
        if (r_snd(5)(4) = '1') then -- noise enable
          vol(3) := r_snd(7)(7 downto 4); end if; -- noise \\ the noise volume is given by the upper 4 bits of port $17 (VOLN).  
        end if;

        sum01 := ('0' & vol(0)) + ('0' & vol(1));
        sum23 := ('0' & vol(2)) + ('0' & vol(3));
        sum := ('0' & sum01) + ('0' & sum23);

        if (I_RESET_L = '0') then
          O_AUDIO <= "00000000";
        else
          O_AUDIO <= (sum & "00");
        end if;
      end if;
--    end if;
  end process;

end architecture RTL;
