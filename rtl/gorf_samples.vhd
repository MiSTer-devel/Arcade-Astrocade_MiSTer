library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity GorfSound is
port (
	-- Sample data
	s_enable  	: in  std_logic;
	s_addr    	: out std_logic_vector(23 downto 0);
	s_data    	: in  std_logic_vector(15 downto 0);
	s_read    	: out std_logic;
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

-- Gorf simulation of Votrax speech chip
--
-- general logic (and samples) taken from older version of Mame before speech chip added

architecture RTL of GorfSound is

 signal wav_clk_cnt : std_logic_vector(8 downto 0) := (others=>'0'); -- 44kHz divider / sound# counter
 
 subtype snd_id_t is integer range 0 to 87;
 
 -- sound#
 signal snd_id   : integer range 0 to 15;				-- for Time Slice
 signal snd_play : snd_id_t := 87; 						-- current wav playing
 signal audio    : std_logic_vector(15 downto 0);
 
 type snd_addr_t is array(snd_id_t) of std_logic_vector(23 downto 0);
 
-- 00 - a.wav               1 11025 000000 001A14
-- 01 - again.wav           1 11025 001A16 0066FC
-- 02 - all.wav             1 11025 0066FE 025B18
-- 03 - am.wav              1 11025 025B1A 02817A
-- 04 - and.wav             1 11025 02817C 029AEE
-- 05 - anhilatn.wav        1 11025 029AF0 02FD22
-- 06 - another.wav         1 11025 02FD24 03391A
-- 07 - are.wav             1 11025 03391C 035746
-- 08 - attack.wav          1 11025 035748 038AAA
-- 09 - avenger.wav         1 11025 038AAC 03DB52
-- 10 - bad.wav             1 11025 03DB54 0401F8
-- 11 - be.wav              1 11025 0401FA 041A86
-- 12 - been.wav            1 11025 041A88 0436E2
-- 13 - bite.wav            1 11025 0436E4 045E68
-- 14 - but.wav             1 11025 045E6A 047D1A
-- 15 - button.wav          1 11025 047D1C 04B08A
-- 16 - cadet.wav           1 11025 04B08C 04DA08
-- 17 - cannot.wav          1 11025 04DA0A 0502BA
-- 18 - captain.wav         1 11025 0502BC 0538A6
-- 19 - chronicl.wav        1 11025 0538A8 0586C2
-- 20 - coin.wav            1 11025 0586C4 05BBCA
-- 21 - coins.wav           1 11025 05BBCC 05F3F0
-- 22 - colonel.wav         1 11025 05F3F2 0620F0
-- 23 - conquer.wav         1 11025 0620F2 064D60
-- 24 - consciou.wav        1 11025 064D62 06ABE6
-- 25 - defender.wav        1 11025 06ABE8 06EC56
-- 26 - destroy.wav         1 11025 06EC58 07372C
-- 27 - destroyd.wav        1 11025 07372E 078678
-- 28 - devour.wav          1 11025 07867A 07BCE8
-- 29 - doom.wav            1 11025 07BCEA 07BCEC
-- 30 - draws.wav           1 11025 07BCEE 07DDE6
-- 31 - dust.wav            1 11025 07DDE8 080386
-- 32 - empire.wav          1 11025 080388 084ABE
-- 33 - end.wav             1 11025 084AC0 086C82
-- 34 - enemy.wav           1 11025 086C84 08A0DC
-- 35 - escape.wav          1 11025 08A0DE 08DBE0
-- 36 - flagship.wav        1 11025 08DBE2 093194
-- 37 - for.wav             1 11025 093196 095368
-- 38 - galactic.wav        1 11025 09536A 099D8C
-- 39 - galaxy.wav          1 11025 099D8E 09DD8A
-- 40 - general.wav         1 11025 09DD8C 0A1124
-- 41 - gorf.wav            1 11025 0A1126 0A4BE0
-- 42 - gorphian.wav        1 11025 0A4BE2 0A8984
-- 43 - gorphins.wav        1 11025 0A8986 0ACDC2
-- 44 - got.wav             1 11025 0ACDC4 0AEAEE
-- 45 - hahahahu.wav        1 11025 0AEAF0 0B4116
-- 46 - harder.wav          1 11025 0B4118 0B7240
-- 47 - have.wav            1 11025 0B7242 0B988A
-- 48 - hitting.wav         1 11025 0B988C 0BB3D6
-- 49 - i.wav               1 11025 0BB3D8 0BD69A
-- 50 - in.wav              1 11025 0BD69C 0BEF78
-- 51 - insert.wav          1 11025 0BEF7A 0C2A8E
-- 52 - long.wav            1 11025 0C2A90 0C7102
-- 53 - meet.wav            1 11025 0C7104 0C9B4C
-- 54 - move.wav            1 11025 0C9B4E 0CC9D2
-- 55 - my.wav              1 11025 0CC9D4 0CF434
-- 56 - near.wav            1 11025 0CF436 0D1782
-- 57 - next.wav            1 11025 0D1784 0D51B8
-- 58 - nice.wav            1 11025 0D51BA 0D7B0E
-- 59 - no.wav              1 11025 0D7B10 0D96D0
-- 60 - now.wav             1 11025 0D96D2 0DC8AA
-- 61 - pause.wav           1 11025 0DC8AC 0DC8AE
-- 62 - player.wav          1 11025 0DC8B0 0DF03A
-- 63 - prepare.wav         1 11025 0DF03C 0E7686
-- 64 - prisonrs.wav        1 11025 0E7688 0EBE44
-- 65 - promoted.wav        1 11025 0EBE46 0EFDEE
-- 66 - push.wav            1 11025 0EFDF0 0F1C04
-- 67 - robot.wav           1 11025 0F1C06 0F1C08
-- 68 - robots.wav          1 11025 0F1C0A 0F1C0C
-- 69 - seek.wav            1 11025 0F1C0E 0F1C10
-- 70 - ship.wav            1 11025 0F1C12 0F41F4
-- 71 - shot.wav            1 11025 0F41F6 0F6854
-- 72 - some.wav            1 11025 0F6856 0F8B2A
-- 73 - space.wav           1 11025 0F8B2C 0FBE0C
-- 74 - spause.wav          1 11025 0FBE0E 0FBE10
-- 75 - survival.wav        1 11025 0FBE12 107D3A
-- 76 - take.wav            1 11025 107D3C 10984E
-- 77 - the.wav             1 11025 109850 10AADA
-- 78 - time.wav            1 11025 10AADC 10BC96
-- 79 - to.wav              1 11025 10BC98 10CE7E
-- 80 - try.wav             1 11025 10CE80 10F572
-- 81 - unbeatab.wav        1 11025 10F574 114648
-- 82 - warrior.wav         1 11025 11464A 11464C
-- 83 - warriors.wav        1 11025 11464E 1191FA
-- 84 - will.wav            1 11025 1191FC 11B4DE
-- 85 - you.wav             1 11025 11B4E0 11D38A
-- 86 - your.wav            1 11025 11D38C 11F314
-- 87 - None!

 -- wave start addresses in sdram 
 constant snd_starts : snd_addr_t := (
	x"000000",x"001A16",x"0066FE",x"025B1A",x"02817C",x"029AF0",x"02FD24",x"03391C",
	x"035748",x"038AAC",x"03DB54",x"0401FA",x"041A88",x"0436E4",x"045E6A",x"047D1C",
	x"04B08C",x"04DA0A",x"0502BC",x"0538A8",x"0586C4",x"05BBCC",x"05F3F2",x"0620F2",
	x"064D62",x"06ABE8",x"06EC58",x"07372E",x"07867A",x"07BCEA",x"07BCEE",x"07DDE8",
	x"080388",x"084AC0",x"086C84",x"08A0DE",x"08DBE2",x"093196",x"09536A",x"099D8E",
	x"09DD8C",x"0A1126",x"0A4BE2",x"0A8986",x"0ACDC4",x"0AEAF0",x"0B4118",x"0B7242",
	x"0B988C",x"0BB3D8",x"0BD69C",x"0BEF7A",x"0C2A90",x"0C7104",x"0C9B4E",x"0CC9D4",
	x"0CF436",x"0D1784",x"0D51BA",x"0D7B10",x"0D96D2",x"0DC8AC",x"0DC8B0",x"0DF03C",
	x"0E7688",x"0EBE46",x"0EFDF0",x"0F1C06",x"0F1C0A",x"0F1C0E",x"0F1C12",x"0F41F6",
	x"0F6856",x"0F8B2C",x"0FBE0E",x"0FBE12",x"107D3C",x"109850",x"10AADC",x"10BC98",
	x"10CE80",x"10F574",x"11464A",x"11464E",x"1191FC",x"11B4E0",x"11D38C",x"000000");

 -- wave end addresses in sdram 
 constant snd_stops : snd_addr_t := (
	x"001A14",x"0066FC",x"025B18",x"02817A",x"029AEE",x"02FD22",x"03391A",x"035746",
	x"038AAA",x"03DB52",x"0401F8",x"041A86",x"0436E2",x"045E68",x"047D1A",x"04B08A",
	x"04DA08",x"0502BA",x"0538A6",x"0586C2",x"05BBCA",x"05F3F0",x"0620F0",x"064D60",
	x"06ABE6",x"06EC56",x"07372C",x"078678",x"07BCE8",x"07BCEC",x"07DDE6",x"080386",
	x"084ABE",x"086C82",x"08A0DC",x"08DBE0",x"093194",x"095368",x"099D8C",x"09DD8A",
	x"0A1124",x"0A4BE0",x"0A8984",x"0ACDC2",x"0AEAEE",x"0B4116",x"0B7240",x"0B988A",
	x"0BB3D6",x"0BD69A",x"0BEF78",x"0C2A8E",x"0C7102",x"0C9B4C",x"0CC9D2",x"0CF434",
	x"0D1782",x"0D51B8",x"0D7B0E",x"0D96D0",x"0DC8AA",x"0DC8AE",x"0DF03A",x"0E7686",
	x"0EBE44",x"0EFDEE",x"0F1C04",x"0F1C08",x"0F1C0C",x"0F1C10",x"0F41F4",x"0F6854",
	x"0F8B2A",x"0FBE0C",x"0FBE10",x"107D3A",x"10984E",x"10AADA",x"10BC96",x"10CE7E",
	x"10F572",x"114648",x"11464C",x"1191FA",x"11B4DE",x"11D38A",x"11F314",x"000000");
	
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
			if ((I_RD_L = '0') and (I_IORQ_L = '0') and (I_M1_L = '1') and (cs_r = '1')) then
				Phoneme <= I_MXA(13 downto 8);
				WriteAddress <= I_HL - 1;
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
				when "000011" => snd_play <= 74; 		-- Pause
				when "111110" => snd_play <= 61; 		-- SPause
				when "111111" => snd_play <= 87; 		-- STOP
				when others =>
					case WriteAddress is	
						-- HL=Address of Phoneme in ROM - use this to work out word/phrase to speak
						when x"B3C3" | x"B3E0" => snd_play <= 0; 			-- A
						when x"11AF" => snd_play <= 1; 						-- Again
						when x"12DC" => snd_play <= 2; 						-- All
						when x"B44D" | x"1172" => snd_play <= 3; 			-- Am
						when x"B418" => snd_play <= 4; 						-- And
						when x"B479" => snd_play <= 5; 						-- Annihalate
						when x"119B" | x"12FD" => snd_play <= 6; 			-- Another
						when x"B43C" | x"12CB" => snd_play <= 7; 			-- Are
						when x"11EA" | x"11F0" => snd_play <= 8; 			-- Attack
						when x"128E" => snd_play <= 9; 						-- Avenger
						when x"1246" | x"11F7" => snd_play <= 10; 		-- Bad
						when x"A993" => snd_play <= 11; 						-- Be
						when x"12A1" => snd_play <= 12; 						-- Been
						when x"12CF" => snd_play <= 13; 						-- Bite
						when x"A99B" => snd_play <= 14; 						-- But
						when x"B3CC" => snd_play <= 15; 						-- Button
						when x"1265" => snd_play <= 16; 						-- Cadet
						when x"120F" => snd_play <= 17; 						-- Cannot
						when x"126C" => snd_play <= 18; 						-- Captain
						when x"A9B5" => snd_play <= 19; 						-- Chronicle
						when x"1165" => snd_play <= 20; 						-- Coin
						when x"11BF" => snd_play <= 21; 						-- Coins
						when x"1275" => snd_play <= 22; 						-- Colonel
						when x"1196" => snd_play <= 23; 						-- Conquer
						when x"B45B" => snd_play <= 24; 						-- Conscious
						when x"12BF" => snd_play <= 25; 						-- Defender
						when x"B41C" => snd_play <= 26; 						-- Destroy
						when x"130D" => snd_play <= 27; 						-- Destroyed
						when x"11B9" => snd_play <= 28; 						-- Devour
						when x"B3EA" => snd_play <= 29; 						-- Doom
						when x"131F" => snd_play <= 30; 						-- Draws
						when x"12D6" => snd_play <= 31; 						-- Dust
						when x"117E" => snd_play <= 32; 						-- Empire
						when x"131B" => snd_play <= 33; 						-- End
						when x"1304" => snd_play <= 34; 						-- Enemy
						when x"1215" => snd_play <= 35; 						-- Escape
						when x"A9CF" => snd_play <= 36; 						-- Flagship
						when x"A99E" | x"A9C2" | x"B475" => 
						                snd_play <= 37; 						-- For
						when x"12B6" => snd_play <= 38; 						-- Galactic
						when x"11A0" => snd_play <= 39; 						-- Galaxy
						when x"127C" => snd_play <= 40; 						-- General
						when x"11CF" => snd_play <= 41; 						-- Gorf
						when x"1176" | x"121D" | x"A9AD" | x"B3E2" | x"B42B" | x"B452" | x"11D8"   =>
						                snd_play <= 42; 						-- Gorfian
						when x"118D" | x"124C" => snd_play <= 43;			-- Gorfins
						when x"122F" => snd_play <= 44; 						-- Got
						when x"1201" => snd_play <= 45; 						-- Ha Ha Ha
						when x"A995" => snd_play <= 46; 						-- Harder
						when x"129D" => snd_play <= 47; 						-- Have
						when x"A9C6" => snd_play <= 48; 						-- Hitting
						when x"116F" | x"B44A" | x"11B6" => 
						                snd_play <= 49; 						-- I
						when x"A9A9" => snd_play <= 50; 						-- In
						when x"115F" => snd_play <= 51; 						-- Insert
						when x"11C9" => snd_play <= 52; 						-- Long
						when x"B3DC" => snd_play <= 53; 						-- Meet
						when x"11FB" => snd_play <= 54; 						-- Move
						when x"A9CB" | x"B427" => snd_play <= 55;			-- My
						when x"1323" => snd_play <= 56; 						-- Near
						when x"A986" => snd_play <= 57; 						-- Next
						when x"1238" => snd_play <= 58; 						-- Nice
						when x"1258" => snd_play <= 59; 						-- No
						when x"A9A1" => snd_play <= 60; 						-- Now
						when x"B3C6" => snd_play <= 62; 						-- Player
						when x"B466" => snd_play <= 63; 						-- Prepare
						when x"125A" => snd_play <= 64; 						-- Prisoners
						when x"12A5" => snd_play <= 65; 						-- Promoted
						when x"B3BF" => snd_play <= 66; 						-- Push
						when x"B406" => snd_play <= 67; 						-- Robot
						when x"1226" | x"B434" | x"11E0"
									    => snd_play <= 68; 						-- Robots
						when x"B415" => snd_play <= 69; 						-- Seek
						when x"1309" => snd_play <= 70; 						-- Ship
						when x"123E" => snd_play <= 71; 						-- Shot
						when x"12B3" => snd_play <= 72; 						-- Some
						when x"1186" => snd_play <= 73; 						-- Space
						when x"B3F0" => snd_play <= 75; 						-- Survival
						when x"1255" => snd_play <= 76; 						-- Take
						when x"12D4" | x"B424" | x"B450" | x"1174" | x"121B" | x"A9AB"
						             => snd_play <= 77; 						-- The
						when x"A98B" => snd_play <= 78; 						-- Time
						when x"1244" | x"12AE" => snd_play <= 79;			-- To
						when x"11A9" => snd_play <= 80; 						-- Try
						when x"B43E" => snd_play <= 81; 						-- Unbeatable
						when x"1285" => snd_play <= 82; 						-- Warrior
						when x"B40C" => snd_play <= 83; 						-- Warriors
						when x"A990" | x"B3D9" => snd_play <= 84;			-- Will
						when x"1233" | x"12C7" | x"1299" | x"B3D5" | x"120B"
					  	             => snd_play <= 85; 						-- You
						when x"1318" => snd_play <= 86; 					   -- Yours
						when others  => snd_play <= 87; 						-- Nothing matched, stopped
					end case;
			 end case;
						
			 -- Set start address for selected sample
			 if snd_play /= 87 then
					snd_addrs <= snd_starts(snd_play);
					snd_starteds <= '1';
			 end if;
	    else
			 -- Stopped ?
			 if Phoneme = "111111" then
			 	 snd_play <= 87;
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
				 audio_out_r <= not audio(15) & audio(14 downto 0); --     for output
			 end if;
			
		 else
			 wav_clk_cnt <= wav_clk_cnt + 1;
		 end if;

		-- sdram read trigger (and auto refresh period)
		if wav_clk_cnt(4 downto 0) = "00000" then s_read <= '1';end if;
		if wav_clk_cnt(4 downto 0) = "00010" then s_read <= '0';end if;			

		-- single channel
		if snd_id = 2 and clk11k="01" then 
		
			-- set sdram addr at begining of cycle
			if wav_clk_cnt(4 downto 0) = "00000" then
				s_addr <= snd_addrs;			
			end if;
		
			-- sound# currently playing 
			if (snd_starteds = '1') then
			
				-- get sound# sample and update next sound# address
				if wav_clk_cnt(4 downto 0) = "01000" then
											
					audio <= s_data;
					
					-- update next sound# address
					snd_addrs <= snd_addrs + 2;	
				end if;
				
				-- (stop / loop)
				if snd_addrs >= snd_stops(snd_play) then 
						snd_starteds <= '0';
						--Phoneme <= "111111";
						snd_play <= 87;
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

