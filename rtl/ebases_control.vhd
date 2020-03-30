library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity AnaloguetoDelta is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(3 downto 0);
	data : out std_logic_vector(7 downto 0)
);
end entity;

architecture prom of AnaloguetoDelta is
	type look is array(0 to  15) of std_logic_vector(7 downto 0);
	signal lookup: look := (
			X"FB",X"FB",X"FC",X"FD",X"FE",X"FF",X"00",X"00",
			X"00",X"00",X"01",X"02",X"03",X"04",X"05",X"05");

begin
process(clk)
begin
	if rising_edge(clk) then
		-- Delta as expected by eBases
		data <= lookup(to_integer(unsigned(addr)));
	end if;
end process;

end architecture;

