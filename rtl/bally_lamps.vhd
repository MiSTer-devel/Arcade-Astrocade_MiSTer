--
-- A simulation model of Bally Astrocade hardware
--
-- Lamp circuit for Arcade - Mike@the-coates.com
--
-- Revision list
--
-- version 001 initial release
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;


entity BALLY_LAMPS is
  port (
    I_MXA             : in   std_logic_vector(15 downto  0);
    I_MXD             : in   std_logic_vector( 7 downto  0);

    -- cpu control signals in
    I_M1_L            : in   std_logic;
    I_RD_L            : in   std_logic;
    I_IORQ_L          : in   std_logic;
    I_RESET_L         : in   std_logic;

	 -- Lamp info bitmap
	 O_LAMP            : out  std_logic_vector( 5 downto  0);
	 
    -- clks
    I_CPU_ENA         : in   std_logic; -- cpu clock ena
    ENA               : in   std_logic;
    CLK               : in   std_logic
  );
end;

architecture RTL of BALLY_LAMPS is

  signal cs_r                 : std_logic;
  
begin
  
  p_chip_sel : process(I_CPU_ENA, I_MXA)
  begin
    cs_r <= '0';
    if (I_CPU_ENA = '1') then -- cpu access
      if (I_MXA(7 downto 0) = "00010110") then -- $16
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
			O_LAMP <= (others => '0');
		end if;
		
		if ((I_RD_L = '0') and (I_IORQ_L = '0') and (I_M1_L = '1') and (cs_r = '1')) then
		  -- write to lamp registers in high byte 
			case I_MXA(11 downto 9) is
				 when "000" => O_LAMP(0) <= I_MXA(8);
				 when "001" => O_LAMP(1) <= I_MXA(8);
				 when "010" => O_LAMP(2) <= I_MXA(8);
				 when "011" => O_LAMP(3) <= I_MXA(8);
				 when "100" => O_LAMP(4) <= I_MXA(8);
				 when "101" => O_LAMP(5) <= I_MXA(8);
				 when others => null;
			end case;
      end if;
    end if;
  end process;
  
end architecture RTL;

