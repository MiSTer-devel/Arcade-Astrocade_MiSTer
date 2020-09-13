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
  --use ieee.std_logic_arith.all;
  use ieee.std_logic_unsigned.all;
  use IEEE.numeric_std.all;

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
	 I_GORF             : in    std_logic; -- Gorf (seperate RAM access for CPU opcodes) and Samples for Votrax
	 I_SEAWOLF          : in    std_logic; -- SeaWolf samples

	 O_SAMP_L           : out   std_logic_vector(15 downto 0);
	 O_SAMP_R           : out   std_logic_vector(15 downto 0);
	 O_SAMP_ADDR        : out   std_logic_vector(23 downto 0);
	 O_SAMP_READ        : out   std_logic;
	 I_SAMP_DATA        : in    std_logic_vector(15 downto 0);
	 O_SAMP_BUSY        : out   std_logic;
	 I_SAMP_READY       : in    std_logic; -- DDRAM use only
	 
    O_BIOS_ADDR        : out   std_logic_vector(15 downto 0);
    I_BIOS_DATA        : in    std_logic_vector( 7 downto 0);
    O_BIOS_CS_L        : out   std_logic;
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

	COMPONENT SeawolfSound PORT (
		cpu_addr  	: in  std_logic_vector(15 downto 0);
		cpu_data  	: in  std_logic_vector(7 downto 0);
		-- Sample Info
		s_enable  	: in  std_logic;
		s_addr    	: out std_logic_vector(23 downto 0);
		s_data    	: in  std_logic_vector(15 downto 0);
		s_read    	: out std_logic;
		s_ready     : in  std_logic;
		-- Sounds
		audio_out_l : out std_logic_vector(15 downto 0);
		audio_out_r : out std_logic_vector(15 downto 0);
		-- cpu
		I_RESET_L 	: in    std_logic;
		I_M1_L    	: in    std_logic;
		I_RD_L    	: in    std_logic;
		I_IORQ_L  	: in    std_logic;
		 -- clks
		I_CPU_ENA 	: in   std_logic; -- cpu clock ena
		ENA       	: in   std_logic; 
		CLK       	: in   std_logic
	);  -- sys clock (14 Mhz)
	END COMPONENT;

	COMPONENT GorfSound PORT (
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
		CLK       	: in  std_logic
	);
	END COMPONENT;

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
  signal cpu_hl			  : std_logic_vector(15 downto 0);

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
  signal pat_MR_L         : std_logic;
  signal patram           : std_logic_vector(7 downto 0);	

  signal addr_bus         : std_logic_vector(15 downto 0);
  signal data_bus         : std_logic_vector(7 downto 0);
  signal mux_rd_l         : std_logic;
  signal mux_mr_l         : std_logic;
  signal mux_io_l		     : std_logic;
  signal mux_rfsh_l		  : std_logic;
  signal mux_M1           : std_logic;
  signal mux_pat_out      : std_logic_vector(7 downto 0);
  signal mux_int          : std_logic;
  
  signal luma             : std_logic_vector(4 downto 0);
  signal luma_t           : std_logic_vector(4 downto 0);
  signal backcol          : std_logic_vector(11 downto 0);
  signal lightpen_h       : std_logic_vector(7 downto 0);	
  signal lightpen_v       : std_logic_vector(7 downto 0);	
  
  signal state            : std_logic_vector(3 downto 0);
  
  signal SW_Sampl_L       : std_logic_vector(15 downto 0);
  signal SW_Sampl_R       : std_logic_vector(15 downto 0);
  signal SW_Sampl_A       : std_logic_vector(23 downto 0);
  signal GF_Sampl_L       : std_logic_vector(15 downto 0);
  signal GF_Sampl_R       : std_logic_vector(15 downto 0);
  signal GF_Sampl_A       : std_logic_vector(23 downto 0);
  signal SW_Read          : std_logic;
  signal GF_Read          : std_logic;
  signal GF_Votrax        : std_logic;
  
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
              DO      => cpu_data_out,
				  HL      => cpu_hl
  );

				
  --CPU data when CPU running, pattern data otherwise
  addr_bus   <= cpu_addr when cpu_busak_l='1' else pat_addr;
  data_bus   <= cpu_data_out when cpu_busak_l='1' else pat_data_o;
  pat_data_i <= cpu_data_out when cpu_busak_l='1' else mux_pat_out;
		
  mux_rd_l   <= cpu_rd_l when cpu_busak_l='1' else pat_RD_L;
  mux_mr_l   <= cpu_mreq_l when cpu_busak_l='1' else pat_MR_L;
  
  mux_io_l   <= cpu_iorq_l when cpu_busak_l='1' else '1';
  mux_rfsh_l <= cpu_rfsh_l when cpu_busak_l='1' else '1';
  mux_M1     <= cpu_m1_l when cpu_busak_l='1' else '1';
  mux_int    <= cpu_int_l when cpu_busak_l='1' else '1';
  
  --
  -- primary addr decode
  --
  p_mem_decode_comb : process(mux_rfsh_l, mux_rd_l, mux_mr_l, addr_bus, I_EXTRA_ROM,I_HIGH_ROM,I_GORF,cpu_addr)
    variable decode : std_logic;
  begin

    sys_cs_l <= '1'; -- system rom
    cas_cs_l <= '1'; -- gorf RAM access rom

    decode := '0';
    if (mux_rd_l = '0') and (mux_mr_l = '0') and (addr_bus(14) = '0' or (I_EXTRA_ROM = '1' and addr_bus(15 downto 13) = "110")) then
      decode := '1';
    end if;

  	 sys_cs_l <= not (decode and (not addr_bus(15) or I_HIGH_ROM));
	 
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

  p_cpu_src_data_mux : process(rom_dout, sys_cs_l, cas_cs_l, mx_addr_oe_l, mx_addr, mx_data_oe_l, mx_data, mx_io_oe_l, mx_io, patram)
  begin
    -- nasty mux
	 if (sys_cs_l = '0') then
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
  u_io1  : entity work.BALLY_IO
    port map (
		I_BASE            => "0001", -- Base Address of chip
		
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
      O_AUDIO           => O_AUDIO_L,

      -- clks
      I_CPU_ENA         => cpu_ena,
      I_PIX_ENA         => pix_ena, -- real chip doesn't get pixel clock
      ENA               => ENA,
      CLK               => CLK
      );

  -- Second IO chip (for Stereo games)
  u_io2  : entity work.BALLY_IO
    port map (
		I_BASE            => "0101", -- Base Address of chip
		
      I_MXA             => cpu_addr,
      I_MXD             => cpu_data_out,
      O_MXD             => open,
      O_MXD_OE_L        => open,

      -- cpu control signals
      I_M1_L            => cpu_m1_l,
      I_RD_L            => cpu_rd_l,
      I_IORQ_L          => cpu_iorq_l,
      I_RESET_L         => I_RESET_L,

      -- no pots - student project ? :)

      -- switches
      O_SWITCH          => open,
      I_SWITCH          => x"00",
      O_POT_SEL         => open,
      I_POT_DATA        => x"00",

      -- audio
      O_AUDIO           => O_AUDIO_R,

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
		O_WR_L            => open,
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
  variable boostcol : integer;
  begin
    wait until rising_edge(CLK);
    if (ENA = '1') then
      O_HSYNC <= hsync;
      O_VSYNC <= vsync;
      O_COMP_SYNC_L <= (not vsync) and (not hsync);

		-- No sparkle or this colour not sparkled
		if I_SPARKLE='0' or luma_t(4)='0' then
			-- Patch Gorf background colour (looks more like real machine)
			if I_GORF='1' and (video_r & video_g & video_b)=x"0AD" then
				O_VIDEO_R <= video_r;
				O_VIDEO_G <= x"4";
				O_VIDEO_B <= video_b;
			else
				O_VIDEO_R <= video_r;
				O_VIDEO_G <= video_g;
				O_VIDEO_B <= video_b;
			end if;
		else
			 -- hardware injects 4 levels into Y line, thus increasing luminosity
			 -- It can also clamp Y line to GND, thus blacking it out
			 -- this is not so easy to do in RGB land, so use custom colours to look more like real hardware
			 case (video_r & video_g & video_b) is
				
				when x"999" =>		-- Gorf Stars
					if luma_t(3)='0' then
						if luma_t(2 downto 0)="000" then
							O_VIDEO_R <= "0000";
							O_VIDEO_G <= "0000";
							O_VIDEO_B <= "0000";
						else
							O_VIDEO_R <= video_r;
							O_VIDEO_G <= video_g;
							O_VIDEO_B <= video_b;
						end if;
					else
						O_VIDEO_R <= luma_t(3 downto 0);
						O_VIDEO_G <= luma_t(3 downto 0);
						O_VIDEO_B <= luma_t(3 downto 0);
					end if;

--				when x"3FF" =>		-- WoW Stars
--					if luma_t(3)='0' then
--						if luma_t(2 downto 0)="000" then
--							O_VIDEO_R <= "0000";
--							O_VIDEO_G <= "0000";
--							O_VIDEO_B <= "0000";
--						else
--							O_VIDEO_R <= video_r;
--							O_VIDEO_G <= video_g;
--							O_VIDEO_B <= video_b;
--						end if;
--					else
--						O_VIDEO_R <= '0' & luma_t(3 downto 1);
--						O_VIDEO_G <= x"F";
--						O_VIDEO_B <= x"F";
--					end if;
					
				when x"F02" | x"F00" =>		-- Gorf space invader Red / WoW Red
					case luma_t(3 downto 0) is
						when "0000" => 
							O_VIDEO_R <= "0000";
							O_VIDEO_G <= "0000";
							O_VIDEO_B <= "0000";
						when "0111" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "0010";
							O_VIDEO_B <= "0011";
						when "1000" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "0011";
							O_VIDEO_B <= "0100";
						when "1001" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "0100";
							O_VIDEO_B <= "0101";
						when "1010" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "0101";
							O_VIDEO_B <= "0111";
						when "1011" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "0110";
							O_VIDEO_B <= "1000";
						when "1100" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "0111";
							O_VIDEO_B <= "1001";
						when "1101" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "1000";
							O_VIDEO_B <= "1010";
						when "1110" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "1001";
							O_VIDEO_B <= "1011";
						when "1111" =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "1010";
							O_VIDEO_B <= "1100";
						when others =>
							O_VIDEO_R <= "1111";
							O_VIDEO_G <= "0001";
							O_VIDEO_B <= "0010";
					end case;
					
				when x"F14" | x"F44" =>	-- Gorf flagship red
					case luma_t(3 downto 0) is
						when "0000" => 
							O_VIDEO_R <= x"0";
							O_VIDEO_G <= x"0";
							O_VIDEO_B <= x"0";
						when "0111" =>
							O_VIDEO_R <= x"E";
							O_VIDEO_G <= x"2";
							O_VIDEO_B <= x"0";
						when "1000" =>
							O_VIDEO_R <= x"F";
							O_VIDEO_G <= x"4";
							O_VIDEO_B <= x"0";
						when "1001" =>
							O_VIDEO_R <= x"F";
							O_VIDEO_G <= x"5";
							O_VIDEO_B <= x"0";
						when "1010" =>
							O_VIDEO_R <= x"F";
							O_VIDEO_G <= x"6";
							O_VIDEO_B <= x"1";
						when "1011" =>
							O_VIDEO_R <= x"F";
							O_VIDEO_G <= x"7";
							O_VIDEO_B <= x"1";
						when "1100" =>
							O_VIDEO_R <= x"F";
							O_VIDEO_G <= x"8";
							O_VIDEO_B <= x"2";
						when "1110" | "1111" =>
							O_VIDEO_R <= x"D";
							O_VIDEO_G <= x"1";
							O_VIDEO_B <= x"0";
						when others =>
							O_VIDEO_R <= x"A";
							O_VIDEO_G <= x"0";
							O_VIDEO_B <= x"0";
					end case;
					
				WHEN x"fff" => -- Gorf shield - Invaders
					if luma_t(3) ='1' then
						O_VIDEO_R <= "1111";
						O_VIDEO_G <= "1111";
						O_VIDEO_B <= "1111";
					else
						O_VIDEO_R <= X"0"; -- patched colour table to match
						O_VIDEO_G <= X"4";
						O_VIDEO_B <= X"D";
					end if;
					backcol <= x"04D"; -- matches patched colour
					
				when others =>  -- colour fades between screens

				  if video_r & video_g & video_b = X"000" then
						backcol <= x"000";
				  end if;
				  
				  if luma_t(3 downto 0) = "0000" then
						-- on one gorf screen goes to background colour instead so we set backcol especially for that!
						O_VIDEO_R <= backcol(11 downto 8);
						O_VIDEO_G <= backcol(7 downto 4);
						O_VIDEO_B <= backcol(3 downto 0);
				  else
					   O_VIDEO_R <= (video_r and luma_t(3 downto 0));
					   O_VIDEO_G <= (video_g and luma_t(3 downto 0));
					   O_VIDEO_B <= (video_b and luma_t(3 downto 0));
				  end if;
			end case;
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

 O_SAMP_L    <= SW_Sampl_L when I_SEAWOLF='1' else GF_Sampl_L;
 O_SAMP_R    <= SW_Sampl_R when I_SEAWOLF='1' else GF_Sampl_R;
 O_SAMP_ADDR <= SW_Sampl_A when I_SEAWOLF='1' else GF_Sampl_A;
 O_SAMP_READ <= SW_Read    when I_SEAWOLF='1' else GF_Read;
 O_SAMP_BUSY <= GF_Votrax;
 
 seasound : SeawolfSound
   port map (
		cpu_addr  	=> cpu_addr,
		cpu_data  	=> cpu_data_out,
		-- Sample Info
		s_enable  	=> I_SEAWOLF,
		s_addr    	=> SW_Sampl_A,
		s_data    	=> I_SAMP_DATA,
		s_read    	=> SW_Read,
		s_ready     => I_SAMP_READY,
		-- Sounds
		audio_out_l => SW_Sampl_L,
		audio_out_r => SW_Sampl_R,
		-- cpu
		I_RESET_L 	=> I_RESET_L,
		I_M1_L    	=> cpu_m1_l,
		I_RD_L    	=> cpu_rd_l,
		I_IORQ_L  	=> cpu_iorq_l,
		 -- clks
		I_CPU_ENA   => cpu_ena,
		ENA         => ENA,
		CLK         => CLK
	);
	
 gorfvotrax : GorfSound
   port map (
		I_MXA     	=> cpu_addr,
		-- Sample Info
		s_enable  	=> I_GORF,
		s_addr    	=> GF_Sampl_A,
		s_data    	=> I_SAMP_DATA,
		s_read    	=> GF_Read,
		s_ready     => I_SAMP_READY,
		-- Sounds
		audio_out_l => GF_Sampl_L,
		audio_out_r => GF_Sampl_R,
		votrax		=> GF_Votrax,
		-- cpu
		I_RESET_L 	=> I_RESET_L,
		I_M1_L    	=> cpu_m1_l,
		I_RD_L    	=> cpu_rd_l,
		I_IORQ_L  	=> cpu_iorq_l,
		I_HL        => cpu_hl,
		 -- clks
		I_CPU_ENA   => cpu_ena,
		ENA         => ENA,
		CLK         => CLK
	);
		
end RTL;
