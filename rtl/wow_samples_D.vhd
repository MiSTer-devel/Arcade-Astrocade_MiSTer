library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity WoWSound_DDRAM is
port (
	-- Sample data
	s_enable  	: in  std_logic;						-- 1 when playing this game (mod-wow)
	s_addr    	: out std_logic_vector(23 downto 0);
	s_data    	: in  std_logic_vector(15 downto 0);
	s_read    	: out std_logic;
	s_ready     : in  std_logic;
	-- Sounds out
	audio_out_l : out std_logic_vector(15 downto 0);
	audio_out_r : out std_logic_vector(15 downto 0);
	votrax      : out std_logic;     
   -- cpu
	I_MXA    	: in  std_logic_vector(15 downto 0);
	I_RESET_L 	: in  std_logic;
	I_M1_L    	: in  std_logic;
	I_RD_L    	: in  std_logic;
	I_IORQ_L  	: in  std_logic;
	I_HL        : in  std_logic_vector(15 downto 0);
    -- clks
	I_CPU_ENA 	: in  std_logic; -- cpu clock ena
	ENA       	: in  std_logic; 
	CLK       	: in  std_logic  -- sys clock (14 Mhz)
);
end entity;

-- WOW simulation of Votrax speech chip
--
-- Sept2020 All samples extracted and re-recorded from real Votrax SC01 - Reggs
-- First sentence @ $8B6C \ Wow Pointer Table = $9477 to $95fA

architecture RTL of WoWSound_DDRAM is

 signal wav_clk_cnt : std_logic_vector(8 downto 0) := (others=>'0'); -- 44kHz divider / sound# counter
 
 subtype snd_id_t is integer range 0 to 77;
 
 -- sound#
 signal snd_id   : integer range 0 to 15;				-- for Time Slice
 signal snd_play : snd_id_t := 77; 						-- current wav playing
 signal audio    : std_logic_vector(15 downto 0) register := (others=>'0');

 signal wave_read_ct   : std_logic_vector(2 downto 0)  register := (others=>'0'); 
 signal wave_data      : std_logic_vector(15 downto 0) register := (others=>'0');
 
 type snd_addr_t is array(snd_id_t) of std_logic_vector(23 downto 0);

-- 00 - 00-pause.wav        1 11025 000000 00014C
-- 01 - 01-8b6c Worlock.wav 1 11025 000150 005407
-- 02 - 02-8b70 for double s1 11025 005408 00DE55
-- 03 - 03-8b84 If you get t1 11025 00DE58 02B9FD
-- 04 - 04-8bb6 you are in.w1 11025 02BA00 031479
-- 05 - 05-8BC1 the dungeons1 11025 03147C 03DCD3
-- 06 - 06-8bd6 i am.wav    1 11025 03DCD4 043DC3
-- 07 - 07-8bdf the wizard o1 11025 043DC4 04DCBF
-- 08 - 08-8BF1 one bite fro1 11025 04DCC0 066D6D
-- 09 - 09-8c1d My creatures1 11025 066D70 077287
-- 10 - 10-8C3A worlock will1 11025 077288 089939
-- 11 - 11-8C59 you wont hav1 11025 08993C 099D07
-- 12 - 12-8C78 remember im 1 11025 099D08 0AC64F
-- 13 - 13-8C98 if you cant 1 11025 0AC650 0C5C29
-- 14 - 14-8CC5 if you destr1 11025 0C5C2C 0E0FBF
-- 15 - 15-8CF7 now im getti1 11025 0E0FC0 0ED435
-- 16 - 16-8D00 you will nev1 11025 0ED438 0FCEF7
-- 17 - 17-8D29 garwor go af1 11025 0FCEF8 109603
-- 18 - 18-8D35 watch the ra1 11025 109604 110F83
-- 19 - 19-8D4C Warrior.wav 1 11025 110F84 116C93
-- 20 - 20-8D55 Now youll ge1 11025 116C94 12408D
-- 21 - 21-8D77 youre asking1 11025 124090 13079B
-- 22 - 22-8D8A if you try a1 11025 13079C 14A3EB
-- 23 - 23-8DB5 burwor garwo1 11025 14A3EC 1623CD
-- 24 - 24-8DDD my worlings 1 11025 1623D0 17576D
-- 25 - 25-8e00 NOT in table1 11025 175770 188B0F
-- 26 - 26-8E24 and 8E20 you1 11025 188B10 19ED35
-- 27 - 27-8E4B while you de1 11025 19ED38 1B67ED
-- 28 - 28-8e77 hey insert c1 11025 1B67F0 1C2885
-- 29 - 29-8e8b find me.wav 1 11025 1C2888 1C93CF
-- 30 - 30-Im out of spite.w1 11025 1C93D0 1D3561
-- 31 - 31-8EA9 get ready.wa1 11025 1D3564 1D881B
-- 32 - 32-8EB2 you better h1 11025 1D881C 1EB7D9
-- 33 - 33-8ED3 another coin1 11025 1EB7DC 1FF71D
-- 34 - 34-8EF2 ha ha ha hay1 11025 1FF720 204F03
-- 35 - 35-8EFD ah good my p1 11025 204F04 21A43D
-- 36 - 36- youl get the are1 11025 21A440 22FEA5
-- 37 - 37-8F41 another warr1 11025 22FEA8 247051
-- 38 - 38-8F65 keep going a1 11025 247054 259851
-- 39 - 39-8F83 a few more d1 11025 259854 271AC9
-- 40 - 40-8FB5 worlords com1 11025 271ACC 282CCF
-- 41 - 41-visit the the dun1 11025 282CD0 29B99D
-- 42 - 42-8FF0 deep in the 1 11025 29B9A0 2B73AB
-- 43 - 43-901F thanks you.w1 11025 2B73AC 2BE569
-- 44 - 44-you know you can 1 11025 2BE56C 2CB965
-- 45 - 45-9044 oh hurry bac1 11025 2CB968 2E13CD
-- 46 - 46-906B you can star1 11025 2E13D0 2F98DB
-- 47 - 47-9093 he he he ho 1 11025 2F98DC 31002D
-- 48 - 48-90B6 welcome to m1 11025 310030 320927
-- 49 - 49-90D0 so you've co1 11025 320928 334AFD
-- 50 - 50-90F2 youre off to1 11025 334B00 350655
-- 51 - 51-9117 burwor hasn'1 11025 350658 3634CB
-- 52 - 52-9140 my babies br1 11025 3634CC 37062F
-- 53 - 53-9157 ill fry you 1 11025 370630 38456F
-- 54 - 54-9173 garwor and t1 11025 384570 399433
-- 55 - 55-91A1 the thorwor 1 11025 399434 3B3845
-- 56 - 56-91CE warrior fear1 11025 3B3848 3CB973
-- 57 - 57-warrior youve jus1 11025 3CB974 3DF61F
-- 58 - 58-bite the bolt.wav1 11025 3DF620 3E78AB
-- 59 - 59-9227 wasn't that 1 11025 3E78AC 3F8965
-- 60 - 60-9245 and my telep1 11025 3F8968 4114EB
-- 61 - 61-9270 now you know1 11025 4114EC 423671
-- 62 - 62-9294 maybe youl s1 11025 423674 432445
-- 63 - 63-92AB your explosi1 11025 432448 4476EB
-- 64 - 64-92CF ill say it a1 11025 4476EC 452BDF
-- 65 - 65-be forwarned you 1 11025 452BE0 469C3D
-- 66 - 66-you path leads di1 11025 469C40 47E721
-- 67 - 67-9326 deeper ever 1 11025 47E724 48D4F7
-- 68 - 68-933D Beware you a1 11025 48D4F8 4A12ED
-- 69 - 69- ah you thought y1 11025 4A12F0 4C09B9
-- 70 - 70-938F thorbur are 1 11025 4C09BC 4D05C7
-- 71 - 71-93AB hey your spa1 11025 4D05C8 4E20D7
-- 72 - 72-93CB my beasts ru1 11025 4E20D8 4FD701
-- 73 - 73-93F8 now your onl1 11025 4FD704 50DACF
-- 74 - 74-are you fit to su1 11025 50DAD0 520181
-- 75 - 75-943A oops i must 1 11025 520184 5356BD
-- 76 - 76-945A where are yo1 11025 5356C0 54593F
-- 77 - None!

       -- wave start addresses in sdram 
constant snd_starts : snd_addr_t := (
	x"000000",x"000150",x"005408",x"00DE58",x"02BA00",x"03147C",x"03DCD4",x"043DC4",
	x"04DCC0",x"066D70",x"077288",x"08993C",x"099D08",x"0AC650",x"0C5C2C",x"0E0FC0",
	x"0ED438",x"0FCEF8",x"109604",x"110F84",x"116C94",x"124090",x"13079C",x"14A3EC",
	x"1623D0",x"175770",x"188B10",x"19ED38",x"1B67F0",x"1C2888",x"1C93D0",x"1D3564",
	x"1D881C",x"1EB7DC",x"1FF720",x"204F04",x"21A440",x"22FEA8",x"247054",x"259854",
	x"271ACC",x"282CD0",x"29B9A0",x"2B73AC",x"2BE56C",x"2CB968",x"2E13D0",x"2F98DC",
	x"310030",x"320928",x"334B00",x"350658",x"3634CC",x"370630",x"384570",x"399434",
	x"3B3848",x"3CB974",x"3DF620",x"3E78AC",x"3F8968",x"4114EC",x"423674",x"432448",
	x"4476EC",x"452BE0",x"469C40",x"47E724",x"48D4F8",x"4A12F0",x"4C09BC",x"4D05C8",
	x"4E20D8",x"4FD704",x"50DAD0",x"520184",x"5356C0",x"000000");

       -- wave end addresses in sdram 
constant snd_stops : snd_addr_t := (
	x"00014C",x"005407",x"00DE55",x"02B9FD",x"031479",x"03DCD3",x"043DC3",x"04DCBF",
	x"066D6D",x"077287",x"089939",x"099D07",x"0AC64F",x"0C5C29",x"0E0FBF",x"0ED435",
	x"0FCEF7",x"109603",x"110F83",x"116C93",x"12408D",x"13079B",x"14A3EB",x"1623CD",
	x"17576D",x"188B0F",x"19ED35",x"1B67ED",x"1C2885",x"1C93CF",x"1D3561",x"1D881B",
	x"1EB7D9",x"1FF71D",x"204F03",x"21A43D",x"22FEA5",x"247051",x"259851",x"271AC9",
	x"282CCF",x"29B99D",x"2B73AB",x"2BE569",x"2CB965",x"2E13CD",x"2F98DB",x"31002D",
	x"320927",x"334AFD",x"350655",x"3634CB",x"37062F",x"38456F",x"399433",x"3B3845",
	x"3CB973",x"3DF61F",x"3E78AB",x"3F8965",x"4114EB",x"423671",x"432445",x"4476EB",
	x"452BDF",x"469C3D",x"47E721",x"48D4F7",x"4A12ED",x"4C09B9",x"4D05C7",x"4E20D7",
	x"4FD701",x"50DACF",x"520181",x"5356BD",x"54593F",x"000000");

 -- sound playing
 signal snd_starteds : std_logic := '0'; 
 signal last_start   : std_logic := '0'; 
 signal cs_r         : std_logic;
 signal snd_addrs    : std_logic_vector(23 downto 0);
 signal clk11k       : std_logic_vector(1 downto 0) := "00";
 signal Phoneme      : std_logic_vector(5 downto 0) := "111111";
 signal WriteAddress : std_logic_vector(15 downto 0);
 
 begin
 
  snd_id <= to_integer(unsigned(wav_clk_cnt(8 downto 5)));
  votrax <= not snd_starteds;
  
  p_chip_sel : process(ENA, I_MXA)
  begin
    cs_r <= '0';
    if (ENA = '1') then -- cpu access to $17
      if (I_MXA(7 downto 0) = "00010111") then
        cs_r <= '1';
      end if;
    end if;
  end process;

  p_reg_read : process
  begin
    wait until rising_edge(CLK);

    if (ENA = '1') then
		if (I_RESET_L = '0') or (last_start = '1' and snd_starteds = '0') then
			Phoneme <= "111111";
		else
			if I_MXA(15 downto 0) = x"8213" and (I_M1_L = '0') and (I_RD_L = '1') and (I_IORQ_L = '1') then 
				Phoneme <= I_MXA(13 downto 8);
				WriteAddress <= I_HL;
			end if;
		end if;
		last_start <= snd_starteds;
    end if;
  end process;

  
 Play : process
 begin

	wait until rising_edge(CLK);

	if s_enable='1' then
	
		 -- work out what sample to play
		 if snd_starteds = '0' then

			 case Phoneme is
				when "000011" => snd_play <= 00; 		-- Pause \\ No sound
				when "111110" => snd_play <= 00; 		-- Pause \\ No sound
				when "111111" => snd_play <= 77; 		-- STOP
				when others =>
					case WriteAddress is	
						-- HL=Address of Phoneme in ROM - use this to work out word/phrase to speak

	when x"8b6c" => snd_play <= 01 ;-- ; worlock (3 length) 
	when x"8b70" => snd_play <= 02 ;-- ; for double score
	when x"8b84" | x"8b81" => snd_play <= 03 ;-- ; (9477,+1) If you get too powerful ill take care of you myself
	when x"8bb6" => snd_play <= 04 ;-- ; you are in --	
	when x"8bc1" => snd_play <= 05 ;-- ; dungeons of war
	when x"8bd6" => snd_play <= 06 ;-- ; i am 
	when x"8bdf" => snd_play <= 07 ;-- ; the wizard of wor  			**** follows
	when x"8bf1" => snd_play <= 08 ;-- ; one bite from my pretties and youll explode 
	when x"8c1d" => snd_play <= 09 ;-- ; My creatures are radioactive 
	when x"8c3a" | x"8C3F" => snd_play <= 10 ;-- ; worlock will escape through the door 
	when x"8c59" => snd_play <= 11 ;-- ; You wont have a chance for your dance...
	when x"8C78" => snd_play <= 12 ;-- ; remember i'm the wizard not you 		
	when x"8C98" => snd_play <= 13 ;-- ; if you can't beat the rest then youl never get the best 
	when x"8CC5" => snd_play <= 14 ;-- ; if you destroy my babies i'll pop you in the oven 
	when x"8CF7" => snd_play <= 15 ;-- ; now i'm getting mad 
	when x"8D00" => snd_play <= 16 ;-- ; youl never leave wor alive
	when x"8D29" => snd_play <= 17 ;-- ; garwor go after them 
	when x"8D35" => snd_play <= 18 ;-- ; watch the radar (no, warrior)  had 8D3F, which is right?
	when x"8D4C" => snd_play <= 19 ;-- ; Warrior 
	when x"8D55" => snd_play <= 20 ;-- ; Now youll get the heavyweights
	when x"8D77" => snd_play <= 21 ;-- ; you're asking for trouble 
	when x"8D8A" => snd_play <= 22 ;-- ; if you try any harder youl only meet with doom 
	when x"8DB5" => snd_play <= 23 ;-- ; burwor garwor and thorwor will do you in 
	when x"8DDD" => snd_play <= 24 ;-- ; my worlings are very very hungry 
	when x"8e00" => snd_play <= 25 ;-- ; (NOT in table)  my magic is stronger than your weapons warrior 
	when x"8E20" | x"8E24" => snd_play <= 26 ;-- ; your bones will lie in the dungeons of wor
	when x"8E4B" | x"8E59" => snd_play <= 27 ;-- while you developed science we developed magic 
	when x"8e77" | x"8E7B" => snd_play <= 28 ;-- ; (NOT in table)  hey insert coin
	when x"8e8b" | x"8E8D" => snd_play <= 29 ;-- ; find me
	when x"8E96" => snd_play <= 30 ;-- ; Im out of spite
	when x"8ea9" => snd_play <= 31 ;-- ; get ready
	when x"8EB2" => snd_play <= 32 ;-- ; you better hope you don't find me (no, the wizard of wor)
	when x"8ED3" => snd_play <= 33 ;-- ; another coin for my treasure chest 			
	when x"8EF2" | x"8F35" => snd_play <= 34 ;-- ; ha ha ha ha 			**** follows
	when x"8EFD" => snd_play <= 35 ;-- ; ah good my pets were getting hungry (no, ha ha ha ha)
	when x"8F20" => snd_play <= 36 ;-- ; youll get the arena pit
	when x"8F41" => snd_play <= 37 ;-- ; another warrior for my babies to devour 			
	when x"8F65" => snd_play <= 38 ;-- ; keep going and you will find me 
	when x"8F83" => snd_play <= 39 ;-- ; a few more dungeons and you will be a worlord 
	when x"8FB5" => snd_play <= 40 ;-- ; come back for more (says dungeons)// (no) with the wizard of wor 
	when x"8Fc4" => snd_play <= 40 ;-- ; visit the dungeons of wor await your 
	when x"8FC8" => snd_play <= 41 ;-- ; (the?) dungeons of wor 	****COULD USE AS 8BC1??
	when x"8FF0" => snd_play <= 42 ;-- ; deep in the caverns of wor you will meet me
	when x"901F" => snd_play <= 43 ;-- ; thanks you
	when x"902B" => snd_play <= 44 ;-- ; you know you can do better
	when x"9044" => snd_play <= 45 ;-- ; hurry back i can't wait to do it again 
	when x"906B" => snd_play <= 46 ;-- ; you can start anew but for now you're through 
	when x"9093" => snd_play <= 47 ;-- ; he he he ho ho ho ha ha ha that was fun 
	when x"90B6" => snd_play <= 48 ;-- ; welcome to my world of wor 
	when x"90D0" => snd_play <= 49 ;-- ; so you've come to score in the world of wor (no, ha ha ha ha)
	when x"90F2" => snd_play <= 50 ;-- ; you're off to see the wizard the (INFL) magical wizard of wor 
	when x"912B" | x"9117" => snd_play <= 51 ;-- ; (no burwor) hasn't eaten anyone in months (no, ha ha ha ha)
	when x"9140" => snd_play <= 52 ;-- ; my babies breathe fire (no, warrior)
	when x"9157" => snd_play <= 53 ;-- ; i'll fry you with my lightning bolts 
	when x"9173" => snd_play <= 54 ;-- ; (wrong start?) garwor and thorwor become invisible 			
	when x"91A1" => snd_play <= 55 ;-- ; thorwor is red mean and hungry for space food 				
	when x"91CE" => snd_play <= 56 ;-- ; warrior fear i draw near each time i appear 
	when x"91F7" => snd_play <= 18 ;-- ; same as...warrior  3E 07 AD 26 2B 29 3A
	when x"91FF" => snd_play <= 57 ;-- ; oh youve just been fried
	when x"9216" | x"9219" => snd_play <= 58 ;-- ; bite the bolt (non 3E!)
	when x"9227" => snd_play <= 59 ;-- ; wasn't that lightning bolt delicious 
	when x"9245" => snd_play <= 60 ;-- ; and my teleporting spell can be even faster
	when x"9270" => snd_play <= 61 ;-- ; now you know the taste of my magic 
	when x"9294" => snd_play <= 62 ;-- ; maybe youl see me again (no, warrior)
	when x"92AB" => snd_play <= 63 ;-- ; your explosion was music to my ears (no, ha ha ha ha)
	when x"92CF" => snd_play <= 64 ;-- ; i'll say it again 
	when x"9281" => snd_play <= 65 ;-- ; be forwarned you approach the pit
	when x"9306" => snd_play <= 66 ;-- ; you path leads directly to the pit 
	when x"9326" => snd_play <= 67 ;-- ; deeper ever deeper into
	when x"933D" => snd_play <= 68 ;-- ; beware you are in the worlord dungeons 
	when x"935F" => snd_play <= 69 ;-- ; ah you thought you could but Im the dungeon Master
	when x"938F" => snd_play <= 70 ;-- ; thor bur are dinner’s ready (no, ha ha ha ha)
	when x"93AB" => snd_play <= 71 ;-- ; hey your space boot's untied (no, ha ha ha ha)
	when x"93CB" => snd_play <= 72 ;-- ; my beasts run wild in the worlord dungeons (no, ha ha ha ha)
	when x"93F8" => snd_play <= 73 ;-- ; now your only chance is your dance 
	when x"9315" => snd_play <= 74 ;-- ; are you fit to survive the pit 
	when x"943A" => snd_play <= 75 ;-- ; oops i must have forgotten the walls (no, ha ha ha ha)
	when x"945A" => snd_play <= 76 ;-- ; where are you going to hide now? (no, ha ha ha ha)
	when others  => snd_play <= 77 ;-- ; nothing matched
					end case;
			 end case;
						
			 -- Set start address for selected sample
			 if snd_play /= 77 then
					snd_addrs <= snd_starts(snd_play);
					snd_starteds <= '1';
			 end if;
	    else
			 -- Stopped ?
			 if Phoneme = "111111" then
			 	 snd_play <= 77;
				 snd_starteds <= '0';
			 end if;
		 end if;
		 
		 -- 44.1kHz base tempo / high bits for scanning sound#
		 if wav_clk_cnt = x"145" then  -- divide 14MHz by 324 => 44.055kHz
			 wav_clk_cnt <= (others=>'0');
			 clk11k <= clk11k + 1;
			 
			 -- All samples 11khz, so every 4th call
			 if clk11k="11" then
				 -- latch final audio / reset sum
				 audio_out_l <= not audio(15) & audio(14 downto 0); -- Convert to unsigned
				 audio_out_r <= not audio(15) & audio(14 downto 0); -- for output
			 end if;
			
		 else
			 wav_clk_cnt <= wav_clk_cnt + 1;
		 end if;

		-- sdram read trigger (and auto refresh period)
		if wav_clk_cnt(4 downto 0) = "00000" then s_read <= '1';end if;
		if wav_clk_cnt(4 downto 0) = "00010" then s_read <= '0';end if;			

		-- single channel
		if clk11k="01" then 

			-- sound# currently playing 
			if (snd_starteds = '1') then

				-- set ddram addr
				if snd_id = 2 and wav_clk_cnt(4 downto 0) = "00000" then
					s_addr <= snd_addrs;			
					wave_read_ct <= "001";
				end if;
			
				if wave_read_ct /= "000" then
											
						case wave_read_ct is
						
							when "001" => -- Read first byte
								s_read       <= '1';
								wave_read_ct <= "010";
						
							when "010" => -- First byte returned ?
								if s_ready='1' then
									s_read <= '0';
									s_addr <= snd_addrs + 1;
									wave_data(7 downto 0) <= s_data(7 downto 0);
									wave_read_ct <= "011";
								end if;
									
							when "011" => -- Read second byte
									s_read <= '1';
									wave_read_ct <= "100";
												
							when "100" => -- Second byte returned ?
								if s_ready='1' then
									s_read <= '0';
									wave_data(15 downto 8) <= s_data(7 downto 0);
									wave_read_ct <= "101";
								end if;

							when "101" => -- Completed
									audio <= wave_data;
									snd_addrs <= snd_addrs + 2;	
									wave_read_ct <= "000";
						
							when others => null;
							
						end case;
						
				end if;
			
				-- (stop / loop)
				if snd_addrs >= snd_stops(snd_play) then 
						snd_starteds <= '0';
						snd_play <= 77;
						audio <= (others => '0');
				end if;
				
			end if;
		
		end if;
		
	else
		 -- Silence
		 audio_out_l <= (others => '0');
		 audio_out_r <= (others => '0');
	end if;
		
 end process;

end architecture;

