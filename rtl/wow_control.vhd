library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity WowMapping is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(2 downto 0);
	dir0 : out std_logic;
	dir1 : out std_logic;
	move : out std_logic
);
end entity;

architecture prom of WowMapping is
	type look is array(0 to  7) of std_logic_vector(7 downto 0);
	signal lookup: look := (
		X"05",X"01",X"01",X"00",X"00",X"02",X"02",X"06");

begin
process(clk)
begin
	if rising_edge(clk) then
		-- Delta as expected by eBases
		dir0 <= lookup(to_integer(unsigned(addr)))(0);
		dir1 <= lookup(to_integer(unsigned(addr)))(1);
		move <= lookup(to_integer(unsigned(addr)))(2);
	end if;
end process;

end architecture;

