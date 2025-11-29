#!/usr/bin/env python3
"""
HEX to COE Converter for Xilinx Block RAM Initialization
Converts Intel HEX format to Xilinx COE format for BRAM initialization

Author: Claude Code
Date: 2025
Usage: python3 hex2coe.py
"""

def hex2coe(hex_file, coe_file, mem_depth=2048):
    """
    Convert game.hex to game.coe for Vivado BRAM initialization

    Args:
        hex_file: Input .hex file path (Intel HEX format)
        coe_file: Output .coe file path (Xilinx COE format)
        mem_depth: Number of 32-bit words (default 2048 for 8KB)
    """
    # Initialize memory with NOP instruction (0x00000033: add x0, x0, x0)
    memory = [0x00000033] * mem_depth

    print(f"[INFO] Initializing {mem_depth} words with NOP instruction (0x00000033)")

    try:
        with open(hex_file, 'r') as f:
            current_addr = 0
            line_num = 0

            for line in f:
                line_num += 1
                line = line.strip()

                # Skip empty lines
                if not line:
                    continue

                # Address directive: @XXXXXXXX
                if line.startswith('@'):
                    try:
                        # Convert hex address to word address (divide by 4)
                        byte_addr = int(line[1:], 16)
                        current_addr = byte_addr // 4
                        print(f"[INFO] Line {line_num}: Address directive @{byte_addr:08X} -> Word address {current_addr}")
                    except ValueError:
                        print(f"[WARNING] Line {line_num}: Invalid address directive '{line}'")
                        continue

                # Data bytes
                else:
                    # Split line into individual byte strings
                    bytes_str = line.split()

                    # Process bytes in groups of 4 (little-endian 32-bit words)
                    for i in range(0, len(bytes_str), 4):
                        # Check if we have 4 bytes
                        if i + 3 < len(bytes_str):
                            try:
                                # Little-endian byte ordering
                                # byte0 = LSB (bits 7:0)
                                # byte1 = bits 15:8
                                # byte2 = bits 23:16
                                # byte3 = MSB (bits 31:24)
                                byte0 = int(bytes_str[i], 16)
                                byte1 = int(bytes_str[i+1], 16)
                                byte2 = int(bytes_str[i+2], 16)
                                byte3 = int(bytes_str[i+3], 16)

                                word = (byte3 << 24) | (byte2 << 16) | (byte1 << 8) | byte0

                                # Store in memory if within bounds
                                if current_addr < mem_depth:
                                    memory[current_addr] = word
                                    if current_addr < 10:  # Print first 10 words for verification
                                        print(f"[INFO] Word[{current_addr:04d}] = 0x{word:08X} (bytes: {byte3:02X} {byte2:02X} {byte1:02X} {byte0:02X})")
                                else:
                                    print(f"[WARNING] Address {current_addr} exceeds memory depth {mem_depth}, skipping")

                                current_addr += 1

                            except ValueError:
                                print(f"[WARNING] Line {line_num}: Invalid hex byte in '{bytes_str[i:i+4]}'")
                                continue

    except FileNotFoundError:
        print(f"[ERROR] Input file '{hex_file}' not found!")
        return False
    except Exception as e:
        print(f"[ERROR] Error reading HEX file: {e}")
        return False

    # Write COE file
    try:
        with open(coe_file, 'w') as f:
            # COE file header
            f.write('memory_initialization_radix=16;\n')
            f.write('memory_initialization_vector=\n')

            # Write all memory words
            for i, word in enumerate(memory):
                if i == mem_depth - 1:
                    # Last entry ends with semicolon
                    f.write(f'{word:08x};\n')
                else:
                    # Other entries end with comma
                    f.write(f'{word:08x},\n')

        print(f"\n[SUCCESS] Conversion complete!")
        print(f"  Input:  {hex_file}")
        print(f"  Output: {coe_file}")
        print(f"  Memory: {mem_depth} words ({mem_depth * 4} bytes = {mem_depth * 4 // 1024}KB)")
        print(f"\nFirst 5 instructions:")
        for i in range(min(5, mem_depth)):
            print(f"  [0x{i*4:04X}] 0x{memory[i]:08X}")

        return True

    except Exception as e:
        print(f"[ERROR] Error writing COE file: {e}")
        return False


if __name__ == '__main__':
    import os

    # File paths (in current directory)
    hex_file = 'game.hex'
    coe_file = 'game.coe'
    mem_depth = 2048  # 8KB = 2048 words of 32 bits

    print("=" * 70)
    print("  RISC-V HEX to COE Converter for Vivado BRAM")
    print("=" * 70)
    print()

    # Check if HEX file exists
    if not os.path.exists(hex_file):
        print(f"[ERROR] '{hex_file}' not found in current directory!")
        print(f"[INFO] Current directory: {os.getcwd()}")
        print(f"[INFO] Please ensure game.hex is in the same directory as this script")
        exit(1)

    # Perform conversion
    success = hex2coe(hex_file, coe_file, mem_depth)

    if success:
        print("\n[NEXT STEPS]")
        print("  1. Verify game.coe was generated correctly")
        print("  2. In Vivado Block Memory Generator IP:")
        print("     - Set 'Load Init File' to game.coe")
        print("     - Memory Depth: 2048")
        print("     - Memory Width: 32")
        print("  3. Generate the IP core")
        print()
        exit(0)
    else:
        print("\n[FAILED] Conversion failed! Check error messages above.")
        exit(1)
