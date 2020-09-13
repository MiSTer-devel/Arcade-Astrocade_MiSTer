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
-- version 001 initial release
-- version 003 spartan3e release
-- version 004 MiSTer tidy up, allow multiple instances - Macro
-- version 005 Sound hardware better matches original - Reggs 
-- version 006 (13/Sept/20) Sound Fixes to Master Oscillator preset, Tremolo, Mux and Adder - Reggs 

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

entity BALLY_IO is
  port (
	I_BASE            : in    std_logic_vector( 3 downto  0); -- Base address of chip (High nibble)
  
    I_MXA             : in    std_logic_vector(15 downto  0);
    I_MXD             : in    std_logic_vector( 7 downto  0);
    O_MXD             : out   std_logic_vector( 7 downto  0);
    O_MXD_OE_L        : out   std_logic;

    -- cpu control signals
    I_M1_L            : in    std_logic; -- not on real chip
    I_RD_L            : in    std_logic;
    I_IORQ_L          : in    std_logic;
    I_RESET_L         : in    std_logic;

    -- POTS
    O_POT_SEL         : out   std_logic_vector( 3 downto 0);
    I_POT_DATA        : in    std_logic_vector( 7 downto 0);

    -- switches
    O_SWITCH          : out   std_logic_vector( 7 downto 0);
    I_SWITCH          : in    std_logic_vector( 7 downto 0);
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

  -- Sound chip
  signal cs                   : std_logic;
  signal snd_ld               : array_bool8;
  signal r_snd                : array_8x8 := (x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00");

  --signal r_pot                : array_4x8 := (x"00",x"00",x"00",x"00");
  signal mxd_out_reg          : std_logic_vector(7 downto 0);

  signal io_read              : std_logic;
  signal switch_read          : std_logic;
  signal pot_read             : std_logic;

  -- audio
  signal poly15               : std_logic_vector(14 downto 0):= "000000000000000"; --(1558 Noise Generator)
  signal counter_up 		  : std_logic_vector(5 downto 0) := "000000";
  signal counter	 		  : std_logic := '0';

  signal noise_gen            : std_logic_vector(7 downto 0);
  signal master_ena           : std_logic;
  signal master_cnt           : std_logic_vector(7 downto 0);
  signal master_freq          : std_logic_vector(7 downto 0);
  signal vibrato_cnt          : std_logic_vector(12 downto 0); -- 13 Bit counter (1556)
  signal vibrato_ena          : std_logic;

  signal tone_gen             : array_3x8 := (others => (others => '0'));
  signal tone_gen_op          : std_logic_vector(2 downto 0);
 
begin

  p_chip_sel             : process(I_CPU_ENA, I_MXA, I_BASE)
  begin
    cs <= '0';
    if (I_CPU_ENA = '1') then -- cpu access
		if (I_MXA(7 downto 4) = I_BASE) then -- $1x		
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
	-- Required for WOW audio
    snd_ld <= (others => false);
    if (I_CPU_ENA = '1') then
      if (I_RD_L = '1') and (I_IORQ_L = '0') and (I_M1_L = '1') and (cs = '1') then
        snd_ld(0) <= ( I_MXA( 3 downto 0) = x"0") or 
                     ((I_MXA(10 downto 8) = "000") and (I_MXA(3 downto 0) = x"8"));

        snd_ld(1) <= ( I_MXA( 3 downto 0) = x"1") or
                     ((I_MXA(10 downto 8) = "001") and (I_MXA(3 downto 0) = x"8"));

        snd_ld(2) <= ( I_MXA( 3 downto 0) = x"2") or
                     ((I_MXA(10 downto 8) = "010") and (I_MXA(3 downto 0) = x"8"));

        snd_ld(3) <= ( I_MXA( 3 downto 0) = x"3") or
                     ((I_MXA(10 downto 8) = "011") and (I_MXA(3 downto 0) = x"8"));

        snd_ld(4) <= ( I_MXA( 3 downto 0) = x"4") or
                     ((I_MXA(10 downto 8) = "100") and (I_MXA(3 downto 0) = x"8"));

        snd_ld(5) <= ( I_MXA( 3 downto 0) = x"5") or
					 ((I_MXA(10 downto 8) = "101") and (I_MXA(3 downto 0) = x"8"));

        snd_ld(6) <= ( I_MXA( 3 downto 0) = x"6") or
                     ((I_MXA(10 downto 8) = "110") and (I_MXA(3 downto 0) = x"8"));

        snd_ld(7) <= ( I_MXA( 3 downto 0) = x"7") or
                     ((I_MXA(10 downto 8) = "111") and (I_MXA(3 downto 0) = x"8"));

      end if;
	
    end if;
  end process;

  p_reg_write_blk        : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (I_RESET_L = '0') then -- Reset the sound 
        r_snd 	 <= (others => (others => '0'));
        r_snd(0) <= x"47"; -- D71 As per Chuck Thomka 'The Sound Synthesizer"
      else
        for i in 0 to 7 loop
          if snd_ld(i) then r_snd(i) <= I_MXD; end if;
        end loop;
      end if;
    end if;
  end process;

  p_reg_read             : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (I_MXA(3) = '0') then
        mxd_out_reg <= I_SWITCH(7 downto 0);
      else
        mxd_out_reg <= x"00";
        case I_MXA(2 downto 0) is
          when "100" => mxd_out_reg <= I_POT_DATA(7 downto 0); --x1C
          when "101" => mxd_out_reg <= I_POT_DATA(7 downto 0); --x1D
          when "110" => mxd_out_reg <= I_POT_DATA(7 downto 0); --x1E
          when "111" => mxd_out_reg <= I_POT_DATA(7 downto 0); --x1F
          when others => null;
        end case;
      end if;
    end if;
  end process;

  p_decode_read          : process(I_MXA, I_IORQ_L, I_RD_L)
  begin

    -- we will return 0 for x18-1b
    io_read <= '0';
    switch_read <= '0';
    pot_read <= '0';
    if (I_MXA(7 downto 4) = "0001") then
      if (I_IORQ_L = '0') and (I_RD_L = '0') then
        io_read <= '1';
        if (I_MXA(3) = '0') then
          switch_read <= '1';
        end if;
        if (I_MXA(3 downto 2) = "11") then
          pot_read <= '1';
        end if;
      end if;
    end if;
  end process;

  p_switch_out           : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      O_SWITCH <= x"00";
      if (switch_read = '1') then
        case I_MXA(2 downto 0) is
          when "000" => O_SWITCH <= "00000001";
          when "001" => O_SWITCH <= "00000010";
          when "010" => O_SWITCH <= "00000100";
          when "011" => O_SWITCH <= "00001000";
          when "100" => O_SWITCH <= "00010000";
          when "101" => O_SWITCH <= "00100000";
          when "110" => O_SWITCH <= "01000000";
          when "111" => O_SWITCH <= "10000000";
          when others => null;
        end case;
        O_POT_SEL <= "0000";
      end if;
      if (pot_read = '1') then
        case I_MXA(3 downto 0) is
          when "1100" => O_POT_SEL <= "0001"; --x1C
          when "1101" => O_POT_SEL <= "0010"; --x1D
          when "1110" => O_POT_SEL <= "0100"; --x1E
          when "1111" => O_POT_SEL <= "1000"; --x1F
          when others => null;
        end case;
      end if;
    end if;
  end process;

  p_mxd_oe               : process(mxd_out_reg, io_read)
  begin
    O_MXD <= x"00";
    O_MXD_OE_L <= '1';
    if (io_read = '1') then
      O_MXD <= mxd_out_reg;
      O_MXD_OE_L <= '0';
    end if;
  end process;
  --

-- no longer used with proper pot hookup
  -- p_pots                 : process
  -- begin
  --   wait until rising_edge(CLK);
  --   if (ENA = '1') then
  --     -- return FF when not plugged in
  --     r_pot(0) <= x"FF";
  --     r_pot(1) <= x"FF";
  --     r_pot(2) <= x"FF";
  --     r_pot(3) <= x"FF";
  --   end if;
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

-- Better Bally Book - Reggs
               -- 7    6    5    4    3    2    1    0
-- $10  TONMO   [ f ][ f ][ f ][ f ][ f ][ f ][ f ][ f ]   f = Master oscillator frequency
-- $11  TONEA   [ f ][ f ][ f ][ f ][ f ][ f ][ f ][ f ]   f = Tone A frequency
-- $12  TONEB   [ f ][ f ][ f ][ f ][ f ][ f ][ f ][ f ]   f = Tone B frequency
-- $13  TONEC   [ f ][ f ][ f ][ f ][ f ][ f ][ f ][ f ]   f = Tone C frequency
-- $14  VIBRA   [ s ][ s ][ v ][ v ][ v ][ v ][ v ][ v ]   s = Vibrato speed (1482), v = Vibrato depth (1488)
-- $15  VOLC    [ u ][ u ][ n ][ t ][ c ][ c ][ c ][ c ]   u = unused, n = noise switch, t = Tremolo (1476 Mutiplexor Reg) Vibrato(0) Noise(1), c = Tone C
-- $16  VOLAB   [ b ][ b ][ b ][ b ][ a ][ a ][ a ][ a ]   b = Tone B volume, a = Tone A volume
-- $17  VOLN    [ N ][ N ][ N ][ N ][ n ][ n ][ n ][ n ]   N = Noise volume register, 4 MSB's noise Vol \ All 8 Bits Tremolo preset


 -- 2+4, 6 bit up counter as per patent and Mame = 7 bit counter = x3F or max 63
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


-- The noise generator comprises a number generator and is indicated generally at 1496. The number generator comprises a 15-bit shift register 1558 and an exclusive-OR gate indicated at 1560. The inputs of the NOR gates 1494 are connected to the outputs of the 8 most significant bits of the shift register 1558. The output of the two most significant bits are connected to the inputs of the exclusive-OR gate 1560 whose output is connected to the input of the least significant bit of the shift register 1558. The output of the 8 most significant bits of the shift register 1558 is a binary number that constantly changes with each clock signal to the shift register 1558. 

  p_noise_gen            : process -- 15 bit shift register (1558)
    variable poly15_zero : std_logic;
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
		if (I_CPU_ENA = '1') then
			poly15_zero := '0';
			if counter = '1' then 
				poly15_zero := not (poly15(14) xor poly15(13));
				poly15 <= (poly15(13 downto 0) & poly15_zero); 
			end if;
		end if;
    end if;
  end process;
  noise_gen <= poly15(14 downto 7); -- Noise Generator (1496) Connected to 8 MSB's of shift register 1558
														   

-- The speed of modulation is set by the Vibrato Speed Register (upper 2 bits of output port $14): 00 for fastest and 11 for slowest. The inputs of the transistor switches 1554 are connected to the 4 most significant bits 1556a-d of a counter comprising 13 bits 1556a-m. The output of the 2 bits 1482 (7 & 6) are connected to the inputs of the Vibrato Low Frequency Oscilator (1484)

   p_vibrato_osc          : process -- Vibrato Low Frequency Oscilator (1484)
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      -- cpu clock period 0.558730s us

      -- 00 toggle output every  18.5 mS bet its 32768 clocks
      -- 01 toggle output every  37   mS
      -- 10 toggle output every  74   mS
      -- 11 toggle output every 148   mS
      if (I_CPU_ENA = '1') then
        vibrato_cnt <= vibrato_cnt + "1"; -- Astrocade 13-bit Vibrato Clock
        vibrato_ena <= '0';

-- x14 Frequency (Bits 7 & 6 (1482) \ 5..0 Vibrato Depth (1488) 
        case r_snd(4)(7 downto 6) is -- Vibrato Frequency Reg (2 bit 1482)
          when "00" => vibrato_ena <= vibrato_cnt(9); 
          when "01" => vibrato_ena <= vibrato_cnt(10);
          when "10" => vibrato_ena <= vibrato_cnt(11);
          when "11" => vibrato_ena <= vibrato_cnt(12);
          when others => null;
        end case;
      end if;
    end if;
  end process;

 p_master_osc_freq          : process(vibrato_ena, r_snd, noise_gen, master_freq)
    variable mux : std_logic_vector(7 downto 0); 	
  begin
	master_freq <= (others => '0'); 
	mux := (others => '0'); -- default, Mux (1474)
	if (r_snd(5)(4) = '1') then -- use noise \\ Bit 4 is the Multiplexer Register (1476) \\ (0=vibrato, 1=noise)
		mux (7 downto 0) := noise_gen and r_snd(7); -- All 8 bits = Tremolo preset. (Also 4 MSB's = Noise Volume)
		master_freq <=  mux;  
	else 
		if (vibrato_ena = '1') then -- From Vibrato Frequency Reg (1482)
			mux := "00" & r_snd(4)(5 downto 0); -- Ground upper 2 bits and send Vibrato Depth, 5 LSB's (1488)
			master_freq <= mux; -- Ensure Master Oscillator will not count to r_snd(0)
		end if;
	end if;
 end process;

 p_master_osc           : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      if (I_CPU_ENA = '1') then -- 1.789 Mhz base clock
        master_ena <= '0';
        if (master_cnt = r_snd(0)) then -- Preset Master Oscillator Frequency (TONMO)
          master_cnt <= master_freq;
          master_ena <= '1';
        else
          master_cnt <= master_cnt + "1";
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

-- Patent -- The output of the most significant bit of the shift register 1558 of the noise generator 1496 (poly15(14)) is connected to the input of a NOR gate 1598 whose output is connected by an inverter 1600 to a PLA 1602. The other input of the NOR gate 1598 is connected to the noise modulation register 1536 which is the most significant bit of the output register having address 15H and register select line 1412. The PLA 1602 has inputs connected to the output of the 4 most significant bits of the noise volume register [17H] and the output of the PLA 1602 is also connected to the resistor network 1586. The set of "AND" gates 1530 comprise the plurality of pull-down transistors 1604 of the PLA 1602 with the digital-analog converter 1538 comprising the remainder of the PLA 1602 and resistor network 1586 in a manner similar to the tone generators. The resistor network 1586 has a common summing point 1540 which is connected to the output line 1588 which carries the analog signal AUDIO. In this manner, the AUDIO signal is the sum of the tones A, B and C, generated by the tone generators A, B and C (at their respective volumes), and the noise generator (at its respective volume). 

  p_op_mixer_l           : process
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

-- A 4th tone generator comprises a set of gates indicated at 1530 which functions as 4 AND gates which each have an input operatively connected to a line 1532 which carries a bit from the noise generator 1496 (FIG. 71B). The output of this bit of the noise generator 1496 is a square wave having a constantly varying frequency. The input 1532 is ANDed with 4 volume bits on lines 1534 from the noise volume register 1492 (FIG. 71B). The set of AND gates 1530 operate the same way as the AND gates for the tones A-C, except that a noise modulation register 1536 (having address 15H which activates register select line 1412) must contain a logical 1 for the outputs of the AND gate 1530 to oscillate.

        if (r_snd(5)(5) = '1') then -- Set noise volume if enabled
			vol(3) := (noise_gen(7 downto 7) and r_snd(7)(7 downto 4)); -- 4 MSB's volume bits And'd with Poly15 MSB 
		else 
			vol(3) := (others => '0');  
        end if;
	
        sum01 := ('0' & vol(0)) + ('0' & vol(1));
        sum23 := ('0' & vol(2)) + ('0' & vol(3));
        sum   := ('0' & sum01)  + ('0' & sum23);

        if (I_RESET_L = '0') then
          O_AUDIO <= "00000000";
        else
          O_AUDIO <= (sum & "00");
        end if;
      end if;
   end if;
  end process;
 
end architecture RTL;

