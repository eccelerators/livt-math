set here [file dirname [file normalize [info script]]]
set_param general.maxThreads 4
set_param synth.maxThreads 4
cd $here/wrapper/before
create_project -in_memory -part xc7a200tfbg676-1
read_vhdl -vhdl2008 [glob *.vhd]
read_xdc clock.xdc
synth_design -top bench -part xc7a200tfbg676-1 -mode out_of_context -directive AreaOptimized_high -control_set_opt_threshold 16
report_utilization -hierarchical -file utilization.rpt
report_timing_summary -file timing.rpt
set latches [get_cells -hier -quiet -filter {REF_NAME =~ LD*}]
if {[llength $latches]} {error "Unexpected latches"}
puts "WRAPPER_before_PASS"
close_project
cd $here/wrapper/after
create_project -in_memory -part xc7a200tfbg676-1
read_vhdl -vhdl2008 [glob *.vhd]
read_xdc clock.xdc
synth_design -top bench -part xc7a200tfbg676-1 -mode out_of_context -directive AreaOptimized_high -control_set_opt_threshold 16
report_utilization -hierarchical -file utilization.rpt
report_timing_summary -file timing.rpt
set latches [get_cells -hier -quiet -filter {REF_NAME =~ LD*}]
if {[llength $latches]} {error "Unexpected latches"}
puts "WRAPPER_after_PASS"
close_project
cd $here/wrapper/division
create_project -in_memory -part xc7a200tfbg676-1
read_vhdl -vhdl2008 [glob *.vhd]
read_xdc clock.xdc
synth_design -top bench -part xc7a200tfbg676-1 -mode out_of_context -directive AreaOptimized_high -control_set_opt_threshold 16
report_utilization -hierarchical -file utilization.rpt
report_timing_summary -file timing.rpt
set latches [get_cells -hier -quiet -filter {REF_NAME =~ LD*}]
if {[llength $latches]} {error "Unexpected latches"}
puts "WRAPPER_division_PASS"
close_project
exit
