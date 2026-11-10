  wire Q0_APB3PSEL;
  wire Q0_APB3PWRITE;
  wire Q0_APB3PREADY;
  wire Q0_APB3PENABLE;
  wire[127:0] Q0_dbg0;
  wire[127:0] Q0_dbg1;
  wire[127:0] Q0_dbg2;
  wire[127:0] Q0_dbg3;
  wire [15:0] Q0_APB3PADDR;
  wire [31:0] Q0_APB3PWDATA;
  
 cpm4_v1_0_21_txfir_remap Q0_txfir_remap_inst(
    .clk(gt_reflck0_div2),
    .reset(~Q0_dbg0[57]),

    .APB3PADDR  (Q0_APB3PADDR),
    .APB3PWDATA (Q0_APB3PWDATA),
    .APB3PENABLE(Q0_APB3PENABLE),
    .APB3PSEL   (Q0_APB3PSEL),
    .APB3PWRITE (Q0_APB3PWRITE),
    .APB3PREADY (Q0_APB3PREADY),

    .ch0_txemppre (Q0_dbg0[75:71]),
    .ch0_txemppos (Q0_dbg0[63:59]),
    .ch0_txempmain(Q0_dbg0[70:64]),
    .ch0_txdeemph (Q0_dbg0[80]),
    .ch0_txswing  (Q0_dbg0[76]),
    .ch0_txmargin (Q0_dbg0[79:77]),

    .ch1_txemppre (Q0_dbg1[75:71]),
    .ch1_txemppos (Q0_dbg1[63:59]),
    .ch1_txempmain(Q0_dbg1[70:64]),
    .ch1_txdeemph (Q0_dbg1[80]),
    .ch1_txswing  (Q0_dbg1[76]),
    .ch1_txmargin (Q0_dbg1[79:77]),

    .ch2_txemppre (Q0_dbg2[75:71]),
    .ch2_txemppos (Q0_dbg2[63:59]),
    .ch2_txempmain(Q0_dbg2[70:64]),
    .ch2_txdeemph (Q0_dbg2[80]),
    .ch2_txswing  (Q0_dbg2[76]),
    .ch2_txmargin (Q0_dbg2[79:77]),

    .ch3_txemppre (Q0_dbg3[75:71]),
    .ch3_txemppos (Q0_dbg3[63:59]),
    .ch3_txempmain(Q0_dbg3[70:64]),
    .ch3_txdeemph (Q0_dbg3[80]),
    .ch3_txswing  (Q0_dbg3[76]),
    .ch3_txmargin (Q0_dbg3[79:77])
  );


  wire Q1_APB3PSEL;
  wire Q1_APB3PWRITE;
  wire Q1_APB3PREADY;
  wire Q1_APB3PENABLE;
  wire[127:0] Q1_dbg0;
  wire[127:0] Q1_dbg1;
  wire[127:0] Q1_dbg2;
  wire[127:0] Q1_dbg3;
  wire [15:0] Q1_APB3PADDR;
  wire [31:0] Q1_APB3PWDATA;

  cpm4_v1_0_21_txfir_remap Q1_txfir_remap_inst(
    .clk(gt_reflck0_div2),
    .reset(~Q1_dbg0[57]),

    .APB3PSEL(Q1_APB3PSEL),
    .APB3PADDR(Q1_APB3PADDR),
    .APB3PWDATA(Q1_APB3PWDATA),
    .APB3PWRITE(Q1_APB3PWRITE),
    .APB3PREADY(Q1_APB3PREADY),
    .APB3PENABLE(Q1_APB3PENABLE),

    .ch0_txswing  (Q1_dbg0[76]),
    .ch0_txdeemph (Q1_dbg0[80]),
    .ch0_txmargin (Q1_dbg0[79:77]),
    .ch0_txemppre (Q1_dbg0[75:71]),
    .ch0_txemppos (Q1_dbg0[63:59]),
    .ch0_txempmain(Q1_dbg0[70:64]),

    .ch1_txswing  (Q1_dbg1[76]),
    .ch1_txdeemph (Q1_dbg1[80]),
    .ch1_txemppre (Q1_dbg1[75:71]),
    .ch1_txemppos (Q1_dbg1[63:59]),
    .ch1_txmargin (Q1_dbg1[79:77]),
    .ch1_txempmain(Q1_dbg1[70:64]),

    .ch2_txswing  (Q1_dbg2[76]),
    .ch2_txdeemph (Q1_dbg2[80]),
    .ch2_txemppre (Q1_dbg2[75:71]),
    .ch2_txemppos (Q1_dbg2[63:59]),
    .ch2_txmargin (Q1_dbg2[79:77]),
    .ch2_txempmain(Q1_dbg2[70:64]),

    .ch3_txswing  (Q1_dbg3[76]),
    .ch3_txdeemph (Q1_dbg3[80]),
    .ch3_txemppre (Q1_dbg3[75:71]),
    .ch3_txemppos (Q1_dbg3[63:59]),
    .ch3_txmargin (Q1_dbg3[79:77]),
    .ch3_txempmain(Q1_dbg3[70:64])
  );

  wire Q2_APB3PSEL;
  wire Q2_APB3PWRITE;
  wire Q2_APB3PREADY;
  wire Q2_APB3PENABLE;
  wire[127:0] Q2_dbg0;
  wire[127:0] Q2_dbg1;
  wire[127:0] Q2_dbg2;
  wire[127:0] Q2_dbg3;
  wire [15:0] Q2_APB3PADDR;
  wire [31:0] Q2_APB3PWDATA;

  cpm4_v1_0_21_txfir_remap Q2_txfir_remap_inst(

    .clk(q2q3_txfir_clk),
    .reset(~Q2_dbg0[57]),

    .APB3PSEL(Q2_APB3PSEL),
    .APB3PADDR(Q2_APB3PADDR),
    .APB3PWRITE(Q2_APB3PWRITE),
    .APB3PREADY(Q2_APB3PREADY),
    .APB3PWDATA(Q2_APB3PWDATA),
    .APB3PENABLE(Q2_APB3PENABLE),

    .ch0_txswing  (Q2_dbg0[76]),
    .ch0_txdeemph (Q2_dbg0[80]),
    .ch0_txemppre (Q2_dbg0[75:71]),
    .ch0_txemppos (Q2_dbg0[63:59]),
    .ch0_txmargin (Q2_dbg0[79:77]),
    .ch0_txempmain(Q2_dbg0[70:64]),

    .ch1_txswing  (Q2_dbg1[76]),
    .ch1_txdeemph (Q2_dbg1[80]),
    .ch1_txmargin (Q2_dbg1[79:77]),
    .ch1_txemppre (Q2_dbg1[75:71]),
    .ch1_txemppos (Q2_dbg1[63:59]),
    .ch1_txempmain(Q2_dbg1[70:64]),

    .ch2_txswing  (Q2_dbg2[76]),
    .ch2_txdeemph (Q2_dbg2[80]),
    .ch2_txemppre (Q2_dbg2[75:71]),
    .ch2_txemppos (Q2_dbg2[63:59]),
    .ch2_txmargin (Q2_dbg2[79:77]),
    .ch2_txempmain(Q2_dbg2[70:64]),

    .ch3_txswing  (Q2_dbg3[76]),
    .ch3_txdeemph (Q2_dbg3[80]),
    .ch3_txemppre (Q2_dbg3[75:71]),
    .ch3_txemppos (Q2_dbg3[63:59]),
    .ch3_txmargin (Q2_dbg3[79:77]),
    .ch3_txempmain(Q2_dbg3[70:64])
  );

  wire Q3_APB3PSEL;
  wire Q3_APB3PWRITE;
  wire Q3_APB3PREADY;
  wire Q3_APB3PENABLE;
  wire[127:0] Q3_dbg0;
  wire[127:0] Q3_dbg1;
  wire[127:0] Q3_dbg2;
  wire[127:0] Q3_dbg3;
  wire [15:0] Q3_APB3PADDR;
  wire [31:0] Q3_APB3PWDATA;

  cpm4_v1_0_21_txfir_remap Q3_txfir_remap_inst(
    .clk(q2q3_txfir_clk),
    .reset(~Q3_dbg0[57]),

    .APB3PSEL(Q3_APB3PSEL),
    .APB3PADDR(Q3_APB3PADDR),
    .APB3PWDATA(Q3_APB3PWDATA),
    .APB3PWRITE(Q3_APB3PWRITE),
    .APB3PREADY(Q3_APB3PREADY),
    .APB3PENABLE(Q3_APB3PENABLE),

    .ch0_txswing  (Q3_dbg0[76]),
    .ch0_txdeemph (Q3_dbg0[80]),
    .ch0_txmargin (Q3_dbg0[79:77]),
    .ch0_txemppre (Q3_dbg0[75:71]),
    .ch0_txemppos (Q3_dbg0[63:59]),
    .ch0_txempmain(Q3_dbg0[70:64]),

    .ch1_txswing  (Q3_dbg1[76]),
    .ch1_txdeemph (Q3_dbg1[80]),
    .ch1_txemppre (Q3_dbg1[75:71]),
    .ch1_txemppos (Q3_dbg1[63:59]),
    .ch1_txmargin (Q3_dbg1[79:77]),
    .ch1_txempmain(Q3_dbg1[70:64]),

    .ch2_txswing  (Q3_dbg2[76]),
    .ch2_txdeemph (Q3_dbg2[80]),
    .ch2_txemppre (Q3_dbg2[75:71]),
    .ch2_txemppos (Q3_dbg2[63:59]),
    .ch2_txmargin (Q3_dbg2[79:77]),
    .ch2_txempmain(Q3_dbg2[70:64]),

    .ch3_txswing  (Q3_dbg3[76]),
    .ch3_txdeemph (Q3_dbg3[80]),
    .ch3_txemppre (Q3_dbg3[75:71]),
    .ch3_txemppos (Q3_dbg3[63:59]),
    .ch3_txmargin (Q3_dbg3[79:77]),
    .ch3_txempmain(Q3_dbg3[70:64])
  );
