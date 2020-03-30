library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity GRAY is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(5 downto 0);
	data : out std_logic_vector(7 downto 0);
	posi : out std_logic_vector(11 downto 0)
);
end entity;

architecture prom of GRAY is
	type gray is array(0 to  63) of std_logic_vector(7 downto 0);
	signal lookup: gray := (
			X"20",X"21",X"23",X"22",X"26",X"27",X"25",X"24",
			X"2c",X"2d",X"2f",X"2e",X"2a",X"2b",X"29",X"28",
			X"38",X"39",X"3b",X"3a",X"3e",X"3f",X"3d",X"3c",
			X"34",X"35",X"37",X"36",X"32",X"33",X"31",X"30",
			X"10",X"11",X"13",X"12",X"16",X"17",X"15",X"14",
			X"1c",X"1d",X"1f",X"1e",X"1a",X"1b",X"19",X"18",
			X"08",X"09",X"0b",X"0a",X"0e",X"0f",X"0d",X"0c",
			X"04",X"05",X"07",X"06",X"02",X"03",X"01",X"00");

begin
process(clk)
begin
	if rising_edge(clk) then
		-- Grays binary as expected by Seawolf
		data <= lookup(to_integer(unsigned(addr)));
		-- Screen position for scope
		if (addr(5) = '1') then
			posi <= std_logic_vector((unsigned(addr(5 downto 0)) * 10) - 40);
		else
			posi <= std_logic_vector((unsigned(addr(5 downto 0)) * 11) - 72);
		end if;
	end if;
end process;

end architecture;

