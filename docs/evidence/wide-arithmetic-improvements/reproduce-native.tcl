set here [file dirname [file normalize [info script]]]
set_param general.maxThreads 4
set_param synth.maxThreads 4
cd $here/native/baseline
create_project -in_memory -part xc7a200tfbg676-1
read_vhdl -vhdl2008 [list ../Livt.Lang.Package.vhd ../Livt.Lang.IContext.Package.vhd primitive.vhd wrapper.vhd]
read_xdc clock.xdc
synth_design -top bench -part xc7a200tfbg676-1 -mode out_of_context -directive AreaOptimized_high -control_set_opt_threshold 16
report_utilization -file synth_utilization.rpt
report_timing_summary -file synth_timing.rpt
opt_design
place_design
route_design
report_utilization -file routed_utilization.rpt
report_timing_summary -check_timing_verbose -report_unconstrained -file routed_timing.rpt
report_timing -from [all_registers] -to [all_registers] -max_paths 10 -file internal_paths.rpt
set latches [get_cells -hier -quiet -filter {REF_NAME =~ LD*}]
if {[llength $latches]} {error "Unexpected latches"}
puts "WIDE_baseline_PASS"
close_project
cd $here/native/final-full
create_project -in_memory -part xc7a200tfbg676-1
read_vhdl -vhdl2008 [list ../Livt.Lang.Package.vhd ../Livt.Lang.IContext.Package.vhd primitive.vhd wrapper.vhd]
read_xdc clock.xdc
synth_design -top bench -part xc7a200tfbg676-1 -mode out_of_context -directive AreaOptimized_high -control_set_opt_threshold 16
report_utilization -file synth_utilization.rpt
report_timing_summary -file synth_timing.rpt
opt_design
place_design
route_design
report_utilization -file routed_utilization.rpt
report_timing_summary -check_timing_verbose -report_unconstrained -file routed_timing.rpt
report_timing -from [all_registers] -to [all_registers] -max_paths 10 -file internal_paths.rpt
set latches [get_cells -hier -quiet -filter {REF_NAME =~ LD*}]
if {[llength $latches]} {error "Unexpected latches"}
puts "WIDE_final-full_PASS"
close_project
cd $here/native/final-division
create_project -in_memory -part xc7a200tfbg676-1
read_vhdl -vhdl2008 [list ../Livt.Lang.Package.vhd ../Livt.Lang.IContext.Package.vhd primitive.vhd wrapper.vhd]
read_xdc clock.xdc
synth_design -top bench -part xc7a200tfbg676-1 -mode out_of_context -directive AreaOptimized_high -control_set_opt_threshold 16
report_utilization -file synth_utilization.rpt
report_timing_summary -file synth_timing.rpt
opt_design
place_design
route_design
report_utilization -file routed_utilization.rpt
report_timing_summary -check_timing_verbose -report_unconstrained -file routed_timing.rpt
report_timing -from [all_registers] -to [all_registers] -max_paths 10 -file internal_paths.rpt
set latches [get_cells -hier -quiet -filter {REF_NAME =~ LD*}]
if {[llength $latches]} {error "Unexpected latches"}
puts "WIDE_final-division_PASS"
close_project
exit
