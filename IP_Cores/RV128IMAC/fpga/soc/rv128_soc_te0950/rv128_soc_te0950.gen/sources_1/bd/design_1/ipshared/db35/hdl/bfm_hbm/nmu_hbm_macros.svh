`ifndef NMU_HBM_MACROS
   `define NMU_HBM_MACROS


    `define PRINT_NMU_MONITOR(ifdef_msg,msg,verbosity_l) \
    if( ifdef_msg) \
      $display("%m :: @%0t :: ",$time,msg);
  
    `define PRINT_NMU_MODEL(ifdef_msg,reg_handle,msg,verbosity_l) \
    if( ifdef_msg) \
      $display("%m :: %0d :: @%0t :: REG_SRC ='d%0d :: ",`__LINE__,$time,reg_handle.REG_SRC,msg);
 
   `define PRINT_NMU_FATAL(reg_handle,msg) \
   if (verbosity_fatal_to_warn && ~ignore_warning) begin \
   $display("WARNING :: %m :: %0d :: @%0t :: REG_SRC ='d%0d :: ",`__LINE__,$time,reg_handle.REG_SRC,msg); \
   $warning("WARNING :: time %0t :: REG_SRC ='d%0d ",$time,reg_handle.REG_SRC); \
   end \
   else if (~verbosity_fatal_to_warn) begin \
   $display("FATAL_ERROR :: %m :: %0d :: @%0t :: REG_SRC ='d%0d :: ",`__LINE__,$time,reg_handle.REG_SRC,msg); \
   $fatal(1,"FATAL_ERROR :: time %0t :: REG_SRC ='d%0d ",$time,reg_handle.REG_SRC); \
   end
 
   `define PRINT_NMU_ERROR(reg_handle,msg) \
   if (verbosity_err_to_warn && ~ignore_warning) \
   $warning("%m :: time %0t :: REG_SRC ='d%0d :: ",$time,reg_handle.REG_SRC,msg); \
   else if (~verbosity_fatal_to_warn) \
   $error("%m :: time %0t :: REG_SRC ='d%0d :: ",$time,reg_handle.REG_SRC,msg);

`endif 
