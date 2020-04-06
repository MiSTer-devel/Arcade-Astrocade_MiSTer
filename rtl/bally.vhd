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
  use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;

entity BALLY is
  port (
    O_AUDIO_L          : out   std_logic_vector(7 downto 0);
	 O_AUDIO_R          : out   std_logic_vector(7 downto 0);

    O_VIDEO_R          : out   std_logic_vector(3 downto 0);
    O_VIDEO_G          : out   std_logic_vector(3 downto 0);
    O_VIDEO_B          : out   std_logic_vector(3 downto 0);
    O_CE_PIX           : out   std_logic;
    O_HBLANK_V         : out   std_logic;
    O_VBLANK_V         : out   std_logic;

    O_HSYNC            : out   std_logic;
    O_VSYNC            : out   std_logic;
    O_COMP_SYNC_L      : out   std_logic;
    O_FPSYNC           : out   std_logic;
	 
	 -- Needed for Scope on Seawolf2
	 O_HCOUNT           : out   std_logic_vector(8 downto 0);
	 O_VCOUNT           : out   std_logic_vector(10 downto 0);

	 -- Arcade Rom
	 I_HIGH_ROM			  : in    std_logic; -- ROM at 8000-CFFF ?
 	 I_EXTRA_ROM	     : in    std_logic; -- ROM at D000-DFFF ?
	 I_SPARKLE          : in    std_logic; -- Sparkle Circuit
	 I_LIGHTPEN         : in    std_logic; -- Light pen interrupt
	 I_GORF             : in    std_logic; -- Gorf (seperate RAM access for CPU opcodes)

    O_BIOS_ADDR        : out   std_logic_vector(15 downto 0);
    I_BIOS_DATA        : in    std_logic_vector( 7 downto 0);
    O_BIOS_CS_L        : out   std_logic;

    -- exp slot (subset for now)
    O_EXP_ADDR         : out   std_logic_vector(15 downto 0);
    O_EXP_DATA         : out   std_logic_vector( 7 downto 0);
    I_EXP_DATA         : in    std_logic_vector( 7 downto 0);
    I_EXP_OE_L         : in    std_logic; -- expansion slot driving data bus

    O_EXP_M1_L         : out   std_logic;
    O_EXP_MREQ_L       : out   std_logic;
    O_EXP_IORQ_L       : out   std_logic;
    O_EXP_WR_L         : out   std_logic;
    O_EXP_RD_L         : out   std_logic;
    --
    O_SWITCH_COL       : out   std_logic_vector(7 downto 0);
    I_SWITCH_ROW       : in    std_logic_vector(7 downto 0);
    O_POT              : out   std_logic_vector(3 downto 0);
    I_POT              : in    std_logic_vector(7 downto 0);
	 O_TRACK_S		     : out   std_logic_vector(1 downto 0);
    --
    I_RESET_L          : in    std_logic;
    ENA                : in    std_logic;
    CLK                : in    std_logic	 
);
end;

architecture RTL of BALLY is

  --  signals
  signal cpu_ena          : std_logic;
  signal pix_ena          : std_logic;
  signal cpu_ena_gated    : std_logic;
  --
  signal cpu_m1_l         : std_logic;
  signal cpu_mreq_l       : std_logic;
  signal cpu_iorq_l       : std_logic;
  signal cpu_rd_l         : std_logic;
  signal cpu_wr_l         : std_logic;
  signal cpu_rfsh_l       : std_logic;
  signal cpu_halt_l       : std_logic;
  signal cpu_wait_l       : std_logic;
  signal cpu_int_l        : std_logic;
  signal cpu_nmi_l        : std_logic;
  signal cpu_busrq_l      : std_logic;
  signal cpu_busak_l      : std_logic;
  signal cpu_addr         : std_logic_vector(15 downto 0);
  signal cpu_data_out     : std_logic_vector(7 downto 0);
  signal cpu_data_in      : std_logic_vector(7 downto 0);

  signal mc1              : std_logic;
  signal mc0              : std_logic;
  --signal mx_bus           : std_logic_vector(7 downto 0); -- cpu to customs
  signal mx_addr          : std_logic_vector(7 downto 0); -- customs to cpu
  signal mx_addr_oe_l     : std_logic;
  signal mx_data          : std_logic_vector(7 downto 0); -- customs to cpu
  signal mx_data_oe_l     : std_logic;
  signal mx_io            : std_logic_vector(7 downto 0); -- customs to cpu
  signal mx_io_oe_l       : std_logic;

  signal ma_bus           : std_logic_vector(15 downto 0);
  signal md_bus_out       : std_logic_vector(7 downto 0);
  signal md_bus_in        : std_logic_vector(7 downto 0);
  signal md_bus_in_x      : std_logic_vector(7 downto 0);
  signal daten_l          : std_logic;
  signal datwr            : std_logic;

  signal horiz_dr         : std_logic;
  signal vert_dr          : std_logic;
  signal wrctl_l          : std_logic;
  signal ltchdo           : std_logic;
  --
  -- expansion
  signal exp_buzoff_l     : std_logic;
  signal exp_sysen        : std_logic;
  signal exp_casen        : std_logic;

  signal sys_cs_l         : std_logic;
  signal rom0_dout        : std_logic_vector(7 downto 0);
  signal rom1_dout        : std_logic_vector(7 downto 0);
  signal rom_dout         : std_logic_vector(7 downto 0);
  signal cas_cs_l         : std_logic;

  signal video_r          : std_logic_vector(3 downto 0);
  signal video_g          : std_logic_vector(3 downto 0);
  signal video_b          : std_logic_vector(3 downto 0);
  signal hsync            : std_logic;
  signal vsync            : std_logic;
  signal fpsync           : std_logic;
  signal serial           : std_logic_vector(1 downto 0);
  
  signal pat_addr         : std_logic_vector(15 downto 0);
  signal pat_data_o       : std_logic_vector(7 downto 0);
  signal pat_data_i       : std_logic_vector(7 downto 0);	
  signal pat_RD_L         : std_logic;
  signal pat_WR_L         : std_logic;
  signal pat_MR_L         : std_logic;
  signal patram           : std_logic_vector(7 downto 0);	

  signal addr_bus         : std_logic_vector(15 downto 0);
  signal data_bus         : std_logic_vector(7 downto 0);
  signal mux_rd_l         : std_logic;
  signal mux_wr_l         : std_logic;
  signal mux_mr_l         : std_logic;
  signal mux_io_l		     : std_logic;
  signal mux_rfsh_l		  : std_logic;
  signal mux_M1           : std_logic;
  signal mux_pat_out      : std_logic_vector(7 downto 0);
  signal mux_int          : std_logic;
  
  signal luma             : std_logic_vector(3 downto 0);
  signal luma_t           : std_logic_vector(3 downto 0);
  signal lightpen_h       : std_logic_vector(7 downto 0);	
  signal lightpen_v       : std_logic_vector(7 downto 0);	
  
  signal state            : std_logic_vector(3 downto 0);
begin
  --
  -- cpu
  --
  --  doc
  -- memory map
  -- 0000 - 0fff os rom / magic ram
  -- 1000 - 1fff os rom
  -- 2000 - 3fff cas rom
  -- 4000 - 4fff screen ram

  -- in hi res screen ram from 4000 - 7fff
  -- magic ram 0000 - 3fff

  -- screen
  -- low res 40 bytes / line (160 pixels, 2 bits per pixel)
  -- vert res 102 lines

  -- high res 80 bytes (320 pixels) and 204 lines.
  -- addr 0 top left. lsb 2 bits describe right hand pixel

  -- expansion sigs
  exp_buzoff_l <= '1'; -- pull up
  exp_sysen    <= '1'; -- pull up
  exp_casen    <= '1'; -- pull up

  -- other cpu signals
  cpu_nmi_l   <= '1';
  
  cpu_ena_gated <= ENA and cpu_ena;
  u_cpu : entity work.T80s
          port map (
				  RESET_n => I_RESET_L,
              CLK     => CLK,
              CEN     => cpu_ena_gated,
              WAIT_n  => cpu_wait_l,
              INT_n   => mux_int,	-- keep high when pattern board running
              NMI_n   => cpu_nmi_l,
              BUSRQ_n => cpu_busrq_l,
              M1_n    => cpu_m1_l,
              MREQ_n  => cpu_mreq_l,
              IORQ_n  => cpu_iorq_l,
              RD_n    => cpu_rd_l,
              WR_n    => cpu_wr_l,
              RFSH_n  => cpu_rfsh_l,
              HALT_n  => cpu_halt_l,
              BUSAK_n => cpu_busak_l,
              A       => cpu_addr,
              DI      => cpu_data_in,
              DO      => cpu_data_out
  );

				
  --CPU data when CPU running, pattern data otherwise
  addr_bus   <= cpu_addr when cpu_busak_l='1' else pat_addr;
  data_bus   <= cpu_data_out when cpu_busak_l='1' else pat_data_o;
  pat_data_i <= cpu_data_out when cpu_busak_l='1' else mux_pat_out;
		
  mux_rd_l   <= cpu_rd_l when cpu_busak_l='1' else pat_RD_L;
  mux_wr_l   <= cpu_wr_l when cpu_busak_l='1' else pat_WR_L;
  mux_mr_l   <= cpu_mreq_l when cpu_busak_l='1' else pat_MR_L;
  
  mux_io_l   <= cpu_iorq_l when cpu_busak_l='1' else '1';
  mux_rfsh_l <= cpu_rfsh_l when cpu_busak_l='1' else '1';
  mux_M1     <= cpu_m1_l when cpu_busak_l='1' else '1';
  mux_int    <= cpu_int_l when cpu_busak_l='1' else '1';
  
  --
  -- primary addr decode
  --
  p_mem_decode_comb : process(mux_rfsh_l, mux_rd_l, mux_mr_l, addr_bus, exp_sysen, exp_casen,I_EXTRA_ROM,I_HIGH_ROM,I_GORF,cpu_addr)
    variable decode : std_logic;
  begin

    sys_cs_l <= '1'; -- system rom
    cas_cs_l <= '1'; -- gorf RAM access rom

    decode := '0';
    if (mux_rd_l = '0') and (mux_mr_l = '0') and (addr_bus(14) = '0' or (I_EXTRA_ROM = '1' and addr_bus(15 downto 13) = "110")) then
      decode := '1';
    end if;

  	 sys_cs_l <= not (decode and (not addr_bus(15) or I_HIGH_ROM) and exp_sysen);
	 
	 -- Gorf access to run code from RAM ($D080-$D085)
	 if (I_GORF = '1') and (mux_rd_l = '0') and (mux_mr_l = '0') and (cpu_addr(15 downto 3) = "1101000010000") and (cpu_addr(2 downto 0) /= "101") and (cpu_addr(2 downto 0) /= "111") then 
		cas_cs_l <= '0';
	 end if;

  end process;

  -- Pass BIOS and pixel clock to the top level
  O_BIOS_ADDR <= addr_bus(15 downto 0); -- cpu_addr(15 downto 0);
  O_BIOS_CS_L <= sys_cs_l;
  rom_dout <= I_BIOS_DATA;
  O_CE_PIX <= pix_ena;

  p_cpu_src_data_mux : process(rom_dout, sys_cs_l, cas_cs_l, I_EXP_OE_L, I_EXP_DATA, exp_buzoff_l,
                               mx_addr_oe_l, mx_addr, mx_data_oe_l, mx_data, mx_io_oe_l, mx_io, patram)
  begin
    -- nasty mux
    if (I_EXP_OE_L = '0') or (exp_buzoff_l = '0') then
      cpu_data_in <= I_EXP_DATA;
    elsif (sys_cs_l = '0') then
      cpu_data_in <= rom_dout;
	 elsif (cas_cs_l = '0') then
	   cpu_data_in <= patram;
    elsif (mx_addr_oe_l = '0') then
      cpu_data_in <= mx_addr;
    elsif (mx_data_oe_l = '0') then
      cpu_data_in <= mx_data;
    elsif (mx_io_oe_l = '0') then
      cpu_data_in <= mx_io;
    else
      cpu_data_in <= x"FF";
    end if;
  end process;

  -- simple mux - rom data or ram data for pattern board
  p_pat_src_data_mux : process(rom_dout, sys_cs_l, patram)
  begin
		if (sys_cs_l = '0') then
			mux_pat_out <= rom_dout;
		else
			mux_pat_out <= patram;
		end if;
  end process;
  
  u_addr : entity work.BALLY_ADDR
    port map (
      I_MXA             => addr_bus, -- cpu_addr,
      I_MXD             => cpu_data_out, -- was data_bus
      O_MXD             => mx_addr,
      O_MXD_OE_L        => mx_addr_oe_l,

      -- cpu control signals
      I_RFSH_L          => mux_rfsh_l, -- cpu_rfsh_l,
      I_M1_L            => mux_M1,     -- cpu_m1_l,
      I_RD_L            => mux_rd_l,   -- cpu_rd_l,
      I_MREQ_L          => mux_mr_l,   -- cpu_mreq_l,
      I_IORQ_L          => mux_io_l,   -- cpu_iorq_l,
      O_WAIT_L          => cpu_wait_l,
      O_INT_L           => cpu_int_l,

      -- custom
      I_HORIZ_DR        => horiz_dr,
      I_VERT_DR         => vert_dr,
      O_WRCTL_L         => wrctl_l, -- Write flag
      O_LTCHDO          => ltchdo,
		O_TRACK_S         => O_TRACK_S,

      -- dram address
      O_MA              => ma_bus,
      O_RAS             => open,
		
      -- misc
      I_LIGHTPEN        => I_LIGHTPEN,
		O_LP_V            => lightpen_v,
		O_LP_H            => lightpen_h,

      -- clks
      I_CPU_ENA         => cpu_ena,
      I_PIX_ENA         => pix_ena,
      ENA               => ENA,
      CLK               => CLK
      );

  u_data : entity work.BALLY_DATA
    port map (
      I_MXA             => addr_bus, -- cpu_addr,
      I_MXD             => data_bus, -- cpu_data_out,
      O_MXD             => mx_data,
      O_MXD_OE_L        => mx_data_oe_l,

      -- cpu control signals
      I_M1_L            => mux_M1,   -- cpu_m1_l,
      I_RD_L            => mux_rd_l, -- cpu_rd_l,
      I_MREQ_L          => mux_mr_l, -- cpu_mreq_l,
      I_IORQ_L          => mux_io_l, -- cpu_iorq_l,
      I_RESET_L         => I_RESET_L,

      -- memory
      O_DATEN_L         => daten_l,
      O_DATWR           => datwr, -- makes dp ram timing easier
      I_MDX             => md_bus_in_x,
      I_MD              => md_bus_in,
      O_MD              => md_bus_out,
      O_MD_OE_L         => open,
      -- custom
      O_MC1             => mc1,
      O_MC0             => mc0,

      O_HORIZ_DR        => horiz_dr,
      O_VERT_DR         => vert_dr,
      I_WRCTL_L         => wrctl_l,
      I_LTCHDO          => ltchdo,

      O_SERIAL          => serial,

      O_VIDEO_R         => video_r,
      O_VIDEO_G         => video_g,
      O_VIDEO_B         => video_b,
      O_HSYNC           => hsync,
      O_VSYNC           => vsync,
      O_HBLANK          => O_HBLANK_V,
      O_VBLANK          => O_VBLANK_V,
      O_FPSYNC          => fpsync,
		-- Needed for Scope on Seawolf2
		O_HCOUNT          => O_HCOUNT,
		O_VCOUNT          => O_VCOUNT,
		-- Lightpen info
		I_LP_V            => lightpen_v,
		I_LP_H            => lightpen_h,
		-- clks
      O_CPU_ENA         => cpu_ena, -- cpu clock ena
      O_PIX_ENA         => pix_ena, -- pixel clock ena
      ENA               => ENA,
      CLK               => CLK
      );

  -- Pattern board does not touch, so leave as CPU info for now.
  u_io   : entity work.BALLY_IO
    port map (
      I_MXA             => cpu_addr,
      I_MXD             => cpu_data_out,
      O_MXD             => mx_io,
      O_MXD_OE_L        => mx_io_oe_l,

      -- cpu control signals
      I_M1_L            => cpu_m1_l,
      I_RD_L            => cpu_rd_l,
      I_IORQ_L          => cpu_iorq_l,
      I_RESET_L         => I_RESET_L,

      -- no pots - student project ? :)

      -- switches
      O_SWITCH          => O_SWITCH_COL,
      I_SWITCH          => I_SWITCH_ROW,
      O_POT_SEL         => O_POT,
      I_POT_DATA        => I_POT,

      -- audio
      O_AUDIO_L         => O_AUDIO_L,
		O_AUDIO_R         => O_AUDIO_R,

      -- clks
      I_CPU_ENA         => cpu_ena,
      I_PIX_ENA         => pix_ena, -- real chip doesn't get pixel clock
      ENA               => ENA,
      CLK               => CLK
      );

  PCB : entity work.BALLY_PATTERN
    port map (
      I_MXA             => cpu_addr,
      I_MXD             => pat_data_i,

		-- Pattern board outputs
		O_MXA					=> pat_addr,
		O_MXD					=> pat_data_o,
		O_RD_L            => pat_RD_L,
		O_WR_L            => pat_WR_L,
		O_MR_L            => pat_MR_L,

      -- cpu control signals
      I_M1_L            => cpu_m1_l,
      I_RD_L            => cpu_rd_l,
      I_MREQ_L          => cpu_mreq_l,
      I_IORQ_L          => cpu_iorq_l,
      I_RESET_L         => I_RESET_L,
      I_WAIT_L          => cpu_wait_l,
		I_BUSACK_L        => cpu_busak_l,
 		O_BUSRQ_L         => cpu_busrq_l,

		-- clks
      I_CPU_ENA         => cpu_ena_gated, -- cpu clock ena
      ENA               => ENA,
      CLK               => CLK
  );

  
  -- Sparkle Circuit
  Spark : entity work.BALLY_SPARKLE
  port map (
	I_MXA             => cpu_addr,
	I_MXD             => cpu_data_out,

	-- cpu control signals
	I_M1_L            => cpu_m1_l,
	I_RD_L            => cpu_rd_l,
	I_IORQ_L          => cpu_iorq_l,
	I_RESET_L         => I_RESET_L,

	 -- Screen Info
	I_SCREENSTART     => vsync,
	I_CODE            => serial,
   O_LUMA            => luma,
	-- clks
	I_CPU_ENA         => cpu_ena, -- cpu clock ena
	ENA               => ENA,
	CLK               => CLK
);

  p_video_out : process
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      O_HSYNC <= hsync;
      O_VSYNC <= vsync;
      O_COMP_SYNC_L <= (not vsync) and (not hsync);

		if I_SPARKLE='0' then
			O_VIDEO_R <= video_r;
			O_VIDEO_G <= video_g;
			O_VIDEO_B <= video_b;
			
			-- Test Gorf colours actually being set to something!
			-- O_VIDEO_R <= Serial(1) & Serial(1) & Serial(0) & Serial(0);
		else
			  O_VIDEO_R <= (video_r and luma_t);
			  O_VIDEO_G <= (video_g and luma_t);
			  O_VIDEO_B <= (video_b and luma_t);
--			 case luma_t(3 downto 2) is
--			 
--				 when "11" => -- White
--								  O_VIDEO_R <= "1111";
--								  O_VIDEO_G <= "1111";
--								  O_VIDEO_B <= "1111";
--				 when "10" => -- B.Grey
--								  O_VIDEO_R <= "1011";
--								  O_VIDEO_G <= "1011";
--								  O_VIDEO_B <= "1011";
--				 when others =>
--								  if luma_t(3 downto 0) = "0000" then
--								     -- Black
--									  O_VIDEO_R <= "0000";
--									  O_VIDEO_G <= "0000";
--									  O_VIDEO_B <= "0000";
--								  else
--									  O_VIDEO_R <= (video_r and (luma_t(2 downto 0) & "1"));
--									  O_VIDEO_G <= (video_g and (luma_t(2 downto 0) & "1"));
--									  O_VIDEO_B <= (video_b and (luma_t(2 downto 0) & "1"));
--								  end if;
--			end case;
		end if;
      O_FPSYNC  <= fpsync;
		luma_t <= luma; -- delay 1 cycle
    end if;
  end process;

  u_rams : entity work.BALLY_RAMS
    port map (
    ADDR     => ma_bus,
    DIN      => md_bus_out,
    DOUT     => md_bus_in,
    DOUTX    => md_bus_in_x,
    WE       => datwr,
    WE_ENA_L => daten_l, -- only used for write
    ENA      => ENA,
    CLK      => CLK,
	 -- Pattern board access to read ram (also used when Gorf runs code from RAM)
	 PAT_ADDR => addr_bus,
	 PAT_DATA => patram
    );

  -- drive exp
  -- all sigs should be bi-dir as exp slot devices can take control of the bus
  -- this will be ok for the test cart
  O_EXP_ADDR         <= cpu_addr;
  O_EXP_DATA         <= cpu_data_out; -- not quite right, should be resolved data bus so exp slot can read customs / ram
  O_EXP_M1_L         <= cpu_m1_l;
  O_EXP_MREQ_L       <= cpu_mreq_l;
  O_EXP_IORQ_L       <= cpu_iorq_l;
  O_EXP_WR_L         <= cpu_wr_l;
  O_EXP_RD_L         <= cpu_rd_l;


end RTL;
