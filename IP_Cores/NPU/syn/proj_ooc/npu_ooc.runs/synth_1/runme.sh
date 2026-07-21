#!/bin/bash

# 
# Vivado(TM)
# runme.sh: a Vivado-generated Runs Script for UNIX
# Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
# Copyright 2022-2026 Advanced Micro Devices, Inc. All Rights Reserved.
# 

if [ -z "$PATH" ]; then
  PATH=/home/adrian/Xilinx/2025.2.1/Vitis/bin:/home/adrian/Xilinx/2025.2.1/Vivado/ids_lite/ISE/bin/lin64:/home/adrian/Xilinx/2025.2.1/Vivado/bin
else
  PATH=/home/adrian/Xilinx/2025.2.1/Vitis/bin:/home/adrian/Xilinx/2025.2.1/Vivado/ids_lite/ISE/bin/lin64:/home/adrian/Xilinx/2025.2.1/Vivado/bin:$PATH
fi
export PATH

if [ -z "$LD_LIBRARY_PATH" ]; then
  LD_LIBRARY_PATH=
else
  LD_LIBRARY_PATH=:$LD_LIBRARY_PATH
fi
export LD_LIBRARY_PATH

HD_PWD='/home/adrian/vhdl_repo/IP_Cores/NPU/syn/proj_ooc/npu_ooc.runs/synth_1'
cd "$HD_PWD"

HD_LOG=runme.log
/bin/touch $HD_LOG

ISEStep="./ISEWrap.sh"
EAStep()
{
     $ISEStep $HD_LOG "$@" >> $HD_LOG 2>&1
     if [ $? -ne 0 ]
     then
         exit
     fi
}

EAStep vivado -log npu_top.vds -m64 -product Vivado -mode batch -messageDb vivado.pb -notrace -source npu_top.tcl
