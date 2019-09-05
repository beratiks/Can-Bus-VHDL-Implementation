----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/16/2019 10:09:38 PM
-- Design Name: 
-- Module Name: CanTypes - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package CanTypes is

  constant  CLOCK_WIZARD_FREQUENCY  : integer   :=  8e6;
  constant  BAUDRATE_PRESCALER      : integer   :=  2;
  constant  TIME_SEGMENT_1          : integer   :=  13;
  constant  TIME_SEGMENT_2          : integer   :=  2;
  constant  TIME_SYNC_SEGMENT       : integer   :=  1;
  
  constant SIZE_OF_SOF              : integer   := 1;
  constant SIZE_OF_STD_ID           : integer   := 11;
  constant SIZE_OF_RTR              : integer   := 1;
  constant SIZE_OF_RESERVED         : integer   := 1;
  constant SIZE_OF_IDE              : integer   := 1;
  constant SIZE_OF_DLC              : integer   := 4;
  constant SIZE_OF_MAX_DATA         : integer   := 8;
  constant SIZE_OF_CRC              : integer   := 15;
  constant SIZE_OF_ACK              : integer   := 2;
  constant SIZE_OF_EOF              : integer   := 7;
  constant SIZE_OF_IFS              : integer   := 3;   
  
  constant SIZE_OF_MIN_CRC_FIELD    : integer   := SIZE_OF_SOF + SIZE_OF_STD_ID + SIZE_OF_RTR + SIZE_OF_RESERVED + SIZE_OF_IDE + SIZE_OF_DLC;
  constant SIZE_OF_MAX_CRC_FIELD    : integer   := SIZE_OF_SOF + SIZE_OF_STD_ID + SIZE_OF_RTR + SIZE_OF_RESERVED + SIZE_OF_IDE + SIZE_OF_DLC + SIZE_OF_MAX_DATA*8;
  
  constant SIZE_OF_BIT_STUFFING_FIELD     : integer   := SIZE_OF_SOF + SIZE_OF_STD_ID + SIZE_OF_RTR + SIZE_OF_RESERVED + SIZE_OF_IDE + SIZE_OF_DLC + SIZE_OF_MAX_DATA + SIZE_OF_CRC + 10;
  
type Data is array (SIZE_OF_MAX_DATA - 1 downto 0) of std_logic_vector(7 downto 0);

type CanPackage is record
    StdId   :   std_logic_vector(SIZE_OF_STD_ID - 1 downto 0);
    Rtr     :   std_logic;
    IDE     :   std_logic;
    Dlc     :   std_logic_vector(SIZE_OF_DLC - 1 downto 0);
    Data    :   Data; 
end record CanPackage;

type CanFrame is record
    Sof         :   std_logic;
    StdId       :   std_logic_vector(SIZE_OF_STD_ID - 1 downto 0);
    Rtr         :   std_logic;
    Reserved    :   std_logic;
    IDE         :   std_logic;
    Dlc         :   std_logic_vector(SIZE_OF_DLC - 1 downto 0);
    Data        :   Data; 
    Crc         :   std_logic_vector(SIZE_OF_CRC - 1 downto 0);
end record CanFrame;

constant Location_Error_Sof                     : integer := 0;
constant Location_Error_Reserve                 : integer := 1;
constant Location_Error_Crc                     : integer := 2;
constant Location_Error_Ack                     : integer := 3;
constant Location_Error_EOF                     : integer := 4;
constant Location_Error_IFS                     : integer := 5;
constant Location_Error_BitStuffing             : integer := 6;

constant SIZE_OF_ERRORS                         : integer := 7;
end package CanTypes;
