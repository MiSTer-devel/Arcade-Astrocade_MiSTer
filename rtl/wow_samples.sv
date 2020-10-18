//
// Link to samples module so I can use FB Define
//

module WoWSound
(
	input   [15:0] 	I_MXA,

	input           s_enable,
	output  [23:0] 	s_addr,
	input   [15:0] 	s_data,
	output			s_read,
	input           s_ready,

	output  [15:0] 	audio_out_l,
	output  [15:0] 	audio_out_r,
	output         	votrax,

	input           I_RESET_L,
	input           I_M1_L,
	input           I_RD_L,
	input           I_IORQ_L,
	input   [15:0]  I_HL,

	input           I_CPU_ENA,
	input           ENA,
	input           CLK
);


`ifdef USE_FB

	// If frame buffer is being used, then samples are in SDRAM

	WoWSound_SDRAM WoWSound_SDRAM
	(
		.I_MXA(I_MXA),

		.s_enable(s_enable),
		.s_addr(s_addr),
		.s_data(s_data),
		.s_read(s_read),

		.audio_out_l(audio_out_l),
		.audio_out_r(audio_out_r),
		.votrax(votrax),

		.I_RESET_L(I_RESET_L),
		.I_M1_L(I_M1_L),
		.I_RD_L(I_RD_L),
		.I_IORQ_L(I_IORQ_L),
		.I_HL(I_HL),

		.I_CPU_ENA(I_CPU_ENA),
		.ENA(ENA),
		.CLK(CLK)
	);

`else

	// frame buffer not used, then samples are in DDRAM

	WoWSound_DDRAM WoWSound_DDRAM
	(
		.I_MXA(I_MXA),

		.s_enable(s_enable),
		.s_addr(s_addr),
		.s_data(s_data),
		.s_read(s_read),
		.s_ready(s_ready),

		.audio_out_l(audio_out_l),
		.audio_out_r(audio_out_r),
		.votrax(votrax),

		.I_RESET_L(I_RESET_L),
		.I_M1_L(I_M1_L),
		.I_RD_L(I_RD_L),
		.I_IORQ_L(I_IORQ_L),
		.I_HL(I_HL),

		.I_CPU_ENA(I_CPU_ENA),
		.ENA(ENA),
		.CLK(CLK)
	);

`endif

endmodule
