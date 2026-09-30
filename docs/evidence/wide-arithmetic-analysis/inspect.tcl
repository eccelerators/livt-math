set_param general.maxThreads 4
open_checkpoint /home/vagrant/git/livt/livt-flan-t5-arty-a7-100t/work/a200t-arithmetic-rebuild/routed.dcp
set base livt_onnx_flant5_flant5application_i/model_instance/weights_instance/fixed_instance/math_instance/primitive_instance
set out [open /tmp/ft5-math-analysis/dsp-cones.txt w]
foreach cell [get_cells -hier -filter "NAME =~ $base/* && REF_NAME == DSP48E1"] {
 puts $out "CELL $cell"
 foreach prop {AREG BREG MREG PREG USE_MULT} {puts $out "$prop=[get_property $prop $cell]"}
 set pins [get_pins -of_objects $cell -filter {REF_PIN_NAME =~ A* || REF_PIN_NAME =~ B*}]
 set starts [all_fanin -flat -startpoints_only -to $pins]
 puts $out "INPUT_STARTPOINTS $starts"
}
close $out
exit
