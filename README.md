# Basic Can Bus Example

  This project basic can bus implementation. Not recommend for commercial uses.
  Send a package when switches state change. 
  Parse package and set leds when receiving spesific packages.
  Tested with Pcan hardware and Pcanview software.(125 kBit/s,250 kBit/s,500 kBit/s,1 MBit/s)

# Features :
- Only support Bosch 2.0A and standart frame format.
- Support Remote Frame
- Error check
- Receive and transmit interrupts
- Not support filter


# Design : 

- Clock wizard (Xilinx IP) : for get 8 Mhz main can clock
- Bit Time Logic           : for bit timing and resynhronization
- Bit Stream Processor     : for serialization packages, crc, bit stuffing, receive and transmit packages.
- Can Master               : Top module for send and parse packages.
- CanTypes.vhd             : for storage some defines. (prescaler, time segments, data size ...)

- Baudrate Generation : 

    Baudrate =  (Main clock frequency) / 2 / prescaler / (Time segment 1 + Time segment 2 + 1)
    You can change at CanTypes.vhd

- Main can bus clock 8 Mhz comes from Clock Wizard(Xilinx IP).
- Quanta time occur with prescaler
- Arbitration control
- Bit stuffing control
- Hard synhronization and resynhronization
- Error control
- If occur error during transmit, try transmit until success
- Crc 15 
- Receive and transmit interrupts
 
