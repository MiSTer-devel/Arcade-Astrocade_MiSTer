--
-- A simulation model of Bally Astrocade hardware
--
-- Sparkle circuit for Arcade - Mike@the-coates.com

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;


entity BALLY_SPARKLE is
  port (
    I_MXA             : in   std_logic_vector(15 downto  0);
    I_MXD             : in   std_logic_vector( 7 downto  0);

    -- cpu control signals in
    I_M1_L            : in   std_logic;
    I_RD_L            : in   std_logic;
    I_IORQ_L          : in   std_logic;
    I_RESET_L         : in   std_logic;

	 -- Screen Info
	 I_HCOUNT          : in   std_logic_vector(8 downto 0);
	 I_VCOUNT          : in   std_logic_vector(10 downto 0);
	 I_CODE            : in   std_logic_vector(1 downto  0);
	 I_COLOUR          : in   std_logic_vector(7 downto  0);
	 
	 O_ACTIVE          : out  std_logic;

	 -- colour of new pixel
    O_VIDEO_R         : out   std_logic_vector(7 downto 0);
    O_VIDEO_G         : out   std_logic_vector(7 downto 0);
    O_VIDEO_B         : out   std_logic_vector(7 downto 0);
	 
	 -- Other ouputs from this port
	 O_SPEECH          : out  std_logic; -- Enable / Disable speech circuit
	 O_JLAMP           : out  std_logic; -- Joystick Lamp
	 
    -- clks
    I_CPU_ENA         : in   std_logic; -- cpu clock ena
    ENA               : in   std_logic;
    CLK               : in   std_logic
  );
end;

architecture RTL of BALLY_SPARKLE is

  type array_bool4            is array (0 to 3) of boolean;

  signal cs_r                 : std_logic;
  signal Sparkle_en           : array_bool4 := (others => true);
  --signal prng1 					: std_logic_vector(16 downto 0) := (others => '0');
  signal prng2 					: std_logic_vector(16 downto 0) := (others => '0');
  
  signal col_in               : std_logic_vector( 8 downto 0) := (others => '0');
  signal col_out              : std_logic_vector(23 downto 0) := (others => '0');
  
  signal StarCount            : std_logic_vector( 9 downto 0) := (others => '0');
  signal NextStar             : std_logic_vector( 8 downto 0) := (others => '0');
  signal Horizontal           : std_logic_vector( 8 downto 0) := (others => '0');
  signal Vertical   				: std_logic_vector(10 downto 0);
  
  -- Delays
  signal red,green,blue       : std_logic_vector( 7 downto 0) := (others => '0');
  signal sparkled					: std_logic;
  
begin

  CalcPositions : process(I_VCOUNT, I_HCOUNT)
  begin
		-- Sort out interlace independent counters
		if I_VCOUNT > 262 then
			Vertical <= I_VCOUNT - 263;
		else
			Vertical <= I_VCOUNT;
		end if;
		
		-- Visible screen pixels
		if I_HCOUNT > 91 then
			Horizontal <= I_HCOUNT - 92;
		else
			Horizontal <= (others => '1');
		end if;
  end process;
  
  p_chip_sel : process(I_CPU_ENA, I_MXA)
  begin
    cs_r <= '0';
    if (I_CPU_ENA = '1') then -- cpu access
      if (I_MXA(7 downto 0) = "00010101") then
        cs_r <= '1';
      end if;
    end if;
  end process;

  -- registers -- It's a read, but it isn't ...
  p_reg_read : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
		if (I_RESET_L = '0') then
		  Sparkle_en <= (others => true);
		end if;
		
		if ((I_RD_L = '0') and (I_IORQ_L = '0') and (I_M1_L = '1') and (cs_r = '1')) then
		  -- write to sparkle registers in high byte
        case I_MXA(11 downto 9) is
			 -- 000 and 001 are coin counters
          when "010" => Sparkle_en(0) <= (I_MXA(8)='0'); 
          when "011" => Sparkle_en(1) <= (I_MXA(8)='0'); 
          when "100" => Sparkle_en(2) <= (I_MXA(8)='0'); 
          when "101" => Sparkle_en(3) <= (I_MXA(8)='0'); 
			 -- Speech or Sound flag for Gorf
			 when "110" => O_SPEECH <= I_MXA(8);
			 -- Joystick Lamp
			 when "111" => O_JLAMP  <= I_MXA(8);
          when others => null;
        end case;
      end if;
    end if;
  end process;

  star_position : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
	 			
	   if Horizontal = 0 and Vertical = 44 then
			-- prng1     <= (others => '0');
			StarCount <= (others => '0');
		else
			-- Only increment for 352 pixels per line
			--if I_HCOUNT > 87 and I_HCOUNT < 440 then
			--	prng1 <= (prng1(12) xor (not(prng1(0)))) & prng1(16 downto 1);
			--end if;
			
			-- Star position table - if we reached this star, get the next one
			if Horizontal = NextStar and Horizontal /= "111111111" then
				StarCount <= StarCount + 1;
			end if;
		end if;
    end if;
  end process;

  brightness : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
			prng2 <= (prng2(12) xor (not(prng2(0)))) & prng2(16 downto 1);
    end if;
  end process;

	sparkle : process
	variable TotalLuma : std_logic_vector(8 downto 0);
	variable NewLuma : std_logic_vector(3 downto 0);
	begin
		wait until rising_edge(CLK);
		if ((I_CODE="00" and Sparkle_en(0)) or (I_CODE="01" and Sparkle_en(1)) or (I_CODE="10" and Sparkle_en(2)) or (I_CODE="11" and Sparkle_en(3))) then

			-- Pixel changed
			sparkled <= '1';

			-- Calculate NewLuma ((sparkleluma + 16) * (OriginalLuma * 2) / 32
			TotalLuma := ("1" & prng2(4) & prng2(12) & prng2(16) & prng2(8)) * (I_COLOUR(2 downto 0) & '0');
			NewLuma   := TotalLuma(8 downto 5);
		
			-- Stars if background colour
			if I_CODE="00" then
				-- Black out until we get to the next star on this row or if we are in border area
				if Horizontal /= NextStar or (Horizontal = "111111111") then
					NewLuma := "0000";
				end if;
				
--				if prng1(7 downto 0) /= "11111110" then
--					NewLuma := "0000";
--				end if;
			end if;
		else
			sparkled <= '0';
		end if;
		
		-- Do new colour lookup
		col_in <= I_COLOUR(7 downto 3) & NewLuma(3 downto 0);

		-- Output sparkled colour
		red   <= col_out(23 downto 16);
		green <= col_out(15 downto 8);
		blue  <= col_out( 7 downto 0);
		
		-- delay output signals by 1 cycle
		O_VIDEO_R <= red;
		O_VIDEO_G <= green;
		O_VIDEO_B <= blue;
		O_ACTIVE  <= sparkled;
			
	end process;

   n_col : entity work.BALLY_COL_PAL
   port map (
      ADDR        => col_in,
      DATA        => col_out
   );

   n_star : entity work.BALLY_STARPOS
   port map (
      ADDR        => StarCount,
      DATA        => NextStar
   );
	
end architecture RTL;

