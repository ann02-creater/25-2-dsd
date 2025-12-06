# Vivado Project Creation Script for Haewon RISC-V Odd/Even Game
# Auto-generated: 2025-12-06
# Target: Nexys A7-100T (xc7a100tcsg324-1)

#===================================================================
# Project Configuration
#===================================================================

set project_name "haewon_fpga"
set project_dir "./haewon_vivado"
set part_name "xc7a100tcsg324-1"

puts "========================================"
puts "Creating Vivado Project: $project_name"
puts "Target Device: $part_name"
puts "========================================"

#===================================================================
# Create Project
#===================================================================

create_project $project_name $project_dir -part $part_name -force

puts "\n✓ Project created"

#===================================================================
# Add RTL Source Files
#===================================================================

puts "\nAdding RTL files..."

# Add all Verilog files in rtl/ directory
set rtl_files [glob -directory rtl *.v]
add_files -fileset sources_1 $rtl_files

puts "  Added [llength $rtl_files] RTL files"

# List key files
foreach file {"rtl/fpga_debugger.v" "rtl/data_path.v" "rtl/control_unit.v" "rtl/imm_gen.v"} {
    if {[file exists $file]} {
        puts "  ✓ $file"
    } else {
        puts "  ✗ MISSING: $file"
    }
}

#===================================================================
# Add Configuration Files
#===================================================================

puts "\nAdding configuration files..."

# Add config.vh as global include file
if {[file exists "config/config.vh"]} {
    add_files -fileset sources_1 config/config.vh
    set_property is_global_include true [get_files config/config.vh]
    puts "  ✓ config/config.vh (global include)"
} else {
    puts "  ✗ MISSING: config/config.vh"
}

# Add defines.v as global include (if not already in rtl/)
if {[file exists "rtl/defines.v"]} {
    set_property is_global_include true [get_files defines.v]
    puts "  ✓ rtl/defines.v (global include)"
}

#===================================================================
# Add Constraints
#===================================================================

puts "\nAdding constraints..."

if {[file exists "constraints/const.xdc"]} {
    add_files -fileset constrs_1 constraints/const.xdc
    puts "  ✓ constraints/const.xdc"
} else {
    puts "  ✗ MISSING: constraints/const.xdc"
}

#===================================================================
# Add Memory Initialization Files
#===================================================================

puts "\nAdding memory initialization files..."

if {[file exists "mem/haewon.coe"]} {
    add_files mem/haewon.coe
    set_property FILE_TYPE {Coefficient Files} [get_files haewon.coe]
    puts "  ✓ mem/haewon.coe (BRAM initialization)"
} else {
    puts "  ✗ MISSING: mem/haewon.coe"
}

#===================================================================
# Set Top Module
#===================================================================

puts "\nSetting top module..."

set_property top fpga_debugger [current_fileset]
puts "  ✓ Top module: fpga_debugger"

#===================================================================
# Update Compile Order
#===================================================================

puts "\nUpdating compile order..."
update_compile_order -fileset sources_1
puts "  ✓ Compile order updated"

#===================================================================
# Display Project Summary
#===================================================================

puts "\n========================================"
puts "Project Summary"
puts "========================================"
puts "Project: $project_name"
puts "Location: $project_dir"
puts "Part: $part_name"
puts "Top Module: fpga_debugger"
puts ""
puts "RTL Files: [llength [get_files -of_objects [get_filesets sources_1] -filter {FILE_TYPE == Verilog}]]"
puts "Constraints: [llength [get_files -of_objects [get_filesets constrs_1]]]"
puts "Memory Files: [llength [get_files -filter {FILE_TYPE == {Coefficient Files}}]]"
puts "========================================"

#===================================================================
# Optional: Run Syntax Check
#===================================================================

puts "\nRunning syntax check..."
check_syntax -fileset sources_1

puts "\n✓ Project created successfully!"
puts "\nNext steps:"
puts "  1. Review project in Vivado GUI"
puts "  2. Run synthesis: launch_runs synth_1 -jobs 4"
puts "  3. Check BRAM inference in utilization report"
puts "  4. Expected: RAMB36E1 = 2 blocks, LUT ~2000-3000"
puts ""
