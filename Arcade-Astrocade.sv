//============================================================================
//  Arcade version of Astrocade 
//
//  Add arcade hardware by Mike Coates
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================


//===========================================================================
//                     Current status / To Do list
//===========================================================================
// Extra Bases
// -----------
// Control mapping P2
//===========================================================================
// Seawolf 2
// ---------
// Control mapping P2 (Test, possibly need different positions)
//===========================================================================
// Space Zap
// ---------
// Done!
//===========================================================================
// Wizard of Wor
// ----------
// Control mapping P2 (test digital)
// SC01
//===========================================================================
// Robby Roto
// ----------
// Control mapping P2 (test)
//===========================================================================
// Gorf
// ----------
// Control mapping P2
// SC01 done using samples for the moment.
//===========================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX,  // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,
	
	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE, 

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign AUDIO_S   = mod_seawolf2; // signed - seawolf 2, unsigned others
assign AUDIO_MIX = 2'd0;

assign LED_USER  = ioctl_download;	
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;

`include "build_id.v" 

localparam CONF_STR = {
	"A.ASTROCADE;;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire 1,Fire 2,Start 1P,Start 2P,Coin;",
	"jn,A,B,Start,Select,R;",
	"jp,B,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_snd;
wire pll_locked;
wire CLK_VIDEO;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(CLK_VIDEO),
	.outclk_2(clk_snd),
	.locked(pll_locked)
);

reg [1:0] clk_cpu_ct;

always @(posedge clk_sys or posedge reset) begin
	if (reset)
		clk_cpu_ct <= 2'd0;
	else
		clk_cpu_ct <= clk_cpu_ct + 2'd1;
end

wire clk_cpu_en = clk_cpu_ct[0];
wire reset = RESET | buttons[1] | status[0] | ioctl_download;

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire  [7:0] ioctl_index;

wire [15:0] joystick_0,joystick_1,joystick_a0,joystick_a1;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_analog_0(joystick_a0),
	.joystick_analog_1(joystick_a1),
	
	.ps2_key(ps2_key)
);


////////////////////////////  GAME configuration  ////////////////////////////

reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout[7:0];

reg mod_ebase    = 0;
reg mod_seawolf2 = 0;
reg mod_spacezap = 0;
reg mod_gorf     = 0;
reg mod_wow      = 0;
reg mod_robby    = 0;

always @(posedge clk_sys) begin
	reg [7:0] mod = 0;
	if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout[7:0];
	
	mod_ebase	   <= (mod == 1);
	mod_seawolf2	<= (mod == 2);
	mod_spacezap	<= (mod == 3);
	mod_gorf			<= (mod == 4);
	mod_wow			<= (mod == 5);
	mod_robby		<= (mod == 6);
end

// Game options
wire Stereo    = mod_gorf | mod_wow | mod_robby;                // Two sound chips fitted
wire Sparkle   = mod_wow | mod_gorf;                            // Sparkle circuit used
wire LightPen  = mod_wow | mod_gorf;                            // Light pen interrupt used
wire High_Rom  = ~mod_seawolf2;	                               // Seawolf2 has ram C000-CFFF, everything else 8000-CFFF is ROM
wire Extra_Rom = mod_robby;  											    // Robby has ROM D000-EFFF as well
wire OnlySamples = mod_seawolf2;                                // Uses samples but no sound chip
wire PlusSamples = mod_gorf;											    // Uses samples AND sound chip

////////////////////////////  INPUT  ////////////////////////////////////

wire [7:0] col_select;
wire [7:0] row_data;
wire [3:0] pot_select;
wire [7:0] pot_data;
reg  [1:0] track_select = 2'd0;

wire [7:0] joya_paddle = 8'd128 + $signed(joystick_a0[7:0]);
wire [7:0] joyb_paddle = 8'd128 + $signed(~joystick_a0[15:8]);
wire [7:0] joyc_paddle = 8'd128 + $signed(joystick_a1[7:0]);
wire [7:0] joyd_paddle = 8'd128 + $signed(~joystick_a1[15:8]);

// ebases
wire [7:0] ct0_eb = {2'd3,~B2_S,~B1_S,2'd3,~B1_F,~B2_F};
wire [7:0] ct1_eb = {1'b1,sw[0][0],1'b1,sw[0][1],3'd7,~B1_C};
wire [7:0] ct3_eb = track_select[0] ? p1_LR : p1_UD;
// Seawolf 2
wire [7:0] ct0_sw2 = {B2_F, 1'b1, pos_data2[5:0]};
wire [7:0] ct1_sw2 = {B1_F, sw[0][0], pos_data1[5:0]}; 
wire [7:0] ct2_sw2 = {4'd15, sw[0][1], B2_S, B1_S, B1_C}; 
// Space Zap
wire [7:0] ct0_sz = {2'D3,~B2_S,~B1_S,sw[2][1],1'b1,~B1_C,1'b1};
wire [7:0] ct1_sz = {3'D7,~B2_F,~B2_R,~B2_L,~B2_D,~B2_U};
wire [7:0] ct2_sz = {2'D3,sw[2][0],~B1_F,~B1_R,~B1_L,~B1_D,~B1_U};
// Wizard of Wor
wire [7:0] ct0_ww = {sw[2][2],~B2_S,~B1_S,1'b1,sw[2][1],1'b1,~B1_C,1'b1};
wire [7:0] ct1_ww = sw[0][1] ? {2'd3,~B2_F,~W2_FB,~W2_R,~W2_L,~W2_D,~W2_U} : {2'd3,~B2_F,B2_FB,~B2_R,~B2_L,~B2_D,~B2_U};
wire [7:0] ct2_ww = sw[0][0] ? {Votrax_Status,1'd1,~B1_F,~W1_FB,~W1_R,~W1_L,~W1_D,~W1_U} : {Votrax_Status,1'd1,~B1_F,B1_FB,~B1_R,~B1_L,~B1_D,~B1_U};
// Gorf
wire [7:0] ct0_gf = {sw[2][2],sw[2][0],~B2_S,~B1_S,1'b1,sw[2][1],~B1_C,1'b1};
wire [7:0] ct1_gf = {1'd0,2'd1,~B2_F,~B2_R,~B2_L,~B2_D,~B2_U};
wire [7:0] ct2_gf = {Votrax_Status,2'd1,~B1_F,~B1_R,~B1_L,~B1_D,~B1_U};
// Robby Roto
wire [7:0] ct0_rr = {1'd0,~B2_S,~B1_S,1'b1,sw[2][1],1'b1,~B1_C,1'b1};
wire [7:0] ct1_rr = {2'd3,~B2_F,1'd1,~B2_R,~B2_L,~B2_D,~B2_U};
wire [7:0] ct2_rr = {2'D3,~B1_F,1'd1,~B1_R,~B1_L,~B1_D,~B1_U};

always @(*) begin
	case (col_select)
		8'h01: row_data = mod_ebase ? ct0_eb : mod_seawolf2 ? ct0_sw2 : mod_spacezap ? ct0_sz : mod_gorf ? ct0_gf : mod_wow ? ct0_ww : mod_robby ? ct0_rr : 8'd255;
		8'h02: row_data = mod_ebase ? ct1_eb : mod_seawolf2 ? ct1_sw2 : mod_spacezap ? ct1_sz : mod_gorf ? ct1_gf : mod_wow ? ct1_ww : mod_robby ? ct1_rr : 8'd255;
		8'h04: row_data = mod_ebase ? sw[2]  : mod_seawolf2 ? ct2_sw2 : mod_spacezap ? ct2_sz : mod_gorf ? ct2_gf : mod_wow ? ct2_ww : mod_robby ? ct2_rr : 8'd255;
		8'h08: row_data = mod_ebase ? ct3_eb : sw[3]; // Only eBases does not have this as DIPs
		default: row_data = 8'd255;
	endcase
end

wire [10:0] ps2_key;
wire        pressed = ps2_key[9];
wire [8:0]  code    = ps2_key[8:0];

always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_fire2       <= pressed; // space
			'h014: btn_fire1       <= pressed; // ctrl

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
			'h004: btn_coin        <= pressed; // F3

			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h02D: btn_up_2        <= pressed; // R
			'h02B: btn_down_2      <= pressed; // F
			'h023: btn_left_2      <= pressed; // D
			'h034: btn_right_2     <= pressed; // G
			'h01C: btn_fire1_2     <= pressed; // A
			'h01B: btn_fire2_2     <= pressed; // S
		endcase
	end
end

// Mister Buttons
reg btn_up    = 0;
reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;
reg btn_coin  = 0;
reg btn_fire1 = 0;
reg btn_fire2 = 0;

// Mame buttons
reg btn_start_1=0;
reg btn_start_2=0;
reg btn_coin_1=0;
reg btn_up_2=0;
reg btn_down_2=0;
reg btn_left_2=0;
reg btn_right_2=0;
reg btn_fire1_2=0;
reg btn_fire2_2=0;

// Combined buttons
wire B1_S = btn_one_player | btn_start_1 | joystick_0[6];
wire B2_S = btn_two_players | btn_start_2 | joystick_0[7] | joystick_1[6];
wire B1_C = btn_coin | btn_coin_1 | joystick_0[8];

wire B1_U = btn_up | joystick_0[3];
wire B1_D = btn_down | joystick_0[2];
wire B1_L = btn_left | joystick_0[1];
wire B1_R = btn_right | joystick_0[0];
wire B1_F = btn_fire1 | joystick_0[4];
wire B1_FB = btn_fire2 | joystick_0[5];

wire B2_U = btn_up_2 | joystick_1[3];
wire B2_D = btn_down_2 | joystick_1[2];
wire B2_L = btn_left_2 | joystick_1[1];
wire B2_R = btn_right_2 | joystick_1[0];
wire B2_F = btn_fire1_2 | joystick_1[4];
wire B2_FB = btn_fire2_2 | joystick_1[5];

////////////////////////////  SOUND  ////////////////////////////////////

// Sound Chip
wire [7:0] audio_l;
wire [7:0] audio_r;
// Samples
wire [15:0] sample_l;
wire [15:0] sample_r;
wire [23:0] wave_addr;
wire [15:0] wave_data;
wire        wave_rd;	
wire        Votrax_Status;

// combine speech and SFX (speech seems much louder, so turn it down in comparison to SFX)
wire [15:0] Sum_L = {1'd0, audio_l, audio_l[7:1]} + {2'd0,sample_l[15:2]}; 
wire [15:0] Sum_R = {1'd0, audio_r, audio_r[7:1]} + {2'd0,sample_r[15:2]}; 

assign AUDIO_L = OnlySamples ? sample_l : PlusSamples ? Sum_L : {audio_l, audio_l};
assign AUDIO_R = OnlySamples ? sample_r : PlusSamples ? Sum_R : Stereo ? {audio_r, audio_r} : {audio_l, audio_l};

sdram sdram
(
	.*,
	.init(~pll_locked),
	.clk(clk_snd),

	.addr(ioctl_download ? ioctl_addr : {1'b0,wave_addr}),
	.we(ioctl_download && ioctl_wr && (ioctl_index==2)),
	.rd(~ioctl_download & wave_rd),
	.din(ioctl_dout),
	.dout(wave_data),

	.ready()
);

////////////////////////////  VIDEO  ////////////////////////////////////


wire [3:0] R, G, B;
wire hs,vs;

reg  HSync;
reg  VSync;
wire VBlank;
wire HBlank;
wire [8:0] HCount;
wire [10:0] VCount;
reg ce_pix;

// Corrected VCount (allowing for interlaced output)
wire [10:0] MyVCount = (VCount >= 264) ? VCount - 263 : VCount;
// Change blanking signal to stabilise picture
wire MyVBlank = ((MyVCount < 25) || (MyVCount > 254));

always @(posedge clk_sys) begin
	ce_pix <= ~ce_pix;
end

assign VGA_F1 = 0;

//actual: 0-225, 0-238
//quoted: 160/320, 102/204

arcade_video #(360,240,12) arcade_video
(
        .*,

        .clk_video(CLK_VIDEO),
        .ce_pix(ce_pix),

        .RGB_in({O_R,O_G,O_B}),
        .HBlank(HBlank),
        .VBlank(MyVBlank),
        .HSync(hs),
        .VSync(vs),

		  .rotate_ccw(1),
		  
        .fx(status[5:3]),
		  .forced_scandoubler(forced_scandoubler),
        .no_rotate(status[2])
);

BALLY bally
(
	// Audio
	.O_AUDIO_L      (audio_l), //  : out   std_logic_vector(7 downto 0);
	.O_AUDIO_R      (audio_r), //  : out   std_logic_vector(7 downto 0);

	// Video
	.O_VIDEO_R      (R), //    : out   std_logic_vector(3 downto 0);
	.O_VIDEO_G      (G), //    : out   std_logic_vector(3 downto 0);
	.O_VIDEO_B      (B), //    : out   std_logic_vector(3 downto 0);
	.O_CE_PIX       (),
	.O_HBLANK_V     (HBlank),
	.O_VBLANK_V     (VBlank),
	.O_HSYNC        (hs), //    : out   std_logic;
	.O_VSYNC        (vs), //    : out   std_logic;
	.O_COMP_SYNC_L  (), //    : out   std_logic;
	.O_FPSYNC       (), //    : out   std_logic;
	.O_HCOUNT       (HCount),
	.O_VCOUNT       (VCount),

	// Rom Addressing and game ID
	.I_HIGH_ROM		 (High_Rom),	// 8000-CFFF = ROM
	.I_EXTRA_ROM	 (Extra_Rom),  // D000-DFFF = ROM
	.I_SPARKLE      (Sparkle),
	.I_LIGHTPEN     (LightPen),
	.I_GORF         (mod_gorf),
	.I_SEAWOLF      (mod_seawolf2),

	// Samples
	.O_SAMP_L       (sample_l),
	.O_SAMP_R       (sample_r),
	.O_SAMP_ADDR    (wave_addr),
	.O_SAMP_READ    (wave_rd),
	.I_SAMP_DATA    (wave_data),
	.O_SAMP_BUSY    (Votrax_Status),

	// BIOS
	.O_BIOS_ADDR    (bios_addr),
	.O_BIOS_CS_L    (bios_rd),
	.I_BIOS_DATA    (bios_do),

	// Input
	.O_SWITCH_COL   (col_select), //    : out   std_logic_vector(7 downto 0);
	.I_SWITCH_ROW   (row_data), //    : in    std_logic_vector(7 downto 0);
	.O_POT          (pot_select),
	.I_POT          (pot_data),
	.O_TRACK_S      (track_select), // eBases trackball axis select

	// System
	.I_RESET_L      (~reset), //    : in    std_logic;
	.ENA            (clk_cpu_en), //    : in    std_logic;
	.CLK            (clk_sys) //    : in    std_logic
);

////////////////////////////  MEMORY  ///////////////////////////////////

wire [15:0] bios_addr;
wire [7:0] bios_do = bios_addr[15] ? Hrom_do : Lrom_do;
wire [7:0] Lrom_do;
wire [7:0] Hrom_do;
wire bios_rd;

dpram #(14) bios // 0000-3FFF
(
	.clock(clk_sys),
	.address_a(ioctl_download ? ioctl_addr[13:0] : bios_addr[13:0]),
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && (ioctl_addr[15:14] == 2'd0) && (ioctl_index == 0)),
	.q_a(Lrom_do)
);

// if High_Rom set then 8000-CFFF is also ROM
// Robby Roto uses D000-EFFF as well

dpram #(15) rom  // 8000-CFFF (and D000-EFFF)
(
	.clock(clk_sys),
	.address_a(ioctl_download ? {~ioctl_addr[14],ioctl_addr[13:0]} : bios_addr[14:0] ), 
	.data_a(ioctl_dout),
	.wren_a(ioctl_wr && (ioctl_addr[15:14] != 2'd0) && (ioctl_index == 0)),
	.q_a(Hrom_do)
);


///////////////////// Game specific routines  ////////////////////////////

reg [3:0] O_R,O_G,O_B;

always @(posedge CLK_VIDEO) begin
	// Blank screen edges
	if ((MyVCount >= 260) || (MyVCount <= 21) || (HCount <= 70)) begin
		O_R <= 4'd0;
		O_B <= 4'd0;
		O_G <= 4'd0;
	end
	else begin
		O_R <= R;
		O_B <= B;
		O_G <= G;

		// Seawolf II - Draw scopes (since original has moving periscope)
		if (mod_seawolf2) begin
			if ((MyVCount > 57-15) && (MyVCount < 57+15)) begin
				// Scope for P1
				if ((MyVCount == 57) && (HCount > (pos_posi1 - 15)) && (HCount < (pos_posi1 + 15))) begin
					O_R <= 4'd15;
					O_B <= 4'd0;
					O_G <= 4'd15;
				end
				if (HCount == pos_posi1) begin
					O_R <= 4'd15;
					O_B <= 4'd0;
					O_G <= 4'd15;
				end
				// Scope for P2
				if (sw[0][2]) begin
					if ((MyVCount == 57) && (HCount > (pos_posi2 - 15)) && (HCount < (pos_posi2 + 15))) begin
						O_R <= 4'd15;
						O_B <= 4'd0;
						O_G <= 4'd0;
					end
					if (HCount == pos_posi2) begin
						O_R <= 4'd15;
						O_B <= 4'd0;
						O_G <= 4'd0;
					end
				end
			end
		end		
	end
end


/////////////////
/// Seawolf 2 ///
/////////////////


// analogue position to Grays Binary

reg  [7:0] pos_data1,pos_data2;
reg  [8:0] pos_posi1,pos_posi2;

GRAY conversion1
(
	.clk(clk_sys),
	.addr(joya_paddle[7:2]),
	.data(pos_data1),
	.posi(pos_posi1)
);

GRAY conversion2
(
	.clk(clk_sys),
	.addr(joyc_paddle[7:2]),
	.data(pos_data2),
	.posi(pos_posi2)
);

///////////////////
/// Extra Bases ///
///////////////////

reg  [7:0] p1_UD,p1_LR;

// Use analogue stick to pretend to be rollerball

AnaloguetoDelta P1UDC
(
	.clk(clk_sys),
	.addr(joyb_paddle[7:4]),
	.data(p1_UD)
);

AnaloguetoDelta P1LRC
(
	.clk(clk_sys),
	.addr(joya_paddle[7:4]),
	.data(p1_LR)
);

/////////////////////
/// Wizard of Wor ///
/////////////////////

// edge of stick toggles move button as well as direction.

reg W1_U,W1_D,W1_L,W1_R,W1_F1,W1_F2;
reg W2_U,W2_D,W2_L,W2_R,W2_F1,W2_F2;

// either axis moved far enough to trigger button 2
wire W1_FB = W1_F1 | W1_F2;
wire W2_FB = W2_F1 | W2_F2;

WowMapping WP1UDC
(
	.clk(clk_sys),
	.addr(joyb_paddle[7:5]),
	.dir0(W1_D),
	.dir1(W1_U),
	.move(W1_F1)
);

WowMapping WP1LRC
(
	.clk(clk_sys),
	.addr(joya_paddle[7:5]),
	.dir0(W1_L),
	.dir1(W1_R),
	.move(W1_F2)
);

WowMapping WP2UDC
(
	.clk(clk_sys),
	.addr(joyd_paddle[7:5]),
	.dir0(W2_D),
	.dir1(W2_U),
	.move(W2_F1)
);

WowMapping WP2LRC
(
	.clk(clk_sys),
	.addr(joyc_paddle[7:5]),
	.dir0(W2_L),
	.dir1(W2_R),
	.move(W2_F2)
);

endmodule
