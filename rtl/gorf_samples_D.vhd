library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;

entity GorfSound_DDRAM is
port (
	-- Sample data
	GORF1  		: in  std_logic; -- 0 = Gorf, 1 = Gorfprgm1
	s_enable  	: in  std_logic;
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

-- Gorf simulation of Votrax speech chip
--
-- general logic (and samples) taken from older version of Mame before speech chip added

architecture RTL of GorfSound_DDRAM is

 signal wav_clk_cnt : std_logic_vector(8 downto 0) := (others=>'0'); -- 44kHz divider / sound# counter

 subtype snd_id_t is integer range 0 to 87;

 -- sound#
 signal snd_id   : integer range 0 to 15;				-- for Time Slice
 signal snd_play : snd_id_t := 87; 						-- current wav playing
 signal audio    : std_logic_vector(15 downto 0) register := (others=>'0');

 signal wave_read_ct   : std_logic_vector(2 downto 0) register := (others=>'0');
 signal wave_data      : std_logic_vector(15 downto 0) register := (others=>'0');

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
-- 29 - doom.wav            1 11025 07BCEA 07E6B6
-- 30 - draws.wav           1 11025 07E6B8 0807B0
-- 31 - dust.wav            1 11025 0807B2 082D50
-- 32 - empire.wav          1 11025 082D52 087488
-- 33 - end.wav             1 11025 08748A 08964C
-- 34 - enemy.wav           1 11025 08964E 08CAA6
-- 35 - escape.wav          1 11025 08CAA8 0905AA
-- 36 - flagship.wav        1 11025 0905AC 095B5E
-- 37 - for.wav             1 11025 095B60 097D32
-- 38 - galactic.wav        1 11025 097D34 09C756
-- 39 - galaxy.wav          1 11025 09C758 0A0754
-- 40 - general.wav         1 11025 0A0756 0A3AEE
-- 41 - gorf.wav            1 11025 0A3AF0 0A75AA
-- 42 - gorphian.wav        1 11025 0A75AC 0AB34E
-- 43 - gorphins.wav        1 11025 0AB350 0AF78C
-- 44 - got.wav             1 11025 0AF78E 0B14B8
-- 45 - hahahahu.wav        1 11025 0B14BA 0B6AE0
-- 46 - harder.wav          1 11025 0B6AE2 0B9C0A
-- 47 - have.wav            1 11025 0B9C0C 0BC254
-- 48 - hitting.wav         1 11025 0BC256 0BF8EC
-- 49 - i.wav               1 11025 0BF8EE 0C1BB0
-- 50 - in.wav              1 11025 0C1BB2 0C348E
-- 51 - insert.wav          1 11025 0C3490 0C6FA4
-- 52 - long.wav            1 11025 0C6FA6 0CB618
-- 53 - meet.wav            1 11025 0CB61A 0CE062
-- 54 - move.wav            1 11025 0CE064 0D0EE8
-- 55 - my.wav              1 11025 0D0EEA 0D394A
-- 56 - near.wav            1 11025 0D394C 0D5C98
-- 57 - next.wav            1 11025 0D5C9A 0D96CE
-- 58 - nice.wav            1 11025 0D96D0 0DC024
-- 59 - no.wav              1 11025 0DC026 0DDBE6
-- 60 - now.wav             1 11025 0DDBE8 0E0DC0
-- 61 - pause.wav           1 11025 0E0DC2 0E0DC4
-- 62 - player.wav          1 11025 0E0DC6 0E3550
-- 63 - prepare.wav         1 11025 0E3552 0EBB9C
-- 64 - prisonrs.wav        1 11025 0EBB9E 0F035A
-- 65 - promoted.wav        1 11025 0F035C 0F4304
-- 66 - push.wav            1 11025 0F4306 0F611A
-- 67 - robot.wav           1 11025 0F611C 0F9B44
-- 68 - robots.wav          1 11025 0F9B46 0FEADA
-- 69 - seek.wav            1 11025 0FEADC 100AEA
-- 70 - ship.wav            1 11025 100AEC 1030CE
-- 71 - shot.wav            1 11025 1030D0 10572E
-- 72 - some.wav            1 11025 105730 107A04
-- 73 - space.wav           1 11025 107A06 10ACE6
-- 74 - spause.wav          1 11025 10ACE8 10ACEA
-- 75 - survival.wav        1 11025 10ACEC 116C14
-- 76 - take.wav            1 11025 116C16 118728
-- 77 - the.wav             1 11025 11872A 1199B4
-- 78 - time.wav            1 11025 1199B6 11AB70
-- 79 - to.wav              1 11025 11AB72 11BD58
-- 80 - try.wav             1 11025 11BD5A 11E44C
-- 81 - unbeatab.wav        1 11025 11E44E 123522
-- 82 - warrior.wav         1 11025 123524 1285B0
-- 83 - warriors.wav        1 11025 1285B2 12D15E
-- 84 - will.wav            1 11025 12D160 12F442
-- 85 - you.wav             1 11025 12F444 1312EE
-- 86 - your.wav            1 11025 1312F0 133278
-- 87 - None!

 -- wave start addresses in sdram
 constant snd_starts : snd_addr_t := (
	x"000000",x"001A16",x"0066FE",x"025B1A",x"02817C",x"029AF0",x"02FD24",x"03391C",
	x"035748",x"038AAC",x"03DB54",x"0401FA",x"041A88",x"0436E4",x"045E6A",x"047D1C",
	x"04B08C",x"04DA0A",x"0502BC",x"0538A8",x"0586C4",x"05BBCC",x"05F3F2",x"0620F2",
	x"064D62",x"06ABE8",x"06EC58",x"07372E",x"07867A",x"07BCEA",x"07E6B8",x"0807B2",
	x"082D52",x"08748A",x"08964E",x"08CAA8",x"0905AC",x"095B60",x"097D34",x"09C758",
	x"0A0756",x"0A3AF0",x"0A75AC",x"0AB350",x"0AF78E",x"0B14BA",x"0B6AE2",x"0B9C0C",
	x"0BC256",x"0BF8EE",x"0C1BB2",x"0C3490",x"0C6FA6",x"0CB61A",x"0CE064",x"0D0EEA",
	x"0D394C",x"0D5C9A",x"0D96D0",x"0DC026",x"0DDBE8",x"0E0DC2",x"0E0DC6",x"0E3552",
	x"0EBB9E",x"0F035C",x"0F4306",x"0F611C",x"0F9B46",x"0FEADC",x"100AEC",x"1030D0",
	x"105730",x"107A06",x"10ACE8",x"10ACEC",x"116C16",x"11872A",x"1199B6",x"11AB72",
	x"11BD5A",x"11E44E",x"123524",x"1285B2",x"12D160",x"12F444",x"1312F0",x"000000");

 -- wave end addresses in sdram
 constant snd_stops : snd_addr_t := (
	x"001A14",x"0066FC",x"025B18",x"02817A",x"029AEE",x"02FD22",x"03391A",x"035746",
	x"038AAA",x"03DB52",x"0401F8",x"041A86",x"0436E2",x"045E68",x"047D1A",x"04B08A",
	x"04DA08",x"0502BA",x"0538A6",x"0586C2",x"05BBCA",x"05F3F0",x"0620F0",x"064D60",
	x"06ABE6",x"06EC56",x"07372C",x"078678",x"07BCE8",x"07E6B6",x"0807B0",x"082D50",
	x"087488",x"08964C",x"08CAA6",x"0905AA",x"095B5E",x"097D32",x"09C756",x"0A0754",
	x"0A3AEE",x"0A75AA",x"0AB34E",x"0AF78C",x"0B14B8",x"0B6AE0",x"0B9C0A",x"0BC254",
	x"0BF8EC",x"0C1BB0",x"0C348E",x"0C6FA4",x"0CB618",x"0CE062",x"0D0EE8",x"0D394A",
	x"0D5C98",x"0D96CE",x"0DC024",x"0DDBE6",x"0E0DC0",x"0E0DC4",x"0E3550",x"0EBB9C",
	x"0F035A",x"0F4304",x"0F611A",x"0F9B44",x"0FEADA",x"100AEA",x"1030CE",x"10572E",
	x"107A04",x"10ACE6",x"10ACEA",x"116C14",x"118728",x"1199B4",x"11AB70",x"11BD58",
	x"11E44C",x"123522",x"1285B0",x"12D15E",x"12F442",x"1312EE",x"133278",x"000000");

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

			if GORF1 ='0' then -- 0 = Gorf, 1 = Gorfprgm1

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

			else
			 case Phoneme is
				when "000011" => snd_play <= 74; 		-- Pause
				when "111110" => snd_play <= 61; 		-- SPause
				when "111111" => snd_play <= 87; 		-- STOP
				when others =>
					case WriteAddress is
-- Gorf Program 1
						-- HL=Address of Phoneme in ROM - use this to work out word/phrase to speak
						when x"B331" | x"B34E" => snd_play <= 0; 			-- A
						when x"11C2" => snd_play <= 1; 						-- Again
						when x"B3BB" | x"1185" => snd_play <= 3; 			-- Am
						when x"B386" => snd_play <= 4; 						-- And
						when x"B3E7" => snd_play <= 5; 						-- Annihalate												
						when x"11AE" | x"1310" => snd_play <= 6; 			-- Another
						when x"B3AA" | x"12DE" => snd_play <= 7; 			-- Are
						when x"11FD" | x"1203" => snd_play <= 8; 			-- Attack
						when x"12A1" => snd_play <= 9; 						-- Avenger
						when x"1259" | x"120A" => snd_play <= 10; 			-- Bad
						when x"A8E8" => snd_play <= 11; 					-- Be
						when x"12B4" => snd_play <= 12; 					-- Been
						when x"12E2" => snd_play <= 13; 					-- Bite
						when x"A8F0" => snd_play <= 14; 					-- But
						when x"B33A" => snd_play <= 15; 					-- Button
						when x"1278" => snd_play <= 16; 					-- Cadet
						when x"1222" => snd_play <= 17; 					-- Cannot
						when x"127F" => snd_play <= 18; 					-- Captain
						when x"A90A" => snd_play <= 19; 					-- Chronicle
						when x"1178" => snd_play <= 20; 					-- Coin
						when x"11D2" => snd_play <= 21; 					-- Coins
						when x"1288" => snd_play <= 22; 					-- Colonel
						when x"11A9" => snd_play <= 23; 					-- Conquer
						when x"B3C9" => snd_play <= 24; 					-- Conscious
						when x"12D2" => snd_play <= 25; 					-- Defender
						when x"B38A" => snd_play <= 26; 					-- Destroy
						when x"1320" => snd_play <= 27; 					-- Destroyed
						when x"11CC" => snd_play <= 28; 					-- Devour
						when x"B358" => snd_play <= 29; 					-- Doom
						when x"1332" => snd_play <= 30; 					-- Draws
						when x"12E9" => snd_play <= 31; 					-- Dust
						when x"1191" => snd_play <= 32; 					-- Empire
						when x"132E" => snd_play <= 33; 					-- End
						when x"1317" => snd_play <= 34; 					-- Enemy
						when x"1228" => snd_play <= 35; 					-- Escape
						when x"A924" => snd_play <= 36; 					-- Flagship
						when x"A8F3" | x"A917" | x"B3E3" =>
						                snd_play <= 37; 					-- For
						when x"12C9" => snd_play <= 38; 					-- Galactic
						when x"11B3" => snd_play <= 39; 					-- Galaxy
						when x"128F" => snd_play <= 40; 					-- General
						when x"11E2" => snd_play <= 41; 					-- Gorf
						when x"1189" | x"1230" | x"A902" | x"B350" | x"B399" | x"B3C0" | x"11EB"   =>
						                snd_play <= 42; 					-- Gorfian
						when x"11A0" | x"125F" => snd_play <= 43;			-- Gorfins
						when x"1242" => snd_play <= 44; 					-- Got
						when x"1214" => snd_play <= 45; 					-- Ha Ha Ha
						when x"A8EA" => snd_play <= 46; 					-- Harder
						when x"12B0" => snd_play <= 47; 					-- Have
						when x"A91B" => snd_play <= 48; 					-- Hitting
						when x"1182" | x"B3B8" | x"11C9" =>
						                snd_play <= 49; 					-- I
						when x"A8FE" => snd_play <= 50; 					-- In
						when x"1172" => snd_play <= 51; 					-- Insert
						when x"11DC" => snd_play <= 52; 					-- Long
						when x"B34A" => snd_play <= 53; 					-- Meet
						when x"120E" => snd_play <= 54; 					-- Move
						when x"A920" | x"B395" => snd_play <= 55;			-- My
						when x"1336" => snd_play <= 56; 					-- Near
						when x"A8D8" => snd_play <= 57; 					-- Next
						when x"124B" => snd_play <= 58; 					-- Nice
						when x"126B" => snd_play <= 59; 					-- No
						when x"A8F6" => snd_play <= 60; 					-- Now
						when x"B334" => snd_play <= 62; 					-- Player
						when x"B3D4" => snd_play <= 63; 					-- Prepare
						when x"126D" => snd_play <= 64; 					-- Prisoners
						when x"12B8" => snd_play <= 65; 					-- Promoted
						when x"B32D" => snd_play <= 66; 					-- Push
						when x"B3A2" => snd_play <= 67; 					-- Robot
						when x"1239" | x"B374" | x"11F3"
									    => snd_play <= 68; 					-- Robots
						when x"B383" => snd_play <= 69; 					-- Seek
						when x"131C" => snd_play <= 70; 					-- Ship
						when x"1251" => snd_play <= 71; 					-- Shot
						when x"12C6" => snd_play <= 72; 					-- Some
						when x"1199" => snd_play <= 73; 					-- Space
						when x"B35E" => snd_play <= 75; 					-- Survival
						when x"1268" => snd_play <= 76; 					-- Take
						when x"12E7" | x"B392" | x"B3BE" | x"1187" | x"122E" | x"A900"
						             => snd_play <= 77; 					-- The
						when x"A8E0" => snd_play <= 78; 					-- Time
						when x"1257" | x"12C1" => snd_play <= 79;			-- To
						when x"11BC" => snd_play <= 80; 					-- Try
						when x"B3AC" => snd_play <= 81; 					-- Unbeatable
						when x"1298" => snd_play <= 82; 					-- Warrior
						when x"B37A" => snd_play <= 83; 					-- Warriors
						when x"A8E5" | x"B347" => snd_play <= 84;			-- Will
						when x"1246" | x"12DA" | x"12AC" | x"B343" | x"121E"
					  	             => snd_play <= 85; 					-- You
						when x"132B" => snd_play <= 86; 					-- Yours
						when others  => snd_play <= 87; 					-- Nothing matched, stopped
					end case;
			 end case;

			end if;

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
				 audio <= (others => '0');
			 end if;
		 end if;

		 -- 44.1kHz base tempo / high bits for scanning sound#
		 if wav_clk_cnt = x"145" then  -- divide 14MHz by 324 => 44.055kHz
			 wav_clk_cnt <= (others=>'0');
			 clk11k <= clk11k + 1;

			 -- All samples 11khz, so every 4th call
			 if clk11k="11" then
				 -- latch final audio / reset sum
				 audio_out_l <= audio(15 downto 0);
				 audio_out_r <= audio(15 downto 0);			 
			 end if;

		 else
			 wav_clk_cnt <= wav_clk_cnt + 1;
		 end if;

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
									wave_data <= "00000000" & s_data(7 downto 0);
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

