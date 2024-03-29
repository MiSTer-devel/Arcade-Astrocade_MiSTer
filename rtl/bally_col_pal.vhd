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
use ieee.numeric_std.all;

entity BALLY_COL_PAL is
  port (
    ADDR        : in    std_logic_vector(8 downto 0);
    DATA        : out   std_logic_vector(23 downto 0)
    );
end;

-- New calculations, including effect of RGB PCB from Frank

architecture RTL of BALLY_COL_PAL is

  type ROM_ARRAY is array(0 to 511) of std_logic_vector(23 downto 0);
  constant ROM : ROM_ARRAY := (
	X"000000", X"000000", X"000000", X"000000", X"000000", X"0A0D1A", X"252938", X"404456", X"5B5F74", X"777A92", X"9295B0", X"ADB0CE", X"C8CCEC", X"E3E7FF", X"FEFFFF", X"FFFFFF", 
--	X"000000", X"111111", X"222222", X"333333", X"444444", X"555555", X"666666", X"777777", X"888888", X"999999", X"AAAAAA", X"BBBBBB", X"CCCCCC", X"DDDDDD", X"EEEEEE", X"FFFFFF",  -- Grey scale
	X"00006E", X"000089", X"0000A3", X"0600BD", X"2000D7", X"3A00F1", X"5500FF", X"6F00FF", X"8908FF", X"A423FF", X"C03FFF", X"DB5AFF", X"F675FF", X"FF90FF", X"FFABFF", X"FFC7FF", 
	X"000063", X"00007E", X"180098", X"3200B2", X"4C00CC", X"6600E6", X"8000FF", X"9B00FF", X"B508FF", X"D023FF", X"EC3FFF", X"FF5AFF", X"FF75FF", X"FF90FF", X"FFABFF", X"FFC7FF", 
	X"0C004F", X"260069", X"400083", X"5B009D", X"7500B8", X"8F00D2", X"A900EC", X"C300FF", X"DE0CFF", X"F927FF", X"FF43FF", X"FF5EFF", X"FF79FF", X"FF94FF", X"FFAFFF", X"FFCAFF", 
	X"300034", X"4A004F", X"640069", X"7E0083", X"98009D", X"B200B7", X"CD00D1", X"E700EC", X"FF13FF", X"FF2EFF", X"FF49FF", X"FF64FF", X"FF80FF", X"FF9BFF", X"FFB6FF", X"FFD1FF", 
	X"4C0013", X"66002D", X"800048", X"9A0062", X"B4007C", X"CF0096", X"E900B0", X"FF02CB", X"FF1DE9", X"FF38FF", X"FF53FF", X"FF6EFF", X"FF89FF", X"FFA5FF", X"FFC0FF", X"FFDBFF", 
	X"620000", X"7C0007", X"960021", X"B0003C", X"CA0056", X"E50070", X"FF008A", X"FF0EA6", X"FF29C4", X"FF44E2", X"FF5FFF", X"FF7BFF", X"FF96FF", X"FFB1FF", X"FFCCFF", X"FFE7FF", 
	X"6D0000", X"880000", X"A20000", X"BC0012", X"D6002D", X"F00047", X"FF0161", X"FF1C7F", X"FF389D", X"FF53BB", X"FF6ED9", X"FF89F7", X"FFA4FF", X"FFBFFF", X"FFDBFF", X"FFF6FF", 
	X"740000", X"8E0000", X"A80000", X"C20000", X"DD0002", X"F7001C", X"FF1138", X"FF2C56", X"FF4774", X"FF6292", X"FF7EB0", X"FF99CE", X"FFB4EC", X"FFCFFF", X"FFEAFF", X"FFFFFF", 
	X"6C0000", X"860000", X"A00000", X"BB0000", X"D50000", X"EF0700", X"FF220E", X"FF3D2C", X"FF594A", X"FF7468", X"FF8F86", X"FFAAA4", X"FFC5C2", X"FFE1E0", X"FFFCFE", X"FFFFFF", 
	X"5F0000", X"790000", X"940000", X"AE0000", X"C80000", X"E31800", X"FE3300", X"FF4E05", X"FF6A23", X"FF8541", X"FFA05F", X"FFBB7D", X"FFD69B", X"FFF1B8", X"FFFFD4", X"FFFFEF", 
	X"480000", X"620000", X"7C0000", X"970000", X"B10E00", X"CD2900", X"E84400", X"FF6000", X"FF7B00", X"FF961C", X"FFB139", X"FFCC57", X"FFE775", X"FFFF93", X"FFFFAD", X"FFFFC7", 
	X"2B0000", X"450000", X"5F0000", X"7A0300", X"951E00", X"B03900", X"CB5400", X"E67000", X"FF8B00", X"FFA600", X"FFC118", X"FFDC36", X"FFF854", X"FFFF6F", X"FFFF89", X"FFFFA4", 
	X"070000", X"210000", X"3B0000", X"561200", X"712D00", X"8C4800", X"A76300", X"C37E00", X"DE9A00", X"F9B500", X"FFD000", X"FFEB1A", X"FFFF37", X"FFFF51", X"FFFF6B", X"FFFF86", 
	X"000000", X"000000", X"120300", X"2D1E00", X"483900", X"635500", X"7F7000", X"9A8B00", X"B5A600", X"D0C100", X"ECDD00", X"FFF805", X"FFFF20", X"FFFF3A", X"FFFF54", X"FFFF6E", 
	X"000000", X"000000", X"000D00", X"012800", X"1C4300", X"385E00", X"537900", X"6E9500", X"89B000", X"A4CB00", X"C0E600", X"DBFF00", X"F5FF12", X"FFFF2C", X"FFFF46", X"FFFF60", 
	X"000000", X"000000", X"001400", X"002F00", X"004A00", X"0A6500", X"258100", X"409C00", X"5BB700", X"77D200", X"92ED00", X"ADFF00", X"C7FF0A", X"E1FF25", X"FBFF3F", X"FFFF59", 
	X"000000", X"000000", X"001600", X"003100", X"004C00", X"006800", X"008300", X"119E00", X"2CB900", X"48D400", X"63EF00", X"7EFF00", X"98FF10", X"B2FF2A", X"CCFF45", X"E6FF5F", 
	X"000000", X"000000", X"001500", X"003000", X"004C00", X"006700", X"008200", X"009D00", X"01B800", X"1CD300", X"37EF00", X"52FF03", X"6CFF1E", X"86FF38", X"A0FF52", X"BAFF6C", 
	X"000000", X"000000", X"001100", X"002C00", X"004700", X"006200", X"007E00", X"009900", X"00B400", X"00CF00", X"0DEA00", X"28FF19", X"42FF34", X"5CFF4E", X"77FF68", X"91FF82", 
	X"000000", X"000000", X"000900", X"002500", X"004000", X"005B00", X"007600", X"009100", X"00AC00", X"00C800", X"00E318", X"03FE36", X"1DFF50", X"38FF6B", X"52FF85", X"6CFF9F", 
	X"000000", X"000000", X"000000", X"001A00", X"003600", X"005100", X"006C00", X"008700", X"00A200", X"00BD1C", X"00D939", X"00F457", X"00FF73", X"19FF8D", X"33FFA7", X"4DFFC1", 
	X"000000", X"000000", X"000000", X"000E00", X"002900", X"004400", X"005F00", X"007B05", X"009623", X"00B141", X"00CC5F", X"00E77D", X"00FF9A", X"01FFB4", X"1BFFCE", X"36FFE8", 
	X"000000", X"000000", X"000000", X"000000", X"001B00", X"003600", X"00510E", X"006C2C", X"00884A", X"00A368", X"00BE86", X"00D9A4", X"00F4C2", X"00FFDD", X"0DFFF7", X"27FFFF", 
	X"000000", X"000000", X"000000", X"000000", X"000B00", X"00261A", X"004138", X"005C56", X"007874", X"009392", X"00AEB0", X"00C9CE", X"00E4EC", X"00FFFF", X"07FFFF", X"21FFFF", 
	X"000000", X"000000", X"000000", X"00000C", X"000026", X"001543", X"003061", X"004B7F", X"00669D", X"0082BB", X"009DD9", X"00B8F7", X"00D3FF", X"00EEFF", X"0FFFFF", X"29FFFF", 
	X"000000", X"000001", X"00001B", X"000036", X"000050", X"00046A", X"001F88", X"003AA6", X"0055C4", X"0070E2", X"008CFF", X"00A7FF", X"00C2FF", X"02DDFF", X"1EF8FF", X"38FFFF", 
	X"00000E", X"000028", X"000042", X"00005C", X"000076", X"000091", X"000EAD", X"0029CB", X"0044E9", X"0060FF", X"007BFF", X"0096FF", X"00B1FF", X"1ACCFF", X"36E7FF", X"51FFFF", 
	X"000030", X"00004A", X"000064", X"00007E", X"000099", X"0000B3", X"0000CD", X"0019EB", X"0034FF", X"0050FF", X"006BFF", X"0386FF", X"1EA1FF", X"3ABCFF", X"55D8FF", X"70F3FF", 
	X"00004B", X"000065", X"000080", X"00009A", X"0000B4", X"0000CE", X"0000E8", X"000BFF", X"0027FF", X"0042FF", X"0D5DFF", X"2878FF", X"4493FF", X"5FAEFF", X"7ACAFF", X"95E5FF", 
	X"000061", X"00007B", X"000095", X"0000AF", X"0000CA", X"0000E4", X"0000FE", X"0000FF", X"011AFF", X"1C36FF", X"3751FF", X"526CFF", X"6D87FF", X"89A2FF", X"A4BDFF", X"BFD9FF", 
	X"00006D", X"000087", X"0000A1", X"0000BC", X"0000D6", X"0000F0", X"0000FF", X"1200FF", X"2C12FF", X"482DFF", X"6348FF", X"7E63FF", X"997EFF", X"B499FF", X"D0B5FF", X"EBD0FF"
  );

begin

  p_rom : process(ADDR)
  begin
     DATA <= ROM(to_integer(unsigned(ADDR)));
  end process;

end RTL;

