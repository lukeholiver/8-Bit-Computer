import sys
import serial

program_str = sys.stdin.read().strip()

# invaid program
if not program_str:
    print("Error: invalid program", file=sys.stderr)
    sys.exit(1)

# convert program to bytes
try:
    program_bytes = bytes.fromhex(program_str)
    
except ValueError:
    print("Error: not a valid program", file=sys.stderr)
    sys.exit(1)

# check length
if(len(program_bytes) > 256):
    print(f"Error: program is {len(program_bytes)} bytes", file=sys.stderr)
    sys.exit(1)

# create byte padding
padded_program = program_bytes.ljust(256, b'\x00')

# open serial port at COM3 for windows
with serial.Serial('COM4', 9600, parity=serial.PARITY_NONE) as ser:

    # write the program
    sent = ser.write(padded_program)
    ser.flush()
    print(f"Sent {sent} bytes")