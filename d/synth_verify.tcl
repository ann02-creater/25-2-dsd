# Vivado synthesis verification script
set proj_dir [pwd]/vivado_proj
file mkdir $proj_dir
create_project riscv_cpu_proj $proj_dir -part xc7a35ticsg324-1L

# Add source files
set src_dir [pwd]/src
add_files -norecurse [glob $src_dir/*.v]

# Add constraints
add_files -fileset constrs_1 $src_dir/const.xdc

# Set top module (adjust if different)
set_property top data_path [current_fileset]

# Run synthesis
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# Write report
report_synthesis -file $proj_dir/synth_report.txt

exit
