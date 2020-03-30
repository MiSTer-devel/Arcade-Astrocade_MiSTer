--
-- A simulation model of Bally Astrocade hardware
--
-- Pattern board for Arcade - Mike@the-coates.com
--
-- Revision list
--
-- version 001 initial release
--
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;


entity BALLY_PATTERN is
  port (
    I_MXA             : in    std_logic_vector(15 downto  0);
    I_MXD             : in    std_logic_vector( 7 downto  0);

	 O_MXA				 : out   std_logic_vector(15 downto  0);
    O_MXD             : out   std_logic_vector( 7 downto  0);
	 
	 -- CPU control signals out
	 O_RD_L			    : out   std_logic;
	 O_WR_L			    : out   std_logic;
	 O_MR_L            : out   std_logic;
	 O_BUSRQ_L         : out   std_logic;
	 
    -- cpu control signals in
    I_M1_L            : in    std_logic;
    I_RD_L            : in    std_logic;
    I_MREQ_L          : in    std_logic;
    I_IORQ_L          : in    std_logic;
    I_RESET_L         : in    std_logic;
	 I_WAIT_L          : in    std_logic;
	 I_BUSACK_L        : in    std_logic; 

    -- clks
    I_CPU_ENA         : in   std_logic; -- cpu clock ena
    ENA               : in   std_logic;
    CLK               : in   std_logic;
	 
	 -- Debug info
	 I_FIRE            : in   std_logic;
	 I_DELAY           : in   std_logic_vector(2 downto 0);
	 O_STATE           : out  std_logic_vector(3 downto 0)
  );
end;

architecture RTL of BALLY_PATTERN is

  --  Signals
  
  TYPE P_State_type IS (Suspended, Start, Source, Source_wait, Source_read, Destination, Destination_wait, Increment, Increment_Wait, Repeat, Complete);  -- Define the states
  SIGNAL P_State              : P_State_type := Suspended;
  signal next_state           : P_State_type := Suspended;
	
  -- Pattern Registers	
  signal p_source             : std_logic_vector(15 downto 0); 
  signal p_dest               : std_logic_vector(15 downto 0); 
  signal p_mode               : std_logic_vector(5 downto 0); 
  signal p_skip               : std_logic_vector(7 downto 0); 
  signal p_width              : std_logic_vector(7 downto 0); 
  signal p_height             : std_logic_vector(7 downto 0); 
  -- Pattern work 
  signal p_addr               : std_logic_vector(15 downto 0); 
  signal p_data               : std_logic_vector(7 downto 0); 
  signal u13ff                : std_logic;
  signal curwidth             : std_logic_vector(7 downto 0); 
  signal p_temp					: std_logic_vector(8 downto 0);
  signal c_source             : std_logic_vector(15 downto 0); 
  signal c_dest               : std_logic_vector(15 downto 0); 
  signal c_height             : std_logic_vector(7 downto 0); 
  signal d_count              : std_logic_vector(2 downto 0); 
  -- Pattern CPU equivalent
  signal p_RD					   : std_logic := '1';
  signal p_WR					   : std_logic := '1';
  signal p_MR                 : std_logic := '1';
  
  signal cs_w                 : std_logic;
  signal cs_go                : std_logic;
  
begin

  p_chip_sel : process(I_CPU_ENA, I_MXA)
  begin
    cs_w <= '0';
    if (I_CPU_ENA = '1') then -- cpu access
      if (I_MXA(7 downto 3) = "01111") then
        cs_w <= '1';
      end if;
    end if;
  end process;

  --
  -- registers
  --
  pattern_board : process (CLK) 
  begin
		if rising_edge(CLK) then

			-- Register Write
			if (I_RD_L = '1') and (I_IORQ_L = '0') and (I_M1_L = '1') and (cs_w = '1') and (P_State = Suspended) then
			  case I_MXA(7 downto 0) is
				 -- Pattern board (0x78 - 0x7E) 
				 when "01111000" => p_source(7 downto 0)  <= I_MXD(7 downto 0);
				 when "01111001" => p_source(15 downto 8) <= I_MXD(7 downto 0);
				 when "01111010" => p_mode(5 downto 0)    <= I_MXD(5 downto 0);
								  	     p_dest(7 downto 0)    <= "00000000";
				 when "01111011" => p_skip(7 downto 0)    <= I_MXD(7 downto 0);
				 when "01111100" => -- It apparently adds p-skip to p_dest low, but since this write occurs multiple times it causes big problems!
				                    -- since p_dest seems to always be 0 (set by write to p_mode) then we just take p_skip!
									     --p_dest(8 downto 0)    <= ('0' & p_dest(7 downto 0)) + ('0' & p_skip(7 downto 0));
									     p_dest(7 downto 0)    <= p_skip(7 downto 0);
									     p_dest(15 downto 8)   <= I_MXD(7 downto 0);
				 when "01111101" => p_width(7 downto 0)   <= I_MXD(7 downto 0);
				 when "01111110" => p_height(7 downto 0)  <= I_MXD(7 downto 0);
											-- Initialise everything for copy
										  if (p_mode(1) = '0') then
												u13ff <= '1';
										  else
										  	   u13ff <= '0';
										  end if;
										  curwidth <= p_width;
										  c_source <= p_source;
										  c_dest <= p_dest;
										  c_height <= I_MXD(7 downto 0); -- p_height not ready yet!
										  -- And get ready to start copy loop
										  next_state <= Start;
				 when others => null;
			  end case;
			end if;

			-- Main loop where the copy happens
			
			if (I_CPU_ENA = '1') then

				case p_State is
					
					when Start =>
							-- Wait until CPU responds
					      if I_BUSACK_L = '0' then
								next_state <= Source;
							end if;
							
					when Source => 
							-- address is selected between source/dest based on mode.d0
							if (p_mode(0) = '0') then
								p_addr <= c_source;
							else
								p_addr <= c_dest;
							end if;
							p_WR <= '1';
							p_MR <= '0'; 
							p_RD <= '0'; -- Read
							-- d_count <= I_DELAY;
							next_state <= Source_read; --Source_wait;

--					when Source_wait =>
							-- Delay between set address and data return
--							if (I_WAIT_L='1') then
--								if (d_count = "000") then
--									next_state <= Source_read;
--								else
--									d_count <= d_count - 1;
--								end if;
--							end if;

					when Source_read =>
							if (I_WAIT_L='1') then
								-- if mode.d3 is set, then the last byte fetched per row is forced to 0 (address = gorf hack for the moment)
								if ((curwidth = "00000000") and (p_mode(3) = '1')) then -- or (p_addr = x"D12B")) then
									p_data <= "00000000";
								else
									p_data <= I_MXD(7 downto 0);
								end if;
								
								p_RD <= '1';
								p_MR <= '1';
								p_WR <= '1';

								next_state <= Destination;
							end if;
						
					when Destination => 
							-- Set destination address
							if (I_WAIT_L='1') then
								if (p_mode(0) = '1') then
									p_addr <= c_source;
								else
									p_addr <= c_dest; 
								end if;
								p_WR <= '0';
								next_state <= Destination_wait;
							end if;

					when Destination_wait =>
							-- Debug - single step!	
							--if ((c_source /= x"0776") or (I_FIRE = '1')) then
								p_MR <= '0'; -- set it low
								-- Calculate this now in case needed in increment routine
								p_temp(8 downto 0) <= std_logic_vector(unsigned('0' & c_dest(7 downto 0)) + unsigned('0' & p_skip(7 downto 0)));
								next_state <= Increment;
							--end if;

					when Increment => 
							-- if the flip-flop at U13 is high and mode.d2 is 1 we can increment source
							-- however, if mode.d3 is set and we're on the last byte of a row, the increment is suppressed
							if ((u13ff='1') and (p_mode(2)='1')) then
								if ((curwidth /= "00000000") or (p_mode(3)='0')) then
									c_source <= c_source + 1;
								end if;
							end if;
							
							-- if mode.d1 is 1, toggle the flip-flop; otherwise leave it preset 
							if (p_mode(1)='1') then
								u13ff <= not u13ff;
							end if;
							
							-- destination increment is suppressed for the last byte in a row 
							if (curwidth = "00000000") then
								-- at the end of each row, the skip value is added to the dest value 
								-- p_temp(8 downto 0) <= std_logic_vector(unsigned('0' & c_dest(7 downto 0)) + unsigned('0' & p_skip(7 downto 0)));
								c_dest(7 downto 0) <= p_temp(7 downto 0);
								-- carry behavior into the top byte is controlled by mode.d4 
								if p_mode(4)='0' then
									if (p_temp(8)='1') then
										c_dest(15 downto 8) <= c_dest(15 downto 8) + 1;
									end if;
								else
									if (p_temp(8)='0') then
										c_dest(15 downto 8) <= c_dest(15 downto 8) - 1;
									end if;
								end if;
							else
								-- if mode.d5 is 1, we increment 
								if p_mode(5)='1' then
									c_dest <= c_dest + 1;
								else
									c_dest <= c_dest - 1;
								end if;
							end if;
							
							next_state <= Increment_Wait;

						-- Delay between write address and next byte copy
						when Increment_Wait =>
							if (I_WAIT_L='1') then
								next_state <= Repeat;
							end if;

						when Repeat => 
							-- Debug - single step!	
							--if ((c_source /= x"0776") or (I_FIRE = '0')) then
								if ((c_height="00000000") and (curwidth="00000000")) then 
										-- Finished!
										p_RD <= '1';
										p_WR <= '1';
										p_MR <= '1';
										-- Clear pattern address and data
										p_data <= "00000000";
										p_addr <= "0000000000000000";
										next_state <= Complete;
								else
									if (curwidth /= "00000000") then
										curwidth <= curwidth - 1;
									else
										if (c_height /= "00000000") then 
											curwidth <= p_width;
											c_height <= c_height - 1;
										end if;
									end if;

									next_state <= Source;
								end if;
								
							--end if;
							
						when Complete =>
							-- Wait until CPU restarts
					      if I_BUSACK_L = '1' then
								next_state <= Suspended;
							end if;

						when others => null;
					
					end case;

			end if; 

			if (I_RESET_L = '0') then
			  p_State <= Suspended;
			else
			  p_State <= next_state;
			end if;      
		
		   -- show current state (debug)
			case p_State is
			
				when Suspended => O_STATE <= "0000";
				when Source => O_STATE <= "0001";
				when Source_wait => O_STATE <= "0010";
				when Source_read => O_STATE <= "0011";
				when Destination => O_STATE <= "0100";
				when Destination_wait => O_STATE <= "0101";
				when Increment => O_STATE <= "0110";
				when Increment_Wait => O_STATE <= "0111";
				when Repeat => O_STATE <= "1000";
				when Complete => O_STATE <= "1001";
				when others => O_STATE <= "1111";
			
			end case;
			
	end if; -- rising edge CLK
  
end process;

	-- Our interface with the outside world
  O_MXA <= p_addr;
  O_MXD <= p_data;
  O_RD_L <= p_RD;
  O_WR_L <= p_WR;
  O_MR_L <= p_MR;

  -- Run Z80 normally until Pattern board is active
  O_BUSRQ_L <= '1' when (P_State = Suspended or P_State = Complete) else '0';
  
end architecture RTL;

