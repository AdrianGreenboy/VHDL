`ifndef NMU_MACROS
`define NMU_MACROS
`ifndef VERBOSITY_T_ENUM
`define VERBOSITY_T_ENUM
//typedef enum {NONE,LOW,FULL,DBG} verbosity_t;
typedef enum {LOW,FULL,DBG} verbosity_t;
parameter verbosity_t VERBOSITY=DBG;
`endif
`define PRINT(ifdef_msg,msg,verbosity_l) \
  `ifdef ifdef_msg \
  if(VERBOSITY>=verbosity_l) $display("%m: @%0t ",$time,msg); \
  `else \
    begin end \
  `endif 
  
  `define PRINT_MODEL(ifdef_msg,msg,verbosity_l) \
  if( ifdef_msg) \
  //if(top.verbosity>=verbosity_l) $display("%m: @%0t ",$time,msg); \
  if(VERBOSITY>=verbosity_l) $display("%m: @%0t ",$time,msg); \
  //`else \
//begin end \
 // `endif  
 

`endif 
