library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity SeawolfSound is
port (
	cpu_addr  	: in  std_logic_vector(15 downto 0);
	cpu_data  	: in  std_logic_vector(7 downto 0);
	-- Sample Info
	s_enable  	: in  std_logic;
	s_addr    	: out std_logic_vector(23 downto 0);
	s_data    	: in  std_logic_vector(15 downto 0);
	s_read    	: out std_logic;
	-- Sounds
	audio_out_l : out std_logic_vector(15 downto 0);
	audio_out_r : out std_logic_vector(15 downto 0);
   -- cpu
   I_RESET_L 	: in    std_logic;
   I_M1_L    	: in    std_logic;
   I_RD_L    	: in    std_logic;
   I_IORQ_L  	: in    std_logic;
    -- clks
   I_CPU_ENA 	: in   std_logic; -- cpu clock ena
   ENA       	: in   std_logic; 
   CLK       	: in   std_logic  -- sys clock (14 Mhz)
);
end entity;

architecture RTL of SeawolfSound is

 signal wav_clk_cnt : std_logic_vector(8 downto 0) := (others=>'0'); -- 44kHz divider / sound# counter
 
 subtype snd_id_t is integer range 0 to 8;
 
 -- sound#
 signal snd_id : integer range 0 to 15;
 
 type snd_addr_t is array(snd_id_t) of std_logic_vector(23 downto 0);
 
 -- wave current addresses in sdram
 signal snd_addrs : snd_addr_t;  
 
 -- Loaded
 -- 0 - minehit.wav         1 44100 000000 04B3FE
 -- 1 - my-dive.wav         1 44100 04B400 05D1D0
 -- 2 - my-shiphit.wav      1 44100 05D1D2 0B33F0
 -- 3 - my-sonar.wav        1 44100 0B33F2 0C94B6
 -- 4 - my-torpedo.wav      1 44100 0C94B8 0F683A
 
 -- 0-8 channels to play - sonar,torpedo,ship,mine,dive,sonar,torpedo,ship,mine
 
 -- wave start addresses in sdram 
 constant snd_starts : snd_addr_t := (
		x"0B33F2",x"0C94B8",x"05D1D2",x"000000",x"04B400",x"0B33F2",x"0C94B8",x"05D1D2",x"000000");
		
 -- wave end addresses in sdram 
 constant snd_stops : snd_addr_t := (
		x"0C94B6",x"0F683A",x"0B33F0",x"04B3FE",x"05D1D0",x"0C94B6",x"0F683A",x"0B33F0",x"04B3FE");

 type snd_flag_t is array(snd_id_t) of std_logic;
 
 -- sound playing (once)
 signal snd_starteds : snd_flag_t := (
		'0','0','0','0','0','0','0','0','0');
 -- sound to be restarted
 signal snd_restarts : snd_flag_t := (
		'0','0','0','0','0','0','0','0','0');		
 
 -- sum all sound
 signal audio_r, audio_l, audio_sum_r, audio_sum_l : signed(31 downto 0);
 
 signal cs_w               : std_logic;
 signal port40             : std_logic_vector(7 downto 0);
 signal port41             : std_logic_vector(7 downto 0);
 signal p_port40           : std_logic_vector(7 downto 0);
 signal p_port41           : std_logic_vector(7 downto 0);

 begin

 --#0  - Port 41 bit 5 Sonar Left
 --#1  - Port 40 bit 0 Torpedo Left   
 --#2  - Port 40 bit 1 Ship Hit Left  
 --#3  - Port 40 bit 2 Mine Hit Left  
 --#4  - Port 41 bit 3 Dive both channels 
 --#5  - Port 41 bit 4 Sonar Right
 --#6  - Port 40 bit 3 Torpedo Right  
 --#7  - Port 40 bit 4 Ship Hit Right 
 --#8  - Port 40 bit 5 Mine Hit Right 

 -- Port 41 bits 0-2 volume dive for right channel (left = not bits 0-2)
 -- Port 41 bit  7   volume of everything (on / off)

   p_chip_sel : process(I_CPU_ENA, cpu_addr)
  begin
    cs_w <= '0';
    if (I_CPU_ENA = '1') then -- cpu access
      if (cpu_addr(7 downto 1) = "0100000") then
        cs_w <= '1';
      end if;
    end if;
  end process;

  -- scan sound# from 0-8
  snd_id <= to_integer(unsigned(wav_clk_cnt(8 downto 5)));
 
 process(clk,I_RESET_L)
  variable vol_l, vol_r : integer range 0 to 7;
  begin

	if rising_edge(clk) then

		-- Register Write
		if (I_RD_L = '1') and (I_IORQ_L = '0') and (I_M1_L = '1') and (cs_w = '1') then
		  case cpu_addr(0) is
			 when '0' => port40 <= cpu_data;
			 when '1' => port41 <= cpu_data;
			 when others => null;
		  end case;
		end if;

		if I_RESET_L='0' then
			wav_clk_cnt <= (others=>'0');
			snd_starteds <= (others=>'0');
		end if;

		if s_enable='1' then

		    -- One shot samples, play once when triggered
			 snd_starteds(0) <= snd_starteds(0) or (not(p_port41(5)) and port41(5)); -- left sonar
			 snd_starteds(1) <= snd_starteds(1) or (not(p_port40(0)) and port40(0)); -- left torpedo
			 snd_starteds(2) <= snd_starteds(2) or (not(p_port40(1)) and port40(1)); -- left ship hit
			 snd_starteds(3) <= snd_starteds(3) or (not(p_port40(2)) and port40(2)); -- left mine hit
 			 snd_starteds(5) <= snd_starteds(5) or (not(p_port41(4)) and port41(4)); -- right sonar
			 snd_starteds(6) <= snd_starteds(6) or (not(p_port40(3)) and port40(3)); -- right torpedo
			 snd_starteds(7) <= snd_starteds(7) or (not(p_port40(4)) and port40(4)); -- right ship hit
			 snd_starteds(8) <= snd_starteds(8) or (not(p_port40(5)) and port40(5)); -- right mine hit

			 -- This one loops while still set
 			 snd_starteds(4) <= snd_starteds(4) or (not(p_port41(3)) and port41(3)); -- dive

			 -- 44.1kHz base tempo / high bits for scanning sound#
			 if wav_clk_cnt = x"145" then  -- divide 14MHz by 324 => 44.055kHz
				 wav_clk_cnt <= (others=>'0');
				
				 -- latch final audio / reset sum
				 audio_r <= audio_sum_r;
				 audio_l <= audio_sum_l;
				 audio_sum_r <= (others => '0');
				 audio_sum_l <= (others => '0');
			 else
				 wav_clk_cnt <= wav_clk_cnt + 1;
			 end if;

			 -- clip audio
			if  audio_r(19 downto 2) > 32767 then
				audio_out_r <= x"7FFF";
			elsif	audio_r(19 downto 2) < -32768 then 
				audio_out_r <= x"8000";
			else
				audio_out_r <= std_logic_vector(audio_r(17 downto 2));
			end if;		
			
			if  audio_l(19 downto 2) > 32767 then
				audio_out_l <= x"7FFF";
			elsif	audio_l(19 downto 2) < -32768 then 
				audio_out_l <= x"8000";
			else
				audio_out_l <= std_logic_vector(audio_l(17 downto 2));
			end if;		
			
			-- sdram read trigger (and auto refresh period)
			if wav_clk_cnt(4 downto 0) = "00000" then s_read <= '1';end if;
			if wav_clk_cnt(4 downto 0) = "00010" then s_read <= '0';end if;			

			-- select only useful cycles (0-8)
			if snd_id <= 8 then 
			
				-- set sdram addr at begining of cycle
				if wav_clk_cnt(4 downto 0) = "00000" then
					s_addr <= snd_addrs(snd_id);			
				end if;
			
				-- sound# currently playing 
				if (snd_starteds(snd_id) = '1') then
				
					-- get sound# sample and update next sound# address
					-- (next / restart)
					if wav_clk_cnt(4 downto 0) = "01000" then
												
						vol_l := 0;
						vol_r := 0;
						
						-- Master volume shuts down everything
						if (Port41(7)='1') then
							if (snd_id < 4) then
								vol_l := 7; 
							else
								if (snd_id = 4) then
									vol_r := TO_INTEGER(unsigned(Port41(2 downto 0)));
									vol_l := 7 - vol_r;
								else
									vol_r := 7;
								end if;
							end if;
						end if;

						audio_sum_l <= audio_sum_l + (signed(s_data) * vol_l) / 7;
						audio_sum_r <= audio_sum_r + (signed(s_data) * vol_r) / 7;
						
						-- update next sound# address
						snd_addrs(snd_id) <= snd_addrs(snd_id) + 2;	
					end if;
					
					-- (stop / loop)
					if snd_addrs(snd_id) >= snd_stops(snd_id) then 
						if (snd_id = 4) and (Port41(3) = '1') then
							-- Loop if still active
							snd_addrs(snd_id) <= snd_starts(snd_id);
						else
							snd_starteds(snd_id) <= '0';
						end if;
					end if;
					
				else
					-- sound# stopped set begin address
					snd_addrs(snd_id) <= snd_starts(snd_id);
				end if;
			
			end if;
			
			-- Save to check for changed bits
			p_port40 <= port40;
			p_port41 <= port41;

		else
			 -- Silence
		    audio_out_l <= (others => '0');
			 audio_out_r <= (others => '0');
		end if;
	end if;
 end process;

end architecture;

