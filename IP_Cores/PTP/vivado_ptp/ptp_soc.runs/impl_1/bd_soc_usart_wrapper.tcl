namespace eval ::optrace {
  variable script "/home/adrian/vhdl_repo/IP_Cores/PTP/vivado_ptp/ptp_soc.runs/impl_1/bd_soc_usart_wrapper.tcl"
  variable category "vivado_impl"
}

# Try to connect to running dispatch if we haven't done so already.
# This code assumes that the Tcl interpreter is not using threads,
# since the ::dispatch::connected variable isn't mutex protected.
if {![info exists ::dispatch::connected]} {
  namespace eval ::dispatch {
    variable connected false
    if {[llength [array get env XILINX_CD_CONNECT_ID]] > 0} {
      set result "true"
      if {[catch {
        if {[lsearch -exact [package names] DispatchTcl] < 0} {
          set result [load librdi_cd_clienttcl[info sharedlibextension]] 
        }
        if {$result eq "false"} {
          puts "WARNING: Could not load dispatch client library"
        }
        set connect_id [ ::dispatch::init_client -mode EXISTING_SERVER ]
        if { $connect_id eq "" } {
          puts "WARNING: Could not initialize dispatch client"
        } else {
          puts "INFO: Dispatch client connection id - $connect_id"
          set connected true
        }
      } catch_res]} {
        puts "WARNING: failed to connect to dispatch server - $catch_res"
      }
    }
  }
}
if {$::dispatch::connected} {
  # Remove the dummy proc if it exists.
  if { [expr {[llength [info procs ::OPTRACE]] > 0}] } {
    rename ::OPTRACE ""
  }
  proc ::OPTRACE { task action {tags {} } } {
    ::vitis_log::op_trace "$task" $action -tags $tags -script $::optrace::script -category $::optrace::category
  }
  # dispatch is generic. We specifically want to attach logging.
  ::vitis_log::connect_client
} else {
  # Add dummy proc if it doesn't exist.
  if { [expr {[llength [info procs ::OPTRACE]] == 0}] } {
    proc ::OPTRACE {{arg1 \"\" } {arg2 \"\"} {arg3 \"\" } {arg4 \"\"} {arg5 \"\" } {arg6 \"\"}} {
        # Do nothing
    }
  }
}

proc start_step { step } {
  set stopFile ".stop.rst"
  if {[file isfile .stop.rst]} {
    puts ""
    puts "*** Halting run - EA reset detected ***"
    puts ""
    puts ""
    return -code error
  }
  set beginFile ".$step.begin.rst"
  set platform "$::tcl_platform(platform)"
  set user "$::tcl_platform(user)"
  set pid [pid]
  set host ""
  if { [string equal $platform unix] } {
    if { [info exist ::env(HOSTNAME)] } {
      set host $::env(HOSTNAME)
    } elseif { [info exist ::env(HOST)] } {
      set host $::env(HOST)
    }
  } else {
    if { [info exist ::env(COMPUTERNAME)] } {
      set host $::env(COMPUTERNAME)
    }
  }
  set ch [open $beginFile w]
  puts $ch "<?xml version=\"1.0\"?>"
  puts $ch "<ProcessHandle Version=\"1\" Minor=\"0\">"
  puts $ch "    <Process Command=\".planAhead.\" Owner=\"$user\" Host=\"$host\" Pid=\"$pid\">"
  puts $ch "    </Process>"
  puts $ch "</ProcessHandle>"
  close $ch
}

proc end_step { step } {
  set endFile ".$step.end.rst"
  set ch [open $endFile w]
  close $ch
}

proc step_failed { step } {
  set endFile ".$step.error.rst"
  set ch [open $endFile w]
  close $ch
OPTRACE "impl_1" END { }
}

set_msg_config -id {HDL-1065} -limit 10000

OPTRACE "impl_1" START { ROLLUP_1 }
OPTRACE "Phase: Init Design" START { ROLLUP_AUTO }
start_step init_design
set ACTIVE_STEP init_design
set rc [catch {
  create_msg_db init_design.pb
  set_param ced.repoPaths /home/adrian/Downloads/TE0950_Designs/04_AMD_Vivado_Custom_Configurable_Example
  set_param bd.open.in_stealth_mode 3
  set_param chipscope.maxJobs 7
  set_param general.usePosixSpawnForFork 1
  set_param runs.launchOptions { -jobs 8  }
OPTRACE "create in-memory project" START { }
  create_project -in_memory -part xcve2302-sfva784-1LP-e-S
  set_property board_part_repo_paths {/home/adrian/te0950_work/board_files} [current_project]
  set_property board_part trenz.biz:te0950_23_1lse:part0:1.2 [current_project]
  set_property design_mode GateLvl [current_fileset]
  set_param project.singleFileAddWarning.threshold 0
OPTRACE "create in-memory project" END { }
OPTRACE "set parameters" START { }
  set_property webtalk.parent_dir /home/adrian/vhdl_repo/IP_Cores/PTP/vivado_ptp/ptp_soc.cache/wt [current_project]
  set_property parent.project_path /home/adrian/vhdl_repo/IP_Cores/PTP/vivado_ptp/ptp_soc.xpr [current_project]
  set_property ip_output_repo /home/adrian/vhdl_repo/IP_Cores/PTP/vivado_ptp/ptp_soc.cache/ip [current_project]
  set_property ip_cache_permissions {read write} [current_project]
  set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
OPTRACE "set parameters" END { }
OPTRACE "add files" START { }
  add_files -quiet /home/adrian/vhdl_repo/IP_Cores/PTP/vivado_ptp/ptp_soc.runs/synth_1/bd_soc_usart_wrapper.dcp
  set_msg_config -source 4 -id {BD 41-1661} -limit 0
  set_param project.isImplRun true
  add_files /home/adrian/vhdl_repo/IP_Cores/PTP/vivado_ptp/ptp_soc.srcs/sources_1/bd/bd_soc_usart/bd_soc_usart.bd
  set_param project.isImplRun false
OPTRACE "read constraints: implementation" START { }
  read_xdc /home/adrian/m1553_ip/m1553_pins.xdc
  read_xdc /home/adrian/eth_ip/eth_pins.xdc
OPTRACE "read constraints: implementation" END { }
OPTRACE "read constraints: implementation_pre" START { }
OPTRACE "read constraints: implementation_pre" END { }
OPTRACE "add files" END { }
OPTRACE "link_design" START { }
  set_param project.isImplRun true
  link_design -top bd_soc_usart_wrapper -part xcve2302-sfva784-1LP-e-S 
OPTRACE "link_design" END { }
  set_param project.isImplRun false
OPTRACE "gray box cells" START { }
OPTRACE "gray box cells" END { }
OPTRACE "init_design_reports" START { REPORT }
OPTRACE "init_design_reports" END { }
OPTRACE "init_design_write_hwdef" START { }
OPTRACE "init_design_write_hwdef" END { }
  close_msg_db -file init_design.pb
} RESULT]
if {$rc} {
  step_failed init_design
  return -code error $RESULT
} else {
  end_step init_design
  unset ACTIVE_STEP 
}

OPTRACE "Phase: Init Design" END { }
OPTRACE "Phase: Opt Design" START { ROLLUP_AUTO }
start_step opt_design
set ACTIVE_STEP opt_design
set rc [catch {
  create_msg_db opt_design.pb
OPTRACE "read constraints: opt_design" START { }
OPTRACE "read constraints: opt_design" END { }
OPTRACE "opt_design" START { }
  opt_design 
OPTRACE "opt_design" END { }
OPTRACE "read constraints: opt_design_post" START { }
OPTRACE "read constraints: opt_design_post" END { }
OPTRACE "opt_design reports" START { REPORT }
  set_param project.isImplRun true
  generate_parallel_reports -reports { "report_drc -file opt_report_drc_0.rpt -pb opt_report_drc_0.pb -rpx opt_report_drc_0.rpx"  }
  set_param project.isImplRun false
OPTRACE "opt_design reports" END { }
OPTRACE "Opt Design: write_checkpoint" START { CHECKPOINT }
  write_checkpoint -force bd_soc_usart_wrapper_opt.dcp
OPTRACE "Opt Design: write_checkpoint" END { }
  close_msg_db -file opt_design.pb
} RESULT]
if {$rc} {
  step_failed opt_design
  return -code error $RESULT
} else {
  end_step opt_design
  unset ACTIVE_STEP 
}

OPTRACE "Phase: Opt Design" END { }
OPTRACE "Phase: Place Design" START { ROLLUP_AUTO }
start_step place_design
set ACTIVE_STEP place_design
set rc [catch {
  create_msg_db place_design.pb
OPTRACE "read constraints: place_design" START { }
OPTRACE "read constraints: place_design" END { }
  if { [llength [get_debug_cores -quiet] ] > 0 }  { 
OPTRACE "implement_debug_core" START { }
    implement_debug_core 
OPTRACE "implement_debug_core" END { }
  } 
OPTRACE "place_design" START { }
  set_param project.isImplRun true
  place_design 
  set_param project.isImplRun false
OPTRACE "place_design" END { }
OPTRACE "read constraints: place_design_post" START { }
OPTRACE "read constraints: place_design_post" END { }
OPTRACE "place_design reports" START { REPORT }
  set_param project.isImplRun true
  generate_parallel_reports -reports { "report_io -file place_report_io_0.rpt" "report_utilization -file place_report_utilization_0.rpt -pb place_report_utilization_0.pb" "report_control_sets -verbose -file place_report_control_sets_0.rpt"  }
  set_param project.isImplRun false
OPTRACE "place_design reports" END { }
write_noc_qos -force -file bd_soc_usart_wrapper.nts
write_noc_solution -force -file bd_soc_usart_wrapper.ncr
OPTRACE "Place Design: write_checkpoint" START { CHECKPOINT }
  write_checkpoint -force bd_soc_usart_wrapper_placed.dcp
OPTRACE "Place Design: write_checkpoint" END { }
  close_msg_db -file place_design.pb
} RESULT]
if {$rc} {
  step_failed place_design
  return -code error $RESULT
} else {
  end_step place_design
  unset ACTIVE_STEP 
}

OPTRACE "Phase: Place Design" END { }
OPTRACE "Phase: Physical Opt Design" START { ROLLUP_AUTO }
start_step phys_opt_design
set ACTIVE_STEP phys_opt_design
set rc [catch {
  create_msg_db phys_opt_design.pb
OPTRACE "read constraints: phys_opt_design" START { }
OPTRACE "read constraints: phys_opt_design" END { }
OPTRACE "phys_opt_design" START { }
  phys_opt_design 
OPTRACE "phys_opt_design" END { }
OPTRACE "read constraints: phys_opt_design_post" START { }
OPTRACE "read constraints: phys_opt_design_post" END { }
OPTRACE "phys_opt_design report" START { REPORT }
OPTRACE "phys_opt_design report" END { }
OPTRACE "Post-Place Phys Opt Design: write_checkpoint" START { CHECKPOINT }
  write_checkpoint -force bd_soc_usart_wrapper_physopt.dcp
OPTRACE "Post-Place Phys Opt Design: write_checkpoint" END { }
  close_msg_db -file phys_opt_design.pb
} RESULT]
if {$rc} {
  step_failed phys_opt_design
  return -code error $RESULT
} else {
  end_step phys_opt_design
  unset ACTIVE_STEP 
}

OPTRACE "Phase: Physical Opt Design" END { }
OPTRACE "Phase: Route Design" START { ROLLUP_AUTO }
start_step route_design
set ACTIVE_STEP route_design
set rc [catch {
  create_msg_db route_design.pb
OPTRACE "read constraints: route_design" START { }
OPTRACE "read constraints: route_design" END { }
OPTRACE "route_design" START { }
  route_design 
OPTRACE "route_design" END { }
OPTRACE "read constraints: route_design_post" START { }
OPTRACE "read constraints: route_design_post" END { }
OPTRACE "route_design reports" START { REPORT }
  set_param project.isImplRun true
  generate_parallel_reports -reports { "report_drc -file route_report_drc_0.rpt -pb route_report_drc_0.pb -rpx route_report_drc_0.rpx" "report_methodology -file route_report_methodology_0.rpt -pb route_report_methodology_0.pb -rpx route_report_methodology_0.rpx" "report_power -file route_report_power_0.rpt -pb route_report_power_summary_0.pb -rpx route_report_power_0.rpx" "report_route_status -file route_report_route_status_0.rpt -pb route_report_route_status_0.pb" "report_timing_summary -max_paths 10 -report_unconstrained -file route_report_timing_summary_0.rpt -pb route_report_timing_summary_0.pb -rpx route_report_timing_summary_0.rpx" "report_incremental_reuse -file route_report_incremental_reuse_0.rpt" "report_clock_utilization -file route_report_clock_utilization_0.rpt" "report_bus_skew -warn_on_violation -file route_report_bus_skew_0.rpt -pb route_report_bus_skew_0.pb -rpx route_report_bus_skew_0.rpx"  }
  set_param project.isImplRun false
OPTRACE "route_design reports" END { }
OPTRACE "Route Design: write_checkpoint" START { CHECKPOINT }
  write_checkpoint -force bd_soc_usart_wrapper_routed.dcp
OPTRACE "Route Design: write_checkpoint" END { }
OPTRACE "route_design misc" START { }
  close_msg_db -file route_design.pb
} RESULT]
if {$rc} {
OPTRACE "route_design write_checkpoint" START { CHECKPOINT }
OPTRACE "route_design write_checkpoint" END { }
  write_checkpoint -force bd_soc_usart_wrapper_routed_error.dcp
  step_failed route_design
  return -code error $RESULT
} else {
  end_step route_design
  unset ACTIVE_STEP 
}

OPTRACE "route_design misc" END { }
OPTRACE "Phase: Route Design" END { }
OPTRACE "Phase: Write Device Image" START { ROLLUP_AUTO }
OPTRACE "write_device_image setup" START { }
start_step write_device_image
set ACTIVE_STEP write_device_image
set rc [catch {
  create_msg_db write_device_image.pb
  set_property segmented_configuration 0 [current_design]
OPTRACE "read constraints: write_bitstream" START { }
OPTRACE "read constraints: write_bitstream" END { }
OPTRACE "read constraints: write_bitstream" START { }
OPTRACE "read constraints: write_bitstream" END { }
  set_property XPM_LIBRARIES {XPM_CDC XPM_FIFO XPM_MEMORY} [current_project]
  catch { write_mem_info -force -no_partial_mmi bd_soc_usart_wrapper.mmi }
OPTRACE "write_device_image setup" END { }
OPTRACE "write_device_image" START { }
  write_device_image -force bd_soc_usart_wrapper.pdi 
OPTRACE "write_device_image" END { }
OPTRACE "write_device_image misc" START { }
OPTRACE "read constraints: write_bitstream_post" START { }
OPTRACE "read constraints: write_bitstream_post" END { }
OPTRACE "read constraints: write_device_image_post" START { }
OPTRACE "read constraints: write_device_image_post" END { }
  catch {write_debug_probes -quiet -force bd_soc_usart_wrapper}
  catch {file copy -force bd_soc_usart_wrapper.ltx debug_nets.ltx}
  close_msg_db -file write_device_image.pb
} RESULT]
if {$rc} {
OPTRACE "write_device_image write_checkpoint" START { CHECKPOINT }
OPTRACE "write_device_image write_checkpoint" END { }
  step_failed write_device_image
  return -code error $RESULT
} else {
  end_step write_device_image
  unset ACTIVE_STEP 
}

OPTRACE "write_device_image misc" END { }
OPTRACE "Phase: Write Device Image" END { }
OPTRACE "impl_1" END { }
