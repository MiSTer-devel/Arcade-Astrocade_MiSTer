-- bally_rc_filter.vhd
-- Bally Astrocade output lowpass filter for Votrax SC01-A
--
-- Models the 4 cascaded RC lowpass stages on the Wizard of Wor PCB:
--   4 × (R=110kΩ, C=560pF)  →  fc ≈ 2584 Hz
--
-- Implemented as 4 cascaded 1st-order IIR sections:
--   y[n] = k·x[n] + (1-k)·y[n-1]
--
-- Coefficients (Q15, fs=48kHz):
--   k    = 9403   (= round(k * 32768))
--   1-k  = 23365  (= 32768 - k, exact complement)
--
-- Pipelined: one stage per clock cycle, 4-cycle latency.
-- 18-bit version: all data paths widened from 16 to 18 bits.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bally_rc_filter is
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        s_in        : in  signed(17 downto 0);
        s_valid     : in  std_logic;
        s_out       : out signed(17 downto 0);
        s_out_valid : out std_logic
    );
end entity;

architecture rtl of bally_rc_filter is

    -- Q15 coefficients: k + (1-k) = 32768 exactly
    constant RC_K  : integer := 9403;          -- k   * 2^15
    constant RC_KM : integer := 32768 - RC_K;  -- (1-k) * 2^15 = 23365

    type pipe_data_t is array(0 to 3) of signed(17 downto 0);

    -- inter-stage pipeline register + 4-bit valid shift register
    signal pipe_data : pipe_data_t := (others => (others => '0'));

    -- One RC stage: y[n] = (RC_K*x + RC_KM*y_prev) >> 15
    -- Input range ±131071 → output guaranteed ±131071 (coefficients sum to 32768)
    function rc_stage(x : signed(17 downto 0); y_prev : signed(17 downto 0))
                      return signed is
        variable prod1 : signed(35 downto 0);
        variable prod2 : signed(35 downto 0);
        variable acc   : signed(36 downto 0);
    begin
        prod1 := x      * to_signed(RC_K,  18);
        prod2 := y_prev * to_signed(RC_KM, 18);
        acc   := resize(prod1, 37) + resize(prod2, 37);
        -- shift right 15, result fits in 18 bits
        return acc(32 downto 15);
    end function;

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                s_out      <= (others => '0');
                s_out_valid <= '0';
            else
                s_out_valid <= '0';

                if s_valid = '1' then
                    pipe_data(0) <= rc_stage(s_in, pipe_data(0));
                    pipe_data(1) <= rc_stage(pipe_data(0), pipe_data(1));
                    pipe_data(2) <= rc_stage(pipe_data(1), pipe_data(2));
                    pipe_data(3) <= rc_stage(pipe_data(2), pipe_data(3));
                    s_out  <= pipe_data(3);
                    s_out_valid <= '1';
                end if;
            end if;
        end if;
    end process;

end architecture;
