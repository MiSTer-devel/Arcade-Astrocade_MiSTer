library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity VotraxSound is
    generic (
        CLK_HZ  : integer := 28_000_000
    );
    port (
        I_VOTRAX_DATA : in  std_logic_vector(7 downto 0);
        I_VOTRAX_STB  : in  std_logic;
        O_VOTRAX_AR   : out std_logic;

        s_enable      : in  std_logic;
        audio_out     : out signed(17 downto 0);
        audio_valid   : out std_logic;

        I_RESET_L     : in  std_logic;
        CLK           : in  std_logic
    );
end entity VotraxSound;

architecture RTL of VotraxSound is

    -- ================================================================
    -- Bitfeld-Dekodierung aus I_VOTRAX_DATA
    -- ================================================================
    signal phoneme   : std_logic_vector(5 downto 0);
    signal clk_sel   : std_logic;  -- 0=720kHz, 1=780kHz
    signal infl_sel  : std_logic;  -- 0=inflection "10", 1=inflection "00"

    signal inflection : std_logic_vector(1 downto 0);

    -- ================================================================
    -- DDS: SC01 speech clock generator
    -- speech_clock: clk_sel=0 -> 756kHz, clk_sel=1 -> 782kHz
    -- sclock_en rate = speech_clock / 18
    -- ================================================================
    constant SC01_HZ_0 : integer := 756000;
    constant SC01_HZ_1 : integer := 782000;

    -- DDS increment: inc = sc01_hz * 2^32 / (18 * CLK_HZ)
    constant INC_SC01_0 : unsigned(31 downto 0) :=
        to_unsigned(integer(real(SC01_HZ_0) * 4294967296.0 / (18.0 * real(CLK_HZ))), 32);
    constant INC_SC01_1 : unsigned(31 downto 0) :=
        to_unsigned(integer(real(SC01_HZ_1) * 4294967296.0 / (18.0 * real(CLK_HZ))), 32);

    -- Resampler phase_inc: 32768 * 48000 * 18 / sc01_hz
    constant PHASE_INC_0 : unsigned(15 downto 0) :=
        to_unsigned(integer(32768.0 * 48000.0 * 18.0 / real(SC01_HZ_0)), 16);
    constant PHASE_INC_1 : unsigned(15 downto 0) :=
        to_unsigned(integer(32768.0 * 48000.0 * 18.0 / real(SC01_HZ_1)), 16);

    signal inc_sc01       : unsigned(31 downto 0);
    signal phase_sc01     : unsigned(31 downto 0) := (others => '0');
    signal sclock_en      : std_logic := '0';
    signal cclock_en      : std_logic := '0';
    signal phase_inc_resamp : unsigned(15 downto 0);

    -- ================================================================
    -- SC01A audio
    -- ================================================================
    signal ar            : std_logic;
    signal sc01_audio    : signed(17 downto 0);
    signal sc01_av       : std_logic;

    -- ================================================================
    -- Resampler (sc01 rate -> 48kHz)
    -- ================================================================
    signal audio_48k       : signed(17 downto 0);
    signal audio_48k_valid : std_logic;

begin

    -- Bitfeld-Zuweisung
    phoneme   <= I_VOTRAX_DATA(5 downto 0);
    clk_sel   <= I_VOTRAX_DATA(6);
    infl_sel  <= I_VOTRAX_DATA(7);

    -- Intonations-Auswahl
    inflection <= "00" when infl_sel = '1' else "10";

    -- DDS increment und Resampler phase_inc aus clk_sel
    inc_sc01        <= INC_SC01_1     when clk_sel = '1' else INC_SC01_0;
    phase_inc_resamp <= PHASE_INC_1   when clk_sel = '1' else PHASE_INC_0;

    -- ================================================================
    -- DDS: SC01 sample tick generator
    -- ================================================================
    process (CLK)
        variable sum    : unsigned(32 downto 0);
        variable toggle : std_logic := '0';
    begin
        if rising_edge(CLK) then
            if I_RESET_L = '0' then
                phase_sc01 <= (others => '0');
                sclock_en  <= '0';
                cclock_en  <= '0';
                toggle     := '0';
            else
                sum        := ('0' & phase_sc01) + ('0' & inc_sc01);
                phase_sc01 <= sum(31 downto 0);
                sclock_en  <= sum(32);
                cclock_en  <= '0';
                if sum(32) = '1' then
                    toggle := not toggle;
                    if toggle = '1' then
                        cclock_en <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- ================================================================
    -- SC01-A core
    -- ================================================================
    U_SC01A : entity work.sc01a
        generic map (
            IS_SC01A => 0
        )
        port map (
            clk        => CLK,
            reset_n    => I_RESET_L,
            p          => phoneme,
            inflection => inflection,
            stb        => I_VOTRAX_STB,
            ar         => ar,
            sclock_en  => sclock_en,
            cclock_en  => cclock_en,
            audio_out  => sc01_audio,
            audio_valid => sc01_av
        );

    -- ================================================================
    -- Resampler: sc01 variable rate -> 48kHz
    -- ================================================================
    U_RESAMP : entity work.sc01a_resamp
        generic map (
            CLK_HZ      => CLK_HZ,
            SAMPLE_BITS => 18
        )
        port map (
            clk          => CLK,
            reset_n      => I_RESET_L,
            s_in         => sc01_audio,
            s_valid      => sc01_av,
            phase_inc_in => phase_inc_resamp,
            s_out        => audio_48k,
            s_out_valid  => audio_48k_valid
        );

    -- ================================================================
    -- Ausgangszuweisungen
    -- ================================================================
    O_VOTRAX_AR <= ar;
    audio_out <= audio_48k;
    audio_valid <= audio_48k_valid;

end architecture RTL;
