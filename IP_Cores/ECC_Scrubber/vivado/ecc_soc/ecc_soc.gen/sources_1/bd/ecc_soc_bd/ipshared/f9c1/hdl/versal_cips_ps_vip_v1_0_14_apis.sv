/*****************************************************************************
 * File : versal_cips_ps_vip_v1_0_14_apis.sv
 *
 * Date : 2015-16
 *
 * Description : Set of Versal CIPS PS BFM APIs that are used for writing tests.
 *                
 *****************************************************************************/

  /* API for setting the STOP_ON_ERROR*/  
//   task automatic set_stop_on_error;
//     input LEVEL;
//     begin
//       $display("[%0d] : %0s : Setting Stop On Error as %0b",$time, DISP_INFO, LEVEL);
//       STOP_ON_ERROR = LEVEL;
//       
//       A72_API.master.set_stop_on_error(LEVEL);
//       NOC_API.master.set_stop_on_error(LEVEL);
//       R5_API.master.set_stop_on_error(LEVEL);
//       S_AXI_OCM.slave.set_stop_on_error(LEVEL);
//
//       S_AXI_OCM.STOP_ON_ERROR = LEVEL;
//       A72_API.STOP_ON_ERROR = LEVEL;
//       NOC_API.STOP_ON_ERROR = LEVEL;
//       R5_API.STOP_ON_ERROR = LEVEL;
//     end
//   endtask 
//
//  /* API for setting the verbosity for channel level info*/  
//  task automatic set_channel_level_info;
//    input [1023:0] name;
//    input LEVEL;
//    begin
//     $display("[%0d] : [%0s] : %0s Port/s : Setting Channel Level Info as %0b",$time, DISP_INFO,  name , LEVEL);
//     case(name)
//       "S_AXI_OCM" : S_AXI_OCM.slave.set_channel_level_info(LEVEL);
//       "A72_API"   : A72_API.slave.set_channel_level_info(LEVEL);
//       "NOC_API"   : NOC_API.slave.set_channel_level_info(LEVEL);
//       "R5_API"    : R5_API.slave.set_channel_level_info(LEVEL);
//       "ALL"       : begin
//                        S_AXI_OCM.slave.set_channel_level_info(LEVEL);
//                        A72_API.slave.set_channel_level_info(LEVEL);
//                        NOC_API.slave.set_channel_level_info(LEVEL);
//                        R5_API.slave.set_channel_level_info(LEVEL);
//                     end
//      default     : $display("[%0d] : %0s : Invalid Port name (%0s)",$time, DISP_ERR, name);
//     endcase
//    end
//  endtask
//
//  /* API for setting the verbosity for function level info*/  
//  task automatic set_function_level_info;
//    input [1023:0] name;
//    input LEVEL;
//    begin
//     $display("[%0d] : [%0s] : %0s Port/s : Setting Function Level Info as %0b",$time, DISP_INFO,  name , LEVEL);
//     case(name)
//      "S_AXI_OCM" : S_AXI_OCM.slave.set_function_level_info(LEVEL);
//      "A72_API"   : A72_API.slave.set_function_level_info(LEVEL);
//      "NOC_API"   : NOC_API.slave.set_function_level_info(LEVEL);
//      "R5_API"    : R5_API.slave.set_function_level_info(LEVEL);
//      "ALL"       : begin
//                       S_AXI_OCM.slave.set_function_level_info(LEVEL);
//                       A72_API.slave.set_function_level_info(LEVEL);
//                       NOC_API.slave.set_function_level_info(LEVEL);
//                       R5_API.slave.set_function_level_info(LEVEL);
//                    end
//      default     : $display("[%0d] : %0s : Invalid Port name (%0s)",$time, DISP_ERR, name);
//     endcase
//    end
//  endtask

//   /* API for setting the Message verbosity */  
   task automatic set_debug_level_info;
     input LEVEL;
     begin
       $display("INFO: [%0s] (%m) :: [set_debug_level_info] [%0d] ::: Setting Debug Level Info as %0b", DISP_VIP, $time, LEVEL);
       DEBUG_INFO = LEVEL;
       S_AXI_OCM.DEBUG_INFO = LEVEL; 
       A72_API.DEBUG_INFO = LEVEL; 
       NOC_API.DEBUG_INFO = LEVEL; 
       R5_API.DEBUG_INFO = LEVEL; 
     end
   endtask
  
/* To control the internal axi masters and slaves verbosity_level
   32'd0: None
   32'd0: Full
*/
   task automatic set_verbosity;
     input [31:0] verbosity_level;
     begin
       $display("INFO: [%0s] (%m) :: [set_verbosity] [%0d] ::: Setting Verbosity Level as %0b", DISP_VIP, $time, verbosity_level);
       
       if((verbosity_level == 32'd0) || (verbosity_level == 32'd400)) begin
	   S_AXI_OCM.set_verbosity    ( verbosity_level);
          S_AXI_REG1.set_verbosity    ( verbosity_level); 
          S_AXI_REG2.set_verbosity    ( verbosity_level); 
          S_AXI_REG3.set_verbosity    ( verbosity_level); 
          S_AXI_REG4.set_verbosity    ( verbosity_level); 
          S_AXI_REG5.set_verbosity    ( verbosity_level); 
          S_AXI_REG6.set_verbosity    ( verbosity_level); 
          S_AXI_REG7.set_verbosity    ( verbosity_level); 
          S_AXI_REG8.set_verbosity    ( verbosity_level); 
          S_AXI_REG9.set_verbosity    ( verbosity_level); 
          S_AXI_REG10.set_verbosity   ( verbosity_level); 
          S_AXI_REG11.set_verbosity   ( verbosity_level); 
          S_AXI_REG12.set_verbosity   ( verbosity_level); 
          A72_API.set_verbosity       ( verbosity_level);
          NOC_API.set_verbosity       ( verbosity_level);
          R5_API.set_verbosity        ( verbosity_level);
       end
       else begin
           $fatal(" Wrong verbosity_level is being  programmed. \nSupported verbosity_level's are 32'd0, 32'd400 ");
       end
     end
   endtask

//   /* API for setting ARQos Values */  
//   task automatic set_arqos;
//     input [1023:0] name;
//     input [axi_qos_width-1:0] value;
//     begin
//      $display("[%0d] : [%0s] : %0s Port/s : Setting AWQOS as %0b",$time, DISP_INFO,  name , value);
//      case(name)
//       "S_AXI_HPC0_FPD" : S_AXI_HPC0_FPD.set_arqos(value);
//       "S_AXI_HPC1_FPD" : S_AXI_HPC1_FPD.set_arqos(value);
//       "S_AXI_HP0_FPD" : S_AXI_HP0_FPD.set_arqos(value);
//       "S_AXI_HP1_FPD" : S_AXI_HP1_FPD.set_arqos(value);
//       "S_AXI_HP2_FPD" : S_AXI_HP2_FPD.set_arqos(value);
//       "S_AXI_HP3_FPD" : S_AXI_HP3_FPD.set_arqos(value);
//       "S_AXI_HPM0_LPD" : S_AXI_HPM0_LPD.set_arqos(value);
//       "S_AXI_ACP" : S_AXI_ACP.set_arqos(value);
//       "S_AXI_ACE" : S_AXI_ACE.set_arqos(value);
//       default     : $display("[%0d] : %0s : IS_AXI_HPM0_LPDnvalid Slave Port name (%0s)",$time, DISP_ERR, name);
//      endcase
//     end
//   endtask

//   /* API for setting AWQos Values */  
//   task automatic set_awqos;
//     input [1023:0] name;
//     input [axi_qos_width-1:0] value;
//     begin
//      $display("[%0d] : [%0s] : %0s Port/s : Setting ARQOS as %0b",$time, DISP_INFO,  name , value);
//      case(name)
//       "S_AXI_HPC0_FPD" : S_AXI_HPC0_FPD.set_awqos(value);
//       "S_AXI_HPC1_FPD" : S_AXI_HPC1_FPD.set_awqos(value);
//       "S_AXI_HP0_FPD" : S_AXI_HP0_FPD.set_awqos(value);
//       "S_AXI_HP1_FPD" : S_AXI_HP1_FPD.set_awqos(value);
//       "S_AXI_HP2_FPD" : S_AXI_HP2_FPD.set_awqos(value);
//       "S_AXI_HP3_FPD" : S_AXI_HP3_FPD.set_awqos(value);
//       "S_AXI_HPM0_LPD" : S_AXI_HPM0_LPD.set_awqos(value);
//       "S_AXI_ACP" : S_AXI_ACP.set_awqos(value);
//       "S_AXI_ACE" : S_AXI_ACE.set_awqos(value);
//       default     : $display("[%0d] : %0s : Invalid Slave Port (%0s)",$time, DISP_ERR, name);
//      endcase
//     end
//   endtask

  /* API for por reset control */
   task automatic por_reset;
     input por_reset_ctrl;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [por_reset] [%0d] ::: por_reset called for 0x%0h", DISP_VIP, $time, por_reset_ctrl); 
       gen_rst.por_reset(por_reset_ctrl);  
     end
   endtask

   /* API for PL GEN reset control */
   task automatic pl_gen_reset;
     input[data_width-1:0] reset_ctrl;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [pl_gen_reset] [%0d] ::: pl_gen_reset called for 0x%0h",DISP_VIP, $time, reset_ctrl); 
       gen_rst.pl_gen_reset(reset_ctrl);
     end
   endtask

   /* API for PL GEN clock control */
   task automatic pl_gen_clock;
     input[1:0] clk_num;
     input real  freq_in_mhz;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [pl_gen_clock] [%0d] ::: pl_gen_clock called for clk_num : %0d and clock frequency : %0f Mhz ",DISP_VIP, $time, clk_num, freq_in_mhz); 
       gen_clk.pl_gen_clock(clk_num,freq_in_mhz);
     end
   endtask

   /* API for PS GEN clock control */
   task automatic ps_gen_clock;
     input[4:0] clk_num;
     input real  freq_in_mhz;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [ps_gen_clock] [%0d] ::: ps_gen_clock called for clk_num : %0d and clock frequency : %0d Mhz ",DISP_VIP, $time, clk_num, freq_in_mhz); 
       gen_clk.ps_gen_clock(clk_num,freq_in_mhz);
     end
   endtask

   /* API for CIPS PS VIP GEN clock control */
   task automatic gen_cips_ps_vip_clock;
     input int  freq_in_mhz;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [gen_cips_ps_vip_clock] [%0d] ::: gen_cips_ps_vip_clock called with clock frequency : %0d Mhz ",DISP_VIP, $time, freq_in_mhz); 
       gen_clk.gen_cips_ps_vip_clock(freq_in_mhz);
     end
   endtask

   /* API for CPM GEN clock control */
   task automatic cpm_gen_clock;
     input int  freq_in_mhz;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [cpm_gen_clock] [%0d] ::: cpm_gen_clock called with clock frequency : %0d Mhz ",DISP_VIP, $time, freq_in_mhz); 
       gen_clk.cpm_gen_clock(freq_in_mhz);
     end
   endtask

   /* API for HSMREFCLK geneartion */
   task automatic hsmref_gen_clock;
     input[1:0] clk_num;
     input int  freq_in_mhz;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [hsmref_gen_clock] [%0d] ::: hsmref_gen_clock called for clk_num : %0d and clock frequency : %0d Mhz ",DISP_VIP, $time, clk_num, freq_in_mhz); 
       gen_clk.hsmref_gen_clock(clk_num,freq_in_mhz);
     end
   endtask

/* API for cpm_osc_clk_div2 clock control */
   task automatic cpm_osc_clk_div2_gen_clock;
     input int  freq_in_mhz;
     begin
       if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [cpm_osc_clk_div2_gen_clock] [%0d] ::: cpm_osc_clk_div2_gen_clock called with clock frequency : %0d Mhz ",DISP_VIP, $time, freq_in_mhz); 
       gen_clk.cpm_osc_clk_div2_gen_clock(freq_in_mhz);
     end
   endtask

  /* API for pre-loading memories from OCM model) */
  task automatic pre_load_mem_from_file;
    input [(max_chars*8)-1:0] file_name;
    input [addr_width-1:0] start_addr;
    input [int_width-1:0] no_of_bytes;
    reg [1:0] mem_type;
    integer succ;
    begin
      mem_type = decode_address(start_addr);
      succ = $fopen(file_name,"r");
      if(succ == 0) begin
        $display("ERROR: [%0s] (%m) :: [pre_load_mem_from_file] [%0d] ::: '%0s' doesn't exist. 'pre_load_mem_from_file' call failed ...\n",DISP_VIP, $time, file_name); 
        if(STOP_ON_ERROR) $stop; 
      end   
      else if(check_addr_aligned(start_addr)) begin    
        case(mem_type)
        OCM_MEM : begin
                  ocmc.ocm.pre_load_mem_from_file(file_name,(start_addr-ocm_start_addr),no_of_bytes); 
                  if(DEBUG_INFO)
                     $display("INFO: [%0s] (%m) :: [pre_load_mem_from_file] [%0d] ::: OCM Memory is pre-loaded from file %0s with Starting Address = 0x%0h and %0d bytes of data",DISP_VIP, $time, file_name, start_addr, no_of_bytes); 
                  end 
        default : begin
                  $display("ERROR: [%0s] (%m) :: [pre_load_mem_from_file] [%0d] ::: Address(0x%0h) is out-of-range. 'pre_load_mem_from_file' call failed ...\n",DISP_VIP, $time, start_addr); 
                  if(STOP_ON_ERROR) $stop; 
                  end 
        endcase
      end else begin 
        $display("ERROR: [%0s] (%m) :: [pre_load_mem_from_file] [%0d] ::: Address(0x%0h) has to be 32-bit aligned. 'pre_load_mem_from_file' call failed ...",DISP_VIP, $time, start_addr);
        if(STOP_ON_ERROR)
          $stop; 
      end
    end
  endtask
 
  /* API for pre-loading memories OCM) */
   task automatic pre_load_mem;
     input [1:0] data_type;
     input [addr_width-1:0] start_addr;
     input [int_width-1:0] no_of_bytes;
     reg [1:0] mem_type;
     begin
       mem_type = decode_address(start_addr);
       if(check_addr_aligned(start_addr)) begin    
         case(mem_type)
         OCM_MEM : begin
                   ocmc.ocm.pre_load_mem(data_type,(start_addr-ocm_start_addr),no_of_bytes); 
                   if(DEBUG_INFO)
                     $display("INFO: [%0s] (%m) :: [pre_load_mem] [%0d] ::: OCM Memory is pre-loaded with Starting Address: 0x%0h and %0d bytes of data",DISP_VIP, $time, start_addr, no_of_bytes); 
                   end
         default : begin
                   $display("ERROR: [%0s] (%m) :: [pre_load_mem] [%0d] ::: Address(0x%0h) is out-of-range. 'pre_load_mem' call failed ...\n",DISP_VIP, $time, start_addr); 
                   if(STOP_ON_ERROR) $stop; 
                   end
         endcase
       end else begin 
         $display("ERROR: [%0s] (%m) :: [pre_load_mem] [%0d] ::: Address(0x%0h) has to be 32-bit aligned. 'pre_load_mem' call failed ...",DISP_VIP, $time, start_addr);
         if(STOP_ON_ERROR) $stop; 
       end
     end
   endtask

  /* API for backdoor write to memories OCM) */
   task automatic write_mem;
     input [max_reg_burst_bits-1 :0] data;
     input [addr_width-1:0] start_addr;
     input [max_reg_burst_bytes_width:0] no_of_bytes;
     reg [1:0] mem_type;
     integer succ;
     begin
       mem_type = decode_address(start_addr);
       if(check_addr_aligned(start_addr)) begin    
         case(mem_type)
         OCM_MEM : begin
                   ocmc.ocm.write_mem(data,(start_addr-ocm_start_addr),no_of_bytes,all_strb_valid); 
                   if(DEBUG_INFO)
                     $display("INFO: [%0s] (%m) :: [write_mem] [%0d] ::: Write %0d bytes of data to OCM Memory with Starting Address = 0x%0h",DISP_VIP, $time, no_of_bytes, start_addr); 
                   end 
         default : begin
                   $display("ERROR: [%0s] (%m) :: [write_mem] [%0d] ::: Address(0x%0h) is out-of-range. 'write_mem' call failed ...\n",DISP_VIP, $time, start_addr); 
                   if(STOP_ON_ERROR) $stop; 
                   end 
         endcase
       end else begin 
         $display("ERROR: [%0s] (%m) :: [write_mem] [%0d] ::: Address(0x%0h) has to be 32-bit aligned. 'write_mem' call failed ...",DISP_VIP, $time, start_addr);
         if(STOP_ON_ERROR)
           $stop; 
       end
     end
   endtask

    /* read_memory */
    task automatic read_mem;
      input [addr_width-1:0] start_addr;
      input [max_reg_burst_bytes_width :0] no_of_bytes;
      output[max_reg_burst_bits-1 :0] data;
      reg [1:0] mem_type;
      integer succ;
      begin
        mem_type = decode_address(start_addr);
        if(check_addr_aligned(start_addr)) begin    
          case(mem_type)
          OCM_MEM : begin
                    ocmc.ocm.read_mem(data,(start_addr-ocm_start_addr),no_of_bytes); 
                    if(DEBUG_INFO)
                       $display("INFO: [%0s] (%m) :: [read_mem] [%0d] ::: Read %0d bytes of data from OCM Memory with Starting Address: 0x%0h ",DISP_VIP, $time, no_of_bytes, start_addr); 
                    end 
          default : begin
                    $display("ERROR: [%0s] (%m) :: [read_mem] [%0d] ::: Address(0x%0h) is out-of-range. 'read_mem' call failed ...\n",DISP_VIP, $time, start_addr); 
                    if(STOP_ON_ERROR) $stop; 
                    end 
          endcase
        end else begin 
          $display("ERROR: [%0s] (%m) :: [read_mem] [%0d] ::: Address(0x%0h) has to be 32-bit aligned. 'read_mem' call failed ...",DISP_VIP, $time, start_addr);
          if(STOP_ON_ERROR)
            $stop; 
        end
      end
  endtask

  /* API for backdoor read to memories OCM) */
   task automatic peek_mem_to_file;
     input [(max_chars*8)-1:0] file_name;
     input [addr_width-1:0] start_addr;
     input [int_width-1:0] no_of_bytes;
     reg [1:0] mem_type;
     integer succ;
     begin
       mem_type = decode_address(start_addr);
       if(check_addr_aligned(start_addr)) begin    
         case(mem_type)
         OCM_MEM : begin
                   ocmc.ocm.peek_mem_to_file(file_name,(start_addr-ocm_start_addr),no_of_bytes); 
                   if(DEBUG_INFO)
                     $display("INFO: [%0s] (%m) :: [peek_mem_to_file] [%0d] ::: Peeked %0d bytes of data from OCM Memory with Starting Address = 0x%0h to file %0s",DISP_VIP, $time, no_of_bytes, start_addr, file_name); 
                   end 
         default : begin
                   $display("ERROR: [%0s] (%m) :: [peek_mem_to_file] [%0d] ::: Address(0x%0h) is out-of-range. 'peek_mem_to_file' call failed ...\n",DISP_VIP, $time, start_addr); 
                   if(STOP_ON_ERROR) $stop; 
                   end 
         endcase
       end else begin 
         $display("ERROR: [%0s] (%m) :: [peek_mem_to_file] [%0d] ::: Address(0x%0h) has to be 32-bit aligned. 'peek_mem_to_file' call failed ...",DISP_VIP, $time, start_addr);
         if(STOP_ON_ERROR)
           $stop; 
       end
     end
   endtask

  /* API to program the CCI boundary */
  /* cci_boundary: 2'b00: 4K, 2'b01: 2K, 2'b10: 1K */
  task select_cci_boundary;
     input [1:0]  cci_boundary; // 2'b00: 4K, 2'b01: 2K, 2'b10: 1K
     begin
        case(cci_boundary)
	2'b00: begin
	   local_config_cci_boundary = 3'b000;
	end
	2'b01: begin
	   local_config_cci_boundary = 3'b001;
	end
	2'b10: begin
	   local_config_cci_boundary = 3'b010;
	end
	default: begin
           $fatal(" Wrong CCI boudary is being  programmed. \nSupported CCI boundary's are 4K: 2'b00, 2K: 2'b01, 1K: 2'b10 ");
	end
	endcase
     end
  endtask
 
  /* API to program the DW for M_AXI_FPD,M_AXI_LPD */
  /* prog_data_width: 2'b00: 32-bit, 2'b01: 64-bit, 2'b10: 128-bit */
  /* pl_port_name: M_AXI_FPD/M_AXI_LPD */
  task select_pl_datawidth;
     input [1:0]  prog_data_width; // 2'b00: 32-bit, 2'b01: 64-bit, 2'b10: 128-bit
     input [1023:0] pl_port_name;
     begin
        if(pl_port_name == "M_AXI_FPD") begin
           if(prog_data_width == 2'b11) begin
              $fatal(" Wrong DataWidth is being  programmed. \nSupported DataWidth's are 32bit: 2'b00, 64bit: 2'b01, 128bit: 2'b10 ");
	   end
	   else begin
	      local_maxigp0_port_width = prog_data_width;
	   end
	end
	else if(pl_port_name == "M_AXI_LPD") begin
           if(prog_data_width == 2'b11) begin
              $fatal(" Wrong DataWidth is being  programmed. \nSupported DataWidth's are 32bit: 2'b00, 64bit: 2'b01, 128bit: 2'b10 ");
	   end
	   else begin
	      local_maxigp2_port_width = prog_data_width;
	   end
	end
	else begin
              $fatal(" Wrong pl_port_name is being  programmed. \nSupported portname's are M_AXI_FPD/M_AXI_LPD ");
	end
     end
  endtask
 
  /* API to select the CCI port number. In case of single CCI port selection */
  /* cci_port_number: 4'h1: CCI0,
                      4'h2: CCI1,
		      4'h4: CCI2,
		      4'h8: CCI3,
		      4'h0: Disabled single port configuration,
		      remaining combinations are reserved */
  task en_route_to_single_cci;
     input [3:0]   cci_port_num; // 4'h1: CCI0, 4'h2: CCI1, 4'h4: CCI2, 4'h8: CCI3, 4'h0: Disabled single port config

     local_cci_port_num = cci_port_num;
     if((cci_port_num == 4'h1) || (cci_port_num == 4'h2) || (cci_port_num == 4'h4) || (cci_port_num == 4'h8)) begin
        local_route_to_single_cci_port = 1;
     end
     else if(cci_port_num == 4'h0) begin
        local_route_to_single_cci_port = 0;
     end
     else begin
        $fatal(" Wrong CCI port number is programmed. \nSupported CCI port numbers are CCI0: 4'h1, CCI1: 4'h2, CCI2: 4'h4, CCI3: 4'h8, Disable Single CCI port configuration: 4'h0 ");
     end
  endtask


  /* API to enable the multiple clock frequencies support.*/
  task en_multi_clock_support;

     enable_multi_clock_support = 1;
  endtask

  task en_pmc_alias_region;
     enable_pmc_alias_region = 1;
  endtask
  
  /* API to set the interrupt from PS to PL */
  /* intr_type: 2'b01: IRQFPD
           2'b10: IRQLPD
	   2'b11: IRQPMC */

  task automatic trigger_interrupt;
     input [1:0] intr_type;
     input [7:0] interrupt_no;
     begin
        if(intr_type == 2'b01)
	begin
	   if(interrupt_no > 31) begin
	      $display("ERROR: [%0s] (%m) :: [trigger_interrupt] [%0d] ::: Wrong interrupt trigger requested. interrupt_no should be <= 31 for intr_type = %0d",DISP_VIP, $time,intr_type);
	      $stop;
	   end
	   else begin
	      local_PSPLIRQFPD[interrupt_no[4:0]] = 1'b1;
	   end
	end
	else if(intr_type == 2'b10)
	begin
	   if(interrupt_no > 99) begin
	      $display("ERROR: [%0s] (%m) :: [trigger_interrupt] [%0d] ::: Wrong interrupt trigger requested. interrupt_no should be <= 91 for intr_type = %0d",DISP_VIP, $time,intr_type);
	      $stop;
	   end
	   else begin
	      local_PSPLIRQLPD[interrupt_no] = 1'b1;
	   end
	end
	else if(intr_type == 2'b11)
	   if(interrupt_no > 63) begin
	      $display("ERROR: [%0s] (%m) :: [trigger_interrupt] [%0d] ::: Wrong interrupt trigger requested. interrupt_no should be <= 63 for intr_type = %0d",DISP_VIP, $time,intr_type);
	      $stop;
	   end
	   else begin
	      local_PSPLIRQPMC[interrupt_no[6:0]] = 1'b1;
	   end
	end
  endtask

  /* API to clear the interrupt from PS to PL */
  /* intr_type: 2'b01: IRQFPD
           2'b10: IRQLPD
	   2'b11: IRQPMC */

  task automatic clear_interrupt;
     input [1:0] intr_type;
     input [7:0] interrupt_no;
     begin
        if(intr_type == 2'b01)
	begin
	   if(interrupt_no > 31) begin
	      $display("ERROR: [%0s] (%m) :: [clear_interrupt] [%0d] ::: Wrong interrupt clear requested. interrupt_no should be <= 31 for intr_type = %0d",DISP_VIP, $time,intr_type);
	      $stop;
	   end
	   else begin
	      local_PSPLIRQFPD[interrupt_no[4:0]] = 1'b0;
	   end
	end
	else if(intr_type == 2'b10)
	begin
	   if(interrupt_no > 99) begin
	      $display("ERROR: [%0s] (%m) :: [clear_interrupt] [%0d] ::: Wrong interrupt clear requested. interrupt_no should be <= 99 for intr_type = %0d",DISP_VIP, $time,intr_type);
	      $stop;
	   end
	   else begin
	      local_PSPLIRQLPD[interrupt_no] = 1'b0;
	   end
	end
	else if(intr_type == 2'b11)
	   if(interrupt_no > 63) begin
	      $display("ERROR: [%0s] (%m) :: [clear_interrupt] [%0d] ::: Wrong interrupt clear requested. interrupt_no should be <= 63 for intr_type = %0d",DISP_VIP, $time,intr_type);
	      $stop;
	   end
	   else begin
	      local_PSPLIRQPMC[interrupt_no[6:0]] = 1'b0;
	   end
	end
  endtask

  /* API to read interrupt status */
  task automatic read_interrupt;
    output[irq_width-1:0] irq_status;
    begin
      irq_status = {PLPSIRQ1,PLPSIRQ0};
      if(DEBUG_INFO) $display("INFO: [%0s] (%m) :: [read_interrupt] [%0d] ::: Reading Interrupt Status {PLPSIRQ1,PLPSIRQ0} as 0x%0h",DISP_VIP, $time, irq_status);
    end
  endtask

  /* API to wait on interrup */
  task automatic wait_interrupt;
    input [3:0] irq;
    output[irq_width-1:0] irq_status;
    begin
      if(DEBUG_INFO) begin
         if(irq <= 7) begin
            $display("INFO: [%0s] (%m) :: [wait_interrupt] [%0d] ::: Waiting on Interrupt PLPSIRQ0[%0d]",DISP_VIP, $time, irq[2:0]);
	 end
	 else begin
            $display("INFO: [%0s] (%m) :: [wait_interrupt] [%0d] ::: Waiting on Interrupt PLPSIRQ1[%0d]",DISP_VIP, $time, irq[2:0]);
	 end
      end

      case(irq) 
      0 :  wait(PLPSIRQ0[0] === 1'b1);
      1 :  wait(PLPSIRQ0[1] === 1'b1);
      2 :  wait(PLPSIRQ0[2] === 1'b1);
      3 :  wait(PLPSIRQ0[3] === 1'b1);
      4 :  wait(PLPSIRQ0[4] === 1'b1);
      5 :  wait(PLPSIRQ0[5] === 1'b1);
      6 :  wait(PLPSIRQ0[6] === 1'b1);
      7 :  wait(PLPSIRQ0[7] === 1'b1);
      8 :  wait(PLPSIRQ1[0] === 1'b1);
      9 :  wait(PLPSIRQ1[1] === 1'b1);
      10:  wait(PLPSIRQ1[2] === 1'b1);
      11:  wait(PLPSIRQ1[3] === 1'b1);
      12:  wait(PLPSIRQ1[4] === 1'b1);
      13:  wait(PLPSIRQ1[5] === 1'b1);
      14:  wait(PLPSIRQ1[6] === 1'b1);
      15:  wait(PLPSIRQ1[7] === 1'b1);
      default : $display("ERROR: [%0s] (%m) :: [wait_interrupt] [%0d] ::: Only 16 Interrupt lines are supported",DISP_VIP, $time );
      endcase
      
      irq_status = {PLPSIRQ1,PLPSIRQ0};
      if(DEBUG_INFO) begin
         if(irq <= 7) begin
            $display("INFO: [%0s] (%m) :: [wait_interrupt] [%0d] ::: Waiting on Interrupt PLPSIRQ0[%0d] Done",DISP_VIP, $time, irq[2:0]);
	 end
	 else begin
            $display("INFO: [%0s] (%m) :: [wait_interrupt] [%0d] ::: Waiting on Interrupt PLPSIRQ1[%0d] Done",DISP_VIP, $time, irq[2:0]);
	 end
      end
    end
  endtask

  /* API to wait for a certain match pattern*/ 
//   task automatic wait_mem_update;
//     input[addr_width-1:0] address;
//     input[data_width-1:0] data_in;
//     output[data_width-1:0] data_out;
//     reg[data_width-1:0] datao;
//     begin
//       if(mem_update_key) begin
//         mem_update_key = 0;
//         if(DEBUG_INFO) $display("[%0d] : %0s : 'wait_mem_update' called for Address(0x%0h) , Match Pattern(0x%0h) \n",DISP_VIP, $time, DISP_INFO, address, data_in); 
//         if(check_addr_aligned(address)) begin
//          ddrc.ddr.wait_mem_update(address, datao);
//          if(datao != data_in)begin 
//            $display("[%0d] : %0s : Address(0x%0h) -> DATA PATTERN MATCH FAILED, Expected data = 0x%0h, Received data = 0x%0h \n",DISP_VIP, $time, DISP_ERR, address, data_in,datao);
//            $stop;
//          end else
//            $display("[%0d] : %0s : Address(0x%0h) -> DATA PATTERN(0x%0h) MATCHED \n",DISP_VIP, $time, DISP_INFO,  address, data_in);
//          data_out = datao;
//         end else begin
//            $display("[%0d] : %0s : Address(0x%0h) has to be 32-bit aligned. 'wait_mem_update' call failed ...\n",$time, DISP_ERR,  address); 
//            if(STOP_ON_ERROR) $stop;
//         end
//         mem_update_key = 1;
//       end else 
//         $display("[%0d] : %0s : One instance of 'wait_mem_update' thread is already running.Only one instance can be called at a time ...\n",$time, DISP_WARN); 
//     end
//   endtask

/* API to initiate a WRITE transaction on one of the AXI-Master ports*/ 
  task automatic write_from_file;
    input [1023:0] master_name;
    input [(max_chars*8)-1:0] file_name;
    input [addr_width-1:0] start_addr;
    input [int_width-1:0] wr_size;
    output [axi_rsp_width-1:0] response;
    integer succ;
    begin
       //succ = $fopen(file_name,"r+");
       smart_intr_i.check_routing_config();
       succ = $fopen(file_name,"r");
       if(succ == 0) begin
         $display("ERROR: [%0s] (%m) :: [write_from_file] [%0d] ::: '%0s' doesn't exist. 'write_from_file' call failed ...\n",DISP_VIP, $time, file_name); 
         if(STOP_ON_ERROR) $stop; 
       end   
       //else if(!check_master_address(start_addr,master_name)) begin
       //   $display("ERROR: [%0s] (%m) :: [write_from_file] [%0d] ::: Requested Address(0x%0h) is out of range\n",DISP_VIP, $time, start_addr); 
       //   if(STOP_ON_ERROR) $stop;
       //end
       else if(check_addr_aligned(start_addr)) begin
          $fclose(succ);
          if ( master_name == "R5_API") begin//R5_MASTER
             if(DEBUG_INFO)
               $display("INFO: [%0s] (%m) :: [write_from_file] [%0d] ::: [R5_API] AXI Write with Starting Address(0x%0h) and %0d bytes from file %0s",DISP_VIP, $time, start_addr, wr_size, file_name); 
             R5_API.write_from_file(file_name,start_addr,wr_size,response);
             if(DEBUG_INFO)
               $display("INFO: [%0s] (%m) :: [write_from_file] [%0d] ::: [R5_API] Done AXI Write with Starting Address(0x%0h)",DISP_VIP, $time, start_addr); 
          end else if (master_name == "NOC_API") begin//NOC_MASTER
             if(DEBUG_INFO)
               $display("INFO: [%0s] (%m) :: [write_from_file] [%0d] ::: [NOC_API] AXI Write with Starting Address(0x%0h) and %0d bytes from file %0s",DISP_VIP, $time, start_addr, wr_size, file_name); 
             NOC_API.write_from_file(file_name,start_addr,wr_size,response);
             if(DEBUG_INFO)
               $display("INFO: [%0s] (%m) :: [write_from_file] [%0d] ::: [NOC_API] Done AXI Write with Starting Address(0x%0h)",DISP_VIP, $time, start_addr); 
          end else if (master_name == "A72_API") begin//AFI_MASTER
             if(DEBUG_INFO)
               $display("INFO: [%0s] (%m) :: [write_from_file] [%0d] ::: [A72_API] AXI Write with Starting Address(0x%0h) and %0d bytes from file %0s",DISP_VIP, $time, start_addr, wr_size, file_name); 
             A72_API.write_from_file(file_name,start_addr,wr_size,response);
             if(DEBUG_INFO)
               $display("INFO: [%0s] (%m) :: [write_from_file] [%0d] ::: [A72_API] Done AXI Write with Starting Address(0x%0h)",DISP_VIP, $time, start_addr); 
          end 
       end else begin
           $display("ERROR: [%0s] (%m) :: [write_from_file] [%0d] ::: Address(0x%0h) has to be 32-bit aligned. 'write_from_file' call failed ...\n",DISP_VIP, $time, start_addr); 
           if(STOP_ON_ERROR) $stop;
       end
    end
  endtask
 
//  /* API to initiate a READ transaction on one of the AXI-Master ports*/ 
  task automatic read_to_file;
    input [1023:0] master_name;
    input [(max_chars*8)-1:0] file_name;
    input [addr_width-1:0] start_addr;
    input [int_width-1:0] rd_size;
    output [axi_rsp_width-1:0] response;
    begin
       //if(!check_master_address(start_addr,master_name)) begin
       //   $display("ERROR: [%0s] (%m) :: [read_to_file] [%0d] ::: Requested Address(0x%0h) is out of range\n",DISP_VIP, $time, start_addr); 
       //   if(STOP_ON_ERROR) $stop;
       //end else
       smart_intr_i.check_routing_config();

       if(check_addr_aligned(start_addr)) begin
          if (master_name == "R5_API") begin//R5_MASTER
             if(DEBUG_INFO)
                $display("INFO: [%0s] (%m) :: [read_to_file] [%0d] ::: [R5_API] AXI Read with Starting Address(0x%0h) and %0d bytes to file %0s",DISP_VIP, $time, start_addr, rd_size, file_name); 
             R5_API.read_to_file(file_name,start_addr,rd_size,response);
             if(DEBUG_INFO)
                $display("INFO: [%0s] (%m) :: [read_to_file] [%0d] ::: [R5_API] Done AXI Read with Starting Address(0x%0h)",DISP_VIP, $time, start_addr); 
          end else if (master_name == "NOC_API") begin//NOC_MASTER
             if(DEBUG_INFO)
                $display("INFO: [%0s] (%m) :: [read_to_file] [%0d] ::: [NOC_API] AXI Read with Starting Address(0x%0h) and %0d bytes to file %0s",DISP_VIP, $time, start_addr, rd_size, file_name); 
             NOC_API.read_to_file(file_name,start_addr,rd_size,response);
             if(DEBUG_INFO)
                $display("INFO: [%0s] (%m) :: [read_to_file] [%0d] ::: [NOC_API] Done AXI Read with Starting Address(0x%0h)",DISP_VIP, $time, start_addr); 
          end else if (master_name == "A72_API") begin//AFI_MASTER
             if(DEBUG_INFO)
                $display("INFO: [%0s] (%m) :: [read_to_file] [%0d] ::: [A72_API] AXI Read with Starting Address(0x%0h) and %0d bytes to file %0s",DISP_VIP, $time, start_addr, rd_size, file_name); 
             A72_API.read_to_file(file_name,start_addr,rd_size,response);
             if(DEBUG_INFO)
                $display("INFO: [%0s] (%m) :: [read_to_file] [%0d] ::: [A72_API] Done AXI Read with Starting Address(0x%0h)",DISP_VIP, $time, start_addr); 
          end
       end else begin
           $display("ERROR: [%0s] (%m) :: [read_to_file] [%0d] ::: Address(0x%0h) has to be 32-bit aligned. 'read_to_file' call failed ...\n",DISP_VIP, $time, start_addr); 
           if(STOP_ON_ERROR) $stop;
       end
    end
  endtask
  
  //  /* API to initiate a WRITE transaction of 32-bit (<= 16 bytes) on one of the AXI-Master ports*/ 
  task automatic write_data_32;
     input  [1023:0] master_name;
     input  [addr_width-1:0] start_addr;
     input  [31:0] w_data;
     output [axi_rsp_width-1:0] response;
     bit    [127:0] wr_data_128;
     bit    [3:0]  addr_offset;

     begin
       
        smart_intr_i.check_routing_config();
        
	addr_offset = start_addr[3:0];
	if(addr_offset % 4 != 0) begin
           $display("ERROR: [%0s] (%m) :: [write_data_32] [%0d] ::: Invalid Address(0x%0h) 'write_data_32' call failed ...\n",DISP_VIP, $time, start_addr);
	   $stop;
	end
	if(DEBUG_INFO)
           $display("INFO: [%0s] (%m) :: [write_data_32] [%0d] ::: addr:%0h : wr_data = %0h ..\n",DISP_VIP, $time, start_addr, w_data);
	write_burst_internal(master_name,start_addr,0,2,1,0,0,0,w_data,0,response);

     end
  endtask

  //  /* API to initiate a WRITE transaction of 64-bit(<= 16 bytes) on one of the AXI-Master ports*/ 
  task automatic write_data_64;
     input  [1023:0] master_name;
     input  [addr_width-1:0] start_addr;
     input  [63:0] w_data;
     output [axi_rsp_width-1:0] response;
     bit    [127:0] wr_data_128;
     bit    [3:0]  addr_offset;

     begin
        
	smart_intr_i.check_routing_config();
        
	addr_offset = start_addr[3:0];
	
	if(addr_offset % 8 != 0) begin
           $display("ERROR: [%0s] (%m) :: [write_data_64] [%0d] ::: Invalid Address(0x%0h) 'write_data_64' call failed ...\n",DISP_VIP, $time, start_addr);
	   $stop;
	end
	if(DEBUG_INFO)
           $display("INFO: [%0s] (%m) :: [write_data_64] [%0d] ::: addr:%0h : wr_data = %0h ..\n",DISP_VIP, $time, start_addr, w_data);
	write_burst_internal(master_name,start_addr,0,3,1,0,0,0,w_data,8,response);

     end
  endtask

//  /* API to initiate a WRITE transaction(<= 128 bytes) on one of the AXI-Master ports*/ 
  task automatic write_data;
    input [1023:0] master_name;
    input [addr_width-1:0] start_addr;
    input [max_transfer_bytes_width:0] wr_size;
    input [(max_transfer_bytes*8)-1:0] w_data;
    output [axi_rsp_width-1:0] response;
    reg[511:0] rsp;
    bit    [3:0]  addr_offset;
    begin
     
     smart_intr_i.check_routing_config();
     
     addr_offset = start_addr[3:0];
     
     if(addr_offset != 0) begin
        $display("INFO: [%0s] (%m) :: [write_data] [%0d] ::: w_data should be declared as 128-bit and data position should be aligned to the address \n",DISP_VIP, $time);
     end

     //if(!check_master_address(start_addr,master_name)) begin
     //     $display("ERROR: [%0s] (%m) :: [write_data] [%0d] ::: Requested Address(0x%0h) is out of range. 'write_data' call failed ...\n",DISP_VIP, $time, start_addr); 
     //     if(STOP_ON_ERROR) $stop;
     //end else
     if(wr_size > 16) begin
          $display("ERROR: [%0s] (%m) :: [write_data] [%0d] ::: Byte Size (wr_size) supported is 16 bytes only. 'write_data' call failed ...\n",DISP_VIP, $time, start_addr); 
          if(STOP_ON_ERROR) $stop;
     end else if(master_name == "R5_API") begin//R5_MASTER
        //if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data] [%0d] ::: [R5_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, wr_size); 
        R5_API.write_data(start_addr,wr_size,w_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data] [%0d] ::: [R5_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data] [%0d] ::: [NOC_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, wr_size); 
        NOC_API.write_data(start_addr,wr_size,w_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data] [%0d] ::: [NOC_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//AFI_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data] [%0d] ::: [A72_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, wr_size); 
        A72_API.write_data(start_addr,wr_size,w_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data] [%0d] ::: [A72_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [write_data] [%0d] ::: Invalid Address(0x%0h) 'write_data' call failed ...\n",DISP_VIP, $time, start_addr); 
    end
  endtask

  task automatic write_data_internal;
    input [1023:0] master_name;
    input [addr_width-1:0] start_addr;
    input [max_transfer_bytes_width:0] wr_size;
    input [(max_transfer_bytes*8)-1:0] w_data;
    output [axi_rsp_width-1:0] response;
    reg[511:0] rsp;
    bit    [3:0]  addr_offset;
    begin
     
     smart_intr_i.check_routing_config();
     
     addr_offset = start_addr[3:0];
     
     if(wr_size > 16) begin
          $display("ERROR: [%0s] (%m) :: [write_data_internal] [%0d] ::: Byte Size (wr_size) supported is 16 bytes only. 'write_data_internal' call failed ...\n",DISP_VIP, $time, start_addr); 
          if(STOP_ON_ERROR) $stop;
     end else if(master_name == "R5_API") begin//R5_MASTER
        //if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data_internal] [%0d] ::: [R5_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, wr_size); 
        R5_API.write_data(start_addr,wr_size,w_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data_internal] [%0d] ::: [R5_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data_internal] [%0d] ::: [NOC_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, wr_size); 
        NOC_API.write_data(start_addr,wr_size,w_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data_internal] [%0d] ::: [NOC_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//AFI_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data_internal] [%0d] ::: [A72_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, wr_size); 
        A72_API.write_data(start_addr,wr_size,w_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_data_internal] [%0d] ::: [A72_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [write_data_internal] [%0d] ::: Invalid Address(0x%0h) 'write_data_internal' call failed ...\n",DISP_VIP, $time, start_addr); 
    end
  endtask

//  /* API to initiate a READ transaction of 32-bit (<= 16 bytes) on one of the AXI-Master ports*/ 
  task automatic read_data_32;
    input  [1023:0] master_name;
    input  [addr_width-1:0] start_addr;
    output [31:0] rd_data_32;
    output [axi_rsp_width-1:0] response;
    bit    [127:0] rd_data_128;
    bit    [3:0]   addr_offset;

    begin
        smart_intr_i.check_routing_config();
	
	addr_offset = start_addr[3:0];
	
	if(addr_offset % 4 != 0) begin
           $display("ERROR: [%0s] (%m) :: [read_data_32] [%0d] ::: Invalid Address(0x%0h) 'read_data_32' call failed ...\n",DISP_VIP, $time, start_addr);
	   $stop;
	end

	read_burst_internal(master_name,start_addr,0,2,1,0,0,0,rd_data_128,response);
	rd_data_32  = rd_data_128[31:0];
    end
endtask

//  /* API to initiate a READ transaction of 64-bit (<= 16 bytes) on one of the AXI-Master ports*/ 
  task automatic read_data_64;
    input  [1023:0] master_name;
    input  [addr_width-1:0] start_addr;
    output [63:0] rd_data_64;
    output [axi_rsp_width-1:0] response;
    bit    [127:0] rd_data_128;
    bit    [3:0]   addr_offset;

    begin
        
	smart_intr_i.check_routing_config();
	
	addr_offset = start_addr[3:0];
	
	if(addr_offset % 8 != 0) begin
           $display("ERROR: [%0s] (%m) :: [read_data_64] [%0d] ::: Invalid Address(0x%0h) 'read_data_64' call failed ...\n",DISP_VIP, $time, start_addr);
	   $stop;
	end

        read_burst_internal(master_name,start_addr,0,3,1,0,0,0,rd_data_128,response);
	rd_data_64 = rd_data_128[63:0];

    end
endtask

//  /* API to initiate a READ transaction(<= 128 bytes) on one of the AXI-Master ports*/ 
  task automatic read_data;
    input  [1023:0] master_name;
    input  [addr_width-1:0] start_addr;
    input  [max_transfer_bytes_width:0] rd_size;
    output [(max_transfer_bytes*8)-1:0] rd_data;
    output [axi_rsp_width-1:0] response;
    reg    [511:0] rsp;
    bit    [3:0]  addr_offset;

    begin
     
     smart_intr_i.check_routing_config();
     
     addr_offset = start_addr[3:0];
     
     if(rd_size > 16) begin
          $display("ERROR: [%0s] (%m) :: [read_data] [%0d] ::: Byte Size (rd_szie) supported is 16 bytes only.'read_data' call failed ... \n",DISP_VIP, $time, start_addr); 
          if(STOP_ON_ERROR) $stop;
     end else if(master_name == "R5_API") begin//R5_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data] [%0d] ::: [R5_API] AXI Read with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, rd_size); 
        R5_API.read_data(start_addr,rd_size,rd_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data] [%0d] ::: [R5_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data] [%0d] ::: [NOC_API] AXI Read with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, rd_size); 
        NOC_API.read_data(start_addr,rd_size,rd_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data] [%0d] ::: [NOC_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//AFI_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data] [%0d] ::: [A72_API] AXI Read with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, rd_size); 
        A72_API.read_data(start_addr,rd_size,rd_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data] [%0d] ::: Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [read_data] [%0d] ::: Invalid Address(0x%0h) 'read_data' call failed ...\n",DISP_VIP, $time, start_addr); 
     end
  endtask

  task automatic read_data_internal;
    input  [1023:0] master_name;
    input  [addr_width-1:0] start_addr;
    input  [max_transfer_bytes_width:0] rd_size;
    output [(max_transfer_bytes*8)-1:0] rd_data;
    output [axi_rsp_width-1:0] response;
    reg    [511:0] rsp;
    bit    [3:0]  addr_offset;

    begin
     
     smart_intr_i.check_routing_config();
     
     addr_offset = start_addr[3:0];
     
//     if(addr_offset != 0) begin
//        $display("INFO: [%0s] (%m) :: [read_data_internal] [%0d] ::: rd_data should be declared as 128-bit and the data position is aligned to the address \n",DISP_VIP, $time);
//     end
     
     //if(!check_master_address(start_addr,master_name)) begin
     //   $display("ERROR: [%0s] (%m) :: [read_data_internal] [%0d] ::: Requested Address(0x%0h) is out of range 'read_data' call failed ...\n",DISP_VIP, $time, start_addr); 
     //   if(STOP_ON_ERROR) $stop;
     //end else
     if(rd_size > 16) begin
          $display("ERROR: [%0s] (%m) :: [read_data_internal] [%0d] ::: Byte Size (rd_szie) supported is 16 bytes only.'read_data' call failed ... \n",DISP_VIP, $time, start_addr); 
          if(STOP_ON_ERROR) $stop;
     end else if(master_name == "R5_API") begin//R5_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data_internal] [%0d] ::: [R5_API] AXI Read with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, rd_size); 
        R5_API.read_data(start_addr,rd_size,rd_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data_internal] [%0d] ::: [R5_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data_internal] [%0d] ::: [NOC_API] AXI Read with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, rd_size); 
        NOC_API.read_data(start_addr,rd_size,rd_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data_internal] [%0d] ::: [NOC_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//AFI_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data_internal] [%0d] ::: [A72_API] AXI Read with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, rd_size); 
        A72_API.read_data(start_addr,rd_size,rd_data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_data_internal] [%0d] ::: Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [read_data_internal] [%0d] ::: Invalid Address(0x%0h) 'read_data' call failed ...\n",DISP_VIP, $time, start_addr); 
     end
  endtask

// /* Hooks to call to BFM APIs */
  task automatic write_burst(input [1023:0] master_name,  input [addr_width-1:0] start_addr,input [axi_len_width-1:0] len,input [axi_size_width-1:0] siz,input [axi_brst_type_width-1:0] burst,input [axi_lock_width-1:0] lck,input [axi_cache_width-1:0] cache,input [axi_prot_width-1:0] prot,input [(axi_max_mdata_width*axi_burst_len)-1:0] data,input integer datasize, output [axi_rsp_width-1:0] response);
    reg[511:0] rsp;
    begin
     
     smart_intr_i.check_routing_config();
     
     //if(!check_master_address(start_addr,master_name)) begin
     //   $display("ERROR: [%0s] (%m) :: [write_burst] [%0d] ::: Requested Address(0x%0h) is out of range. 'write_burst' call failed ...\n",DISP_VIP, $time, start_addr); 
     //   if(STOP_ON_ERROR) $stop;
     //end else
     if(master_name == "R5_API") begin//R5_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst] [%0d] ::: [R5_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, datasize); 
        R5_API.write_burst(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst] [%0d] ::: [R5_API] Done AXI Write for Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst] [%0d] ::: [NOC_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, datasize); 
        NOC_API.write_burst(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst] [%0d] ::: [NOC_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//A72_API
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst] [%0d] ::: [A72_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, datasize); 
        A72_API.write_burst(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst] [%0d] ::: [A72_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [write_burst] [%0d] ::: Invalid Address(0x%0h) 'write_burst' call failed ... \n",DISP_VIP, $time, start_addr); 
    end
  endtask 

// /* Hooks to call to BFM APIs */
  task automatic write_burst_internal(input [1023:0] master_name,  input [addr_width-1:0] start_addr,input [axi_len_width-1:0] len,input [axi_size_width-1:0] siz,input [axi_brst_type_width-1:0] burst,input [axi_lock_width-1:0] lck,input [axi_cache_width-1:0] cache,input [axi_prot_width-1:0] prot,input [(axi_max_mdata_width*axi_burst_len)-1:0] data,input integer datasize, output [axi_rsp_width-1:0] response);
    reg[511:0] rsp;
    begin
     
     smart_intr_i.check_routing_config();
     
     if(master_name == "R5_API") begin//R5_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst_internal] [%0d] ::: [R5_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, datasize); 
        R5_API.write_burst(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst_internal] [%0d] ::: [R5_API] Done AXI Write for Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst_internal] [%0d] ::: [NOC_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, datasize); 
        NOC_API.write_burst(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst_internal] [%0d] ::: [NOC_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//A72_API
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst_internal] [%0d] ::: [A72_API] AXI Write with Starting Address(0x%0h) and %0d bytes",DISP_VIP, $time, start_addr, datasize); 
        A72_API.write_burst(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [write_burst_internal] [%0d] ::: [A72_API] Done AXI Write with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [write_burst_internal] [%0d] ::: Invalid Address(0x%0h) 'write_burst_internal' call failed ... \n",DISP_VIP, $time, start_addr); 
    end
  endtask 
  
// /* Hooks to call to BFM APIs */
  task automatic write_burst_strb(input [1023:0] master_name, input [addr_width-1:0] start_addr,input [axi_len_width-1:0] len,input [axi_size_width-1:0] siz,input [axi_brst_type_width-1:0] burst,input [axi_lock_width-1:0] lck,input [axi_cache_width-1:0] cache,input [axi_prot_width-1:0] prot,input [(axi_max_mdata_width*axi_burst_len)-1:0] data,input strb_en,input [(axi_mgp_data_width*axi_burst_len)/8-1:0] strb,input integer datasize, output [axi_rsp_width-1:0] response);
    reg[511:0] rsp;
    begin
     
     smart_intr_i.check_routing_config();
     
     //if(!check_master_address(start_addr,master_name)) begin
     //   $display("ERROR: [%0s] (%m) :: [por_reset] [%0d] ::: Master Address(0x%0h) is out of range. 'write_burst_strb' call failed ...\n",DISP_VIP, $time, start_addr); 
     //   if(STOP_ON_ERROR) $stop;
     //end else
     if(master_name == "R5_API") begin//R5_MASTER
        //if(DEBUG_INFO)
        //  $display("[%0d] : R5_API : %0s : Starting Address(0x%0h) -> AXI Write -> %0d bytes",$time, DISP_INFO,  start_addr, datasize); 
        R5_API.write_burst_strb(start_addr,len,siz,burst,lck,cache,prot,data,strb_en,strb,datasize,response);
        rsp = get_resp(response);
        //if(DEBUG_INFO)
        //  $display("[%0d] : R5_API : %0s : Done AXI Write for Starting Address(0x%0h) with Response '%0s'",$time, DISP_INFO,  start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        //if(DEBUG_INFO)
        //  $display("[%0d] : NOC_API : %0s : Starting Address(0x%0h) -> AXI Write -> %0d bytes",$time, DISP_INFO,  start_addr, datasize); 
        NOC_API.write_burst_strb(start_addr,len,siz,burst,lck,cache,prot,data,strb_en,strb,datasize,response);
        rsp = get_resp(response);
        //if(DEBUG_INFO)
        //  $display("[%0d] : NOC_API : %0s : Done AXI Write for Starting Address(0x%0h) with Response '%0s'",$time, DISP_INFO,  start_addr, rsp); 
     end else if(master_name == "A72_API") begin//AFI_MASTER
        //if(DEBUG_INFO)
        //  $display("[%0d] : A72_API : %0s : Starting Address(0x%0h) -> AXI Write -> %0d bytes",$time, DISP_INFO,  start_addr, datasize); 
        A72_API.write_burst_strb(start_addr,len,siz,burst,lck,cache,prot,data,strb_en,strb,datasize,response);
        rsp = get_resp(response);
        //if(DEBUG_INFO)
        //  $display("[%0d] : A72_API : %0s : Done AXI Write for Starting Address(0x%0h) with Response '%0s'",$time, DISP_INFO,  start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [write_burst_strb] [%0d] ::: Invalid Address(0x%0h) 'write_burst_strb' call failed ... \n",DISP_VIP, $time, start_addr); 
    end
  endtask 
 
//  task automatic write_burst_concurrent(input [1023:0] master_name, input [addr_width-1:0] start_addr,input [axi_len_width-1:0] len,input [axi_size_width-1:0] siz,input [axi_brst_type_width-1:0] burst,input [axi_lock_width-1:0] lck,input [axi_cache_width-1:0] cache,input [axi_prot_width-1:0] prot,input [(axi_max_mdata_width*axi_burst_len)-1:0] data,input integer datasize, output [axi_rsp_width-1:0] response);
//    reg[511:0] rsp; /// string for response
//    begin
//     if(!check_master_address(start_addr,master_name)) begin
//        $display("[%0d] : %0s : Master Address(0x%0h) is out of range. 'write_burst_concurrent' call failed ...\n",$time, start_addr); 
//        if(STOP_ON_ERROR) $stop;
//     end else if(master_name == "R5_API") begin//R5_MASTER
//        if(DEBUG_INFO)
//          $display("[%0d] : R5_API : %0s : Starting Address(0x%0h) -> AXI Write -> %0d bytes",$time, start_addr, datasize); 
//        R5_API.write_burst_concurrent(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
//        rsp = get_resp(response);
//        if(DEBUG_INFO)
//          $display("[%0d] : R5_API : %0s : Done AXI Write for Starting Address(0x%0h) with Response '%0s'",$time, start_addr, rsp); 
//     end else if(master_name == "NOC_API") begin//NOC_MASTER
//        if(DEBUG_INFO)
//          $display("[%0d] : NOC_API : %0s : Starting Address(0x%0h) -> AXI Write -> %0d bytes",$time, start_addr, datasize); 
//        NOC_API.write_burst_concurrent(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
//        rsp = get_resp(response);
//        if(DEBUG_INFO)
//          $display("[%0d] : NOC_API : %0s : Done AXI Write for Starting Address(0x%0h) with Response '%0s'",$time, start_addr, rsp); 
//     end else if(master_name == "A72_API") begin//AFI_MASTER
//        if(DEBUG_INFO)
//          $display("[%0d] : A72_API : %0s : Starting Address(0x%0h) -> AXI Write -> %0d bytes",$time, start_addr, datasize); 
//        A72_API.write_burst_concurrent(start_addr,len,siz,burst,lck,cache,prot,data,datasize,response);
//        rsp = get_resp(response);
//        if(DEBUG_INFO)
//          $display("[%0d] : A72_API : %0s : Done AXI Write for Starting Address(0x%0h) with Response '%0s'",$time, start_addr, rsp); 
//     end else
//        $display("[%0d] : %0s : Invalid Address(0x%0h) 'write_burst_concurrent' call failed ... \n",$time, start_addr); 
//    end
//  endtask 
 
  task automatic read_burst;
    input [1023:0] master_name;
    input [addr_width-1:0] start_addr;
    input [axi_len_width-1:0] len;
    input [axi_size_width-1:0] siz;
    input [axi_brst_type_width-1:0] burst;
    input [axi_lock_width-1:0] lck;
    input [axi_cache_width-1:0] cache;
    input [axi_prot_width-1:0] prot;
    output [(axi_max_mdata_width*axi_burst_len)-1:0] data;
    output [(axi_rsp_width*axi_burst_len)-1:0] response;
    reg[511:0] rsp;
    begin
     
     smart_intr_i.check_routing_config();
     
     //if(!check_master_address(start_addr,master_name)) begin
     //   $display("ERROR: [%0s] (%m) :: [read_burst] [%0d] ::: Requested Address(0x%0h) is out of range. 'read_burst' call failed ...\n",DISP_VIP, $time, start_addr); 
     //   if(STOP_ON_ERROR) $stop;
     //end else
     if(master_name == "R5_API") begin//R5_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst] [%0d] ::: [R5_API] AXI Read with Starting Address(0x%0h) is initiated",DISP_VIP, $time, start_addr); 
        R5_API.read_burst(start_addr,len,siz,burst,lck,cache,prot,data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst] [%0d] ::: [R5_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst] [%0d] ::: [NOC_API] AXI Read with Starting Address(0x%0h) is initiated",DISP_VIP, $time, start_addr); 
        NOC_API.read_burst(start_addr,len,siz,burst,lck,cache,prot,data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst] [%0d] ::: [NOC_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//AFI_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst] [%0d] ::: [A72_API] AXI Read with Starting Address(0x%0h) is initiated",DISP_VIP, $time, start_addr); 
        A72_API.read_burst(start_addr,len,siz,burst,lck,cache,prot,data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst] [%0d] ::: [A72_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [read_burst] [%0d] ::: Invalid Address(0x%0h) 'read_burst' call failed ... \n",DISP_VIP, $time, start_addr); 
     end
  endtask 

  task automatic read_burst_internal;
    input [1023:0] master_name;
    input [addr_width-1:0] start_addr;
    input [axi_len_width-1:0] len;
    input [axi_size_width-1:0] siz;
    input [axi_brst_type_width-1:0] burst;
    input [axi_lock_width-1:0] lck;
    input [axi_cache_width-1:0] cache;
    input [axi_prot_width-1:0] prot;
    output [(axi_max_mdata_width*axi_burst_len)-1:0] data;
    output [(axi_rsp_width*axi_burst_len)-1:0] response;
    reg[511:0] rsp;
    begin
     
     smart_intr_i.check_routing_config();
     
     if(master_name == "R5_API") begin//R5_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst_internal] [%0d] ::: [R5_API] AXI Read with Starting Address(0x%0h) is initiated",DISP_VIP, $time, start_addr); 
        R5_API.read_burst(start_addr,len,siz,burst,lck,cache,prot,data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst_internal] [%0d] ::: [R5_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "NOC_API") begin//NOC_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst_internal] [%0d] ::: [NOC_API] AXI Read with Starting Address(0x%0h) is initiated",DISP_VIP, $time, start_addr); 
        NOC_API.read_burst(start_addr,len,siz,burst,lck,cache,prot,data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst_internal] [%0d] ::: [NOC_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else if(master_name == "A72_API") begin//AFI_MASTER
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst_internal] [%0d] ::: [A72_API] AXI Read with Starting Address(0x%0h) is initiated",DISP_VIP, $time, start_addr); 
        A72_API.read_burst(start_addr,len,siz,burst,lck,cache,prot,data,response);
        rsp = get_resp(response);
        if(DEBUG_INFO)
          $display("INFO: [%0s] (%m) :: [read_burst_internal] [%0d] ::: [A72_API] Done AXI Read with Starting Address(0x%0h) with Response '%0s'",DISP_VIP, $time, start_addr, rsp); 
     end else
        $display("ERROR: [%0s] (%m) :: [read_burst_internal] [%0d] ::: Invalid Address(0x%0h) 'read_burst_internal' call failed ... \n",DISP_VIP, $time, start_addr); 
     end
  endtask

//  task automatic wait_reg_update;
//    input [1023:0] master_name;
//    input [addr_width-1:0] addr;
//    input [data_width-1:0] data_i;
//    input [data_width-1:0] mask_i;
//    input [int_width-1:0] time_interval;
//    input [int_width-1:0] time_out;
//    output [data_width-1:0] data_o;
// 
//    reg upd_done0;
//    reg upd_done1;
//    reg upd_done2;
//    begin
//     if(!check_master_address(addr,master_name)) begin
//        $display("[%0d] : %0s : Address(0x%0h) is out of range. 'wait_reg_update' call failed ...\n",$time, DISP_ERR,  addr); 
//        if(STOP_ON_ERROR) $stop;
//     end else if(addr[31:28] === 4'b1010) begin//G_MP0
//      if(reg_update_key_0) begin
//        reg_update_key_0 = 0;
//        if(DEBUG_INFO)
//          $display("[%0d] : M_AXI_HPM0_FPD : %0s : 'wait_reg_update' called for Address(0x%0h), Mask(0x%0h), Match Pattern(0x%0h) \n ",$time, DISP_INFO, addr, mask_i, data_i); 
//        M_AXI_HPM0_FPD.wait_reg_update(addr, data_i, mask_i, time_interval, time_out, data_o, upd_done0);
//        if(DEBUG_INFO && upd_done0)
//          $display("[%0d] : M_AXI_HPM0_FPD : %0s : Register mapped at Address(0x%0h) is updated ",$time, DISP_INFO, addr); 
//        reg_update_key_0 = 1;
//      end else
//        $display("[%0d] : M_AXI_HPM0_FPD : One instance of 'wait_reg_update' thread is already running.Only one instance can be called at a time ...\n",$time, DISP_WARN); 
//     end else if(addr[31:28] === 4'b1011) begin//G_MP1
//      if(reg_update_key_1) begin
//        reg_update_key_1 = 0;
//        if(DEBUG_INFO)
//          $display("[%0d] : M_AXI_HPM1_FPD : %0s : 'wait_reg_update' called for Address(0x%0h), Mask(0x%0h), Match Pattern(0x%0h) \n ",$time, DISP_INFO, addr, mask_i, data_i); 
//        M_AXI_HPM1_FPD.wait_reg_update(addr, data_i, mask_i, time_interval, time_out, data_o, upd_done1);
//        if(DEBUG_INFO && upd_done1)
//          $display("[%0d] : M_AXI_HPM1_FPD : %0s : Register mapped at Address(0x%0h) is updated ",$time, DISP_INFO,  addr); 
//        reg_update_key_1 = 1;
//      end else
//        $display("[%0d] : M_AXI_HPM1_FPD : One instance of 'wait_reg_update' thread is already running.Only one instance can be called at a time ...\n",$time, DISP_WARN); 
//     end else if(addr[31:29] === 3'b100) begin//G_MP2
//      if(reg_update_key_2) begin
//        reg_update_key_2 = 0;
//        if(DEBUG_INFO)
//          $display("[%0d] : M_AXI_HPM0_LPD : %0s : 'wait_reg_update' called for Address(0x%0h), Mask(0x%0h), Match Pattern(0x%0h) \n ",$time, DISP_INFO, addr, mask_i, data_i); 
//        M_AXI_HPM0_LPD.wait_reg_update(addr, data_i, mask_i, time_interval, time_out, data_o, upd_done2);
//        if(DEBUG_INFO && upd_done2)
//          $display("[%0d] : M_AXI_HPM0_LPD : %0s : Register mapped at Address(0x%0h) is updated ",$time, DISP_INFO,  addr); 
//        reg_update_key_2 = 1;
//      end else
//        $display("[%0d] : M_AXI_HPM0_LPD : One instance of 'wait_reg_update' thread is already running.Only one instance can be called at a time ...\n",$time, DISP_WARN); 
//     end else
//        $display("[%0d] : %0s : Invalid Address(0x%0h) 'wait_reg_update' call failed ... \n",$time, DISP_ERR, addr); 
//    end
//  endtask 
 
 /* API to read register map */
  task read_register_map;
    input [addr_width-1:0] start_addr;
    input [max_regs_width:0] no_of_registers;
    output[max_burst_bits-1 :0] data;
    reg [max_regs_width:0] no_of_regs;
    begin
     no_of_regs = no_of_registers;
     if(no_of_registers > 32) begin
       $display("[%0d] : %0s : No_of_Registers(%0d) exceeds the supported number (32).\n Only 32 registers will be read.",$time, DISP_ERR, start_addr);
       no_of_regs = 32;
     end
     if(check_addr_aligned(start_addr)) begin
       if(decode_address(start_addr) == REG_MEM) begin
         if(DEBUG_INFO)  $display("[%0d] : %0s : Reading Registers starting address (0x%0h) -> %0d registers",$time, DISP_INFO,  start_addr,no_of_regs ); 
         regc.regm.read_reg_mem(data,start_addr,no_of_regs*4); /// as each register is of 4 bytes
         if(DEBUG_INFO)  $display("[%0d] : %0s : DONE -> Reading Registers starting address (0x%0h), Data returned(0x%0h)",$time, DISP_INFO,  start_addr, data ); 
       end else begin
        $display("[%0d] : %0s : Invalid Address(0x%0h) for Register Read. 'read_register_map' call failed ...",$time, DISP_ERR, start_addr);
       end
     end else begin
        data = 0;
        $display("[%0d] : %0s : Address(0x%0h) has to be 32-bit aligned. 'read_register_map' call failed ...",$time, DISP_ERR, start_addr);
     end
    end
  endtask
 
 /* API to read single register */
  task read_register;
    input [addr_width-1:0] addr;
    output[data_width-1:0] data;
    begin
//     if(check_addr_aligned(addr)) begin
        if(decode_address(addr) == REG_MEM) begin
          if(DEBUG_INFO)  $display("INFO: [%0s] (%m) :: [read_register] [%0d] ::: Reading Register with address (0x%0h) ",DISP_VIP, $time, addr ); 
          regc.regm.get_data(addr >> 2, data);
          if(DEBUG_INFO)  $display("INFO: [%0s] (%m) :: [read_register] [%0d] ::: DONE Reading Register with address (0x%0h), Data returned(0x%0h)",DISP_VIP, $time, addr, data ); 
        end else begin
          $display("ERROR: [%0s] (%m) :: [read_register] [%0d] ::: Invalid Address(0x%0h) for Register Read. 'read_register' call failed ...",DISP_VIP, $time, addr);
        end
//     end else begin
//        data = 0;
//        $display("[%0d] : %0s : Address(0x%0h) has to be 32-bit aligned. 'read_register' call failed ...",DISP_VIP, $time, DISP_ERR, addr);
//     end
 
    end
  endtask

  /* API to write to the single register */
  task write_register;
    input [addr_width-1:0] addr;
    input [data_width-1:0] data;
    input int size;
  begin
     if(decode_address(addr) == REG_MEM) begin
       if(DEBUG_INFO)  $display("INFO: [%0s] (%m) :: [write_register] [%0d] ::: Writing to Register with address (0x%0h) ",DISP_VIP, $time, addr ); 
       regc.regm.set_reset_data(addr, data, size);
       if(DEBUG_INFO)  $display("INFO: [%0s] (%m) :: [write_register] [%0d] ::: DONE Writing to Register with address (0x%0h), Data Written(0x%0h)",DISP_VIP, $time, addr, data ); 
     end else begin
       $display("ERROR: [%0s] (%m) :: [write_register] [%0d] ::: Invalid Address(0x%0h) for Register Write. 'write_register' call failed ...",DISP_VIP, $time, addr);
     end
  end
  endtask

//   /* API to set the AXI-Slave profile*/ 
//  task automatic set_slave_profile;
//     input[1023:0] name;
//     input[1:0] latency ;
//     begin 
//      if(DEBUG_INFO) $display("[%0d] : %0s : %0s Port/s : Setting Slave profile",$time, DISP_INFO,  name);
//      case(name)
//       "S_AXI_OCM" : S_AXI_OCM.set_latency_type(latency);
//       "A72_API"   : A72_API.set_latency_type(latency);
//       "NOC_API"   : NOC_API.set_latency_type(latency);
//       "R5_API"    : R5_API.set_latency_type(latency);
//       "ALL"       : begin
//                        S_AXI_OCM.set_latency_type(latency);
//                        A72_API.set_latency_type(latency);
//                        NOC_API.set_latency_type(latency);
//                        R5_API.set_latency_type(latency);
//                     end  
//      endcase
//     end
//  endtask

/*------------------------------ LOCAL APIs ------------------------------------------------ */

  /* local API for address decoding*/
  function automatic [1:0] decode_address;
    input [addr_width-1:0] address;
    bit   invalid_addr_detected;
    begin

      foreach(slverr_start_addr_a[i]) begin
         if((address >= i) && (address <= slverr_start_addr_a[i])) begin
	    invalid_addr_detected = 1'b1;
	 end
      end

      if(invalid_addr_detected)
        decode_address = INVALID_MEM_TYPE;
      else if(address >= ocm_start_addr && address <= ocm_end_addr )
        decode_address = OCM_MEM; /// OCM 
      else if(address >= ddr_start_addr && address <= ddr_end_addr)
        decode_address = DDR_MEM; /// DDR 
      else if((address >= reg_mem1_start_addr && address <= reg_mem1_end_addr) ||
              (address >= reg_mem2_start_addr && address <= reg_mem2_end_addr) ||
              (address >= reg_mem3_start_addr && address <= reg_mem3_end_addr) ||
              (address >= reg_mem4_start_addr && address <= reg_mem4_end_addr) ||
              (address >= reg_mem5_start_addr && address <= reg_mem5_end_addr) ||
              (address >= reg_mem6_start_addr && address <= reg_mem6_end_addr) ||
              (address >= reg_mem7_start_addr && address <= reg_mem7_end_addr) ||
              (address >= reg_mem8_start_addr && address <= reg_mem8_end_addr) ||
              (address >= reg_mem9_start_addr && address <= reg_mem9_end_addr) ||
              (address >= reg_mem10_start_addr && address <= reg_mem10_end_addr) ||
	      (address >= reg_mem11_start_addr && address <= reg_mem11_end_addr) ||
	      (address >= reg_mem12_start_addr && address <= reg_mem12_end_addr) )
        decode_address = REG_MEM; /// Register Map
      else
        decode_address = INVALID_MEM_TYPE; /// ERROR in Address 
    end
  endfunction 

  /* local API for checking address is 32-bit (4-byte) aligned */
  function automatic check_addr_aligned;
    input [addr_width-1:0] address;
    begin
      if(data_width == 32) begin
         if((address%4) !=0 ) begin // 
           check_addr_aligned = 0; ///not_aligned
         end else
           check_addr_aligned = 1;
      end
      else begin //if(data_width == 128) begin
         if((address%16) !=0 ) begin // 
           check_addr_aligned = 0; ///not_aligned
         end else
           check_addr_aligned = 1;
      end
    end
  endfunction

  /* to convert the fatal messages to warning */
  task automatic fatal_to_warning;
     input [(max_chars*8)-1:0] component_name;
     begin
        if(component_name == "R5_API") begin
           R5_API.master.IF.PC.set_fatal_to_warnings();
	   $display("INFO: [%0s] (%m) :: [fatal_to_warning] [%0d] ::: FATAL Messages are converted to WARNING's for R5_API ",DISP_VIP, $time);
	end
	else if(component_name == "A72_API") begin
           A72_API.master.IF.PC.set_fatal_to_warnings();
	   $display("INFO: [%0s] (%m) :: [fatal_to_warning] [%0d] ::: FATAL Messages are converted to WARNING's for A72_API ",DISP_VIP, $time); 
	end
	else if(component_name == "NOC_API") begin
           NOC_API.master.IF.PC.set_fatal_to_warnings();
	   $display("INFO: [%0s] (%m) :: [fatal_to_warning] [%0d] ::: FATAL Messages are converted to WARNING's for NOC_API ",DISP_VIP, $time);
	end
	else if(component_name == "OCM") begin
           S_AXI_OCM.slave.IF.PC.set_fatal_to_warnings();
	   $display("INFO: [%0s] (%m) :: [fatal_to_warning] [%0d] ::: FATAL Messages are converted to WARNING's for OCM ",DISP_VIP, $time);
	end
	else if(component_name == "REG") begin
           S_AXI_REG1.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG2.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG3.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG4.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG5.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG6.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG7.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG8.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG9.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG10.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG11.slave.IF.PC.set_fatal_to_warnings();
           S_AXI_REG12.slave.IF.PC.set_fatal_to_warnings();
	   $display("INFO: [%0s] (%m) :: [fatal_to_warning] [%0d] ::: FATAL Messages are converted to WARNING's for REG ",DISP_VIP, $time);
	end
	else begin
	   $display("INFO: [%0s] (%m) :: [fatal_to_warning] [%0d] ::: component_name entered is not supported yet...! \n valid arguments are: R5_API, OCM, REG ",DISP_VIP, $time);
	end
     end
  endtask

 /* local API to check address for GP Masters */
 function check_master_address; 
   input [addr_width-1:0] address;
   input [1023:0] master_name;
   
   begin
     if ( master_name == "R5_API") begin
        if(address >= ocm_start_addr && address <= ocm_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= saxigp0_start_addr && address <= saxigp0_end_addr ) 
          check_master_address = 1'b1; 
        else if(address >= saxigp1_start_addr && address <= saxigp1_end_addr) 
          check_master_address = 1'b1;
	else if(address >= pscpm_cfg_start_addr && address <= pscpm_cfg_end_addr) 
          check_master_address = 1'b1;
	else if(address >= pscpmpcie_start_addr && address <= pscpmpcie_end_addr) 
          check_master_address = 1'b1;  
	else if(address >= psnocpci_axi0_start_addr && address <= psnocpci_axi0_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnocnci_axi0_start_addr && address <= psnocnci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnocnci_axi1_start_addr && address <= psnocnci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= pmcnoc_axi_start_addr && address <= pmcnoc_axi_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi_start_addr && address <= psnoccci_axi_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi0_start_addr && address <= psnoccci_axi0_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi1_start_addr && address <= psnoccci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi2_start_addr && address <= psnoccci_axi2_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi3_start_addr && address <= psnoccci_axi3_end_addr) 
          check_master_address = 1'b1;
        else if(address >= rpu_noc_start_addr && address <= rpu_noc_end_addr) 
          check_master_address = 1'b1; 
        else
          check_master_address = 1'b0; /// ERROR in Address 
     end
     else if ( master_name == "NOC_API") begin
        if(address >= ocm_start_addr && address <= ocm_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= saxigp0_start_addr && address <= saxigp0_end_addr ) 
          check_master_address = 1'b1; 
        else if(address >= saxigp1_start_addr && address <= saxigp1_end_addr) 
          check_master_address = 1'b1;
	else if(address >= pscpm_cfg_start_addr && address <= pscpm_cfg_end_addr) 
          check_master_address = 1'b1; 
	else if(address >= pscpmpcie_start_addr && address <= pscpmpcie_end_addr) 
          check_master_address = 1'b1; 
	else if(address >= psnocpci_axi0_start_addr && address <= psnocpci_axi0_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnocnci_axi0_start_addr && address <= psnocnci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnocnci_axi1_start_addr && address <= psnocnci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= pmcnoc_axi_start_addr && address <= pmcnoc_axi_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi_start_addr && address <= psnoccci_axi_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi0_start_addr && address <= psnoccci_axi0_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi1_start_addr && address <= psnoccci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi2_start_addr && address <= psnoccci_axi2_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi3_start_addr && address <= psnoccci_axi3_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= rpu_noc_start_addr && address <= rpu_noc_end_addr) 
          check_master_address = 1'b1; 
        else
          check_master_address = 1'b0; /// ERROR in Address 
     end
     else if ( master_name == "A72_API") begin
        if(address >= ocm_start_addr && address <= ocm_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= saxigp0_start_addr && address <= saxigp0_end_addr ) 
          check_master_address = 1'b1; 
        else if(address >= saxigp1_start_addr && address <= saxigp1_end_addr) 
          check_master_address = 1'b1;
	else if(address >= pscpm_cfg_start_addr && address <= pscpm_cfg_end_addr) 
          check_master_address = 1'b1; 
	else if(address >= pscpmpcie_start_addr && address <= pscpmpcie_end_addr) 
          check_master_address = 1'b1; 
	else if(address >= psnocpci_axi0_start_addr && address <= psnocpci_axi0_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnocnci_axi0_start_addr && address <= psnocnci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnocnci_axi1_start_addr && address <= psnocnci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= pmcnoc_axi_start_addr && address <= pmcnoc_axi_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi_start_addr && address <= psnoccci_axi_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi0_start_addr && address <= psnoccci_axi0_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi1_start_addr && address <= psnoccci_axi1_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi2_start_addr && address <= psnoccci_axi2_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= psnoccci_axi3_start_addr && address <= psnoccci_axi3_end_addr) 
          check_master_address = 1'b1; 
        else if(address >= rpu_noc_start_addr && address <= rpu_noc_end_addr) 
          check_master_address = 1'b1; 
        else
          check_master_address = 1'b0; /// ERROR in Address 
     end
     else begin
       $display("[ERROR]: %0s (%0m) :: [check_master_address] [%0d] ::: ******************Check API Master selection********\n Valid API master's are: R5_API, A72_API, NOC_API",DISP_VIP,$time);
       $stop;
     end

   end
 endfunction

 /* Response decode */
 function automatic [511:0] get_resp;
   input[axi_rsp_width-1:0] response;
   begin 
    case(response)
     2'b00 : get_resp = "OKAY";
     2'b01 : get_resp = "EXOKAY";
     2'b10 : get_resp = "SLVERR";
     2'b11 : get_resp = "DECERR";
    endcase
   end
 endfunction 
 
 /* CCCI CONFIG */
//task automatic cci_config;
//   input[3:0] cci_config_in;
//     begin 
//	   config_reg = cci_config_in;
//     end
//endtask

  task automatic set_routing_config;
    input 	[8191:0] 	slave_port_name;
    input 	[8191:0] 	master_port_name;
    input			routing_en;

    begin
       
       if(routing_en == 1) begin
          $display("INFO: [%0s] (%m) :: [set_routing_config] [%0d] ::: Routing ENABLED. SOURCE: %0s \t\t DESTINATION: %0s ",DISP_VIP, $time,slave_port_name,master_port_name);
       end
       else begin
          $display("INFO: [%0s] (%m) :: [set_routing_config] [%0d] ::: Routing DISABLED. SOURCE: %0s \t\t DESTINATION: %0s ",DISP_VIP, $time,slave_port_name,master_port_name);
       end
       
       smart_intr_i.set_routing_config(master_port_name,slave_port_name,routing_en);
    end
  endtask

  task automatic get_routing_config;
     begin
       //$display("INFO: [%0s] (%m) :: [get_routing_config] [%0d] ::: get_routing_config is called. routing path %0s <--> %0s with routing_en = %0d ",DISP_VIP, $time,slave_port_name,master_port_name,routing_en);
       //$display("[INFO]: %0s (%0m) :: [get_routing_config] [%0d] ::: Routing Configured is ",DISP_VIP,$time);
       smart_intr_i.get_routing_config();
     end
  endtask

  task automatic cfg_slverr_address_range;
     input   [31:0]	slverr_start_address;
     input   [31:0]	slverr_end_address;
     input		set_slv_error;
     begin

        set_slv_err_called = set_slv_error;
	slverr_start_addr  = slverr_start_address;
	slverr_end_addr    = slverr_end_address;

	if(set_slv_error) begin
	   slverr_start_addr_a[slverr_start_address] = slverr_end_address;
           $display("[INFO]: %0s (%0m) :: [cfg_slverr_address_range] [%0d] ::: Adding SLVERR Address range [0x%h - 0x%h] ",DISP_VIP,$time,slverr_start_address,slverr_end_address);
	   //slverr_end_addr_a.first(slverr_end_address);
	end
	else begin

	   foreach(slverr_start_addr_a[i]) begin
	      if((slverr_start_addr_a[i] == slverr_end_address) && (i == slverr_start_address)) begin
	         slverr_start_addr_a.delete(i);
                 $display("[INFO]: %0s (%0m) :: [cfg_slverr_address_range] [%0d] ::: Removing SLVERR Address range [0x%h - 0x%h] ",DISP_VIP,$time,slverr_start_address,slverr_end_address);
	      end
	   end

	end

        $display("\n---------------------------------------------------------------------------------------------------------");
        $display("                           SLVERR Address Ranges Configured ");
        $display("---------------------------------------------------------------------------------------------------------");
	//$display("\n[INFO]: %0s (%0m) :: [cfg_slverr_address_range] [%0d] ::: SLVERR Address ranges configured ",DISP_VIP,$time);
        foreach(slverr_start_addr_a[i]) begin
	   $display("\t\tSLVERR Address range [0x%h \t-\t 0x%h] ",i,slverr_start_addr_a[i]);
	end
        $display("---------------------------------------------------------------------------------------------------------\n");

     end
  endtask

