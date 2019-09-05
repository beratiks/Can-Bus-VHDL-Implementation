----------------------------------------------------------------------------------
-- Engineer: Berat YILDIZ
-- e-mail : yildizberat@gmail.com
-- Create Date: 07/22/2019 09:45:13 PM
-- Design Name: 
-- Module Name: BitTimeLogic - Behavioral
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
library work;
use work.canTypes.ALL;

entity BitTimeLogic is
    Port ( TxPin : out STD_LOGIC;               -- physical Tx pin to connect Can phy
           RxPin : in STD_LOGIC;                -- physical Rx pin to connect Can phy
           TxBit : in STD_LOGIC;                -- sending Bit to send
           RxBit : out STD_LOGIC;               -- received Bit to receive
           clk_in : in STD_LOGIC;               -- can clock
           write_order : in STD_LOGIC;          -- order of write.
           write_valid : out STD_LOGIC;         -- write is complete.  Accept falling edge
           read_valid : out STD_LOGIC;          -- read is complete.   Accept rising edge
           sample_start      :  in std_logic    -- BSP check starf of frame and set sample start
           ); 
           
end BitTimeLogic;

architecture Behavioral of BitTimeLogic is

signal sig_time_segment_1 : integer := TIME_SEGMENT_1;          -- time segment bit get from canTypes lib
signal sig_time_segment_2 : integer := TIME_SEGMENT_2;          -- time segment bit get from canTypes lib

-- signal of ports
signal sig_TxPin        : STD_LOGIC;     
signal sig_RxPin        : STD_LOGIC;       
signal sig_TxBit        : STD_LOGIC;        
signal sig_RxBit        : STD_LOGIC := '0';              
signal sig_write_order  : STD_LOGIC;  
signal sig_write_valid  : STD_LOGIC := '0'; 
signal sig_read_valid   : STD_LOGIC := '0';  
-- end of ports

signal sig_startSample  : STD_LOGIC := '0';  

signal oneBitQuantaTime : integer := TIME_SEGMENT_1 + TIME_SEGMENT_2 + TIME_SYNC_SEGMENT;  -- one bit time
                                                 -- time quanta counter to detect bit states
type BitStateType is (IDLE,SYNC_SEGMENT,PHASE_SEGMENT_1,PHASE_SEGMENT_2);                   -- bit state enum type definition
signal BitState : BitStateType := IDLE;                                                     --  bit state enum

signal sig_RxPinPrev_receive       : STD_LOGIC;       
signal sig_RxPinPrev_transmit      : STD_LOGIC;      

signal sig_write_order_prev        : std_logic;

signal canClock                    : std_logic := '0';
signal canClockCounter             : integer := 0;
signal canClockCounterLimit        : integer := BAUDRATE_PRESCALER - 1;

begin
-- conneect ports to signals to R-W
TxPin <= sig_TxPin;
sig_rxPin <= RxPin;
sig_TxBit <= TxBit;
RxBit <= sig_RxBit;       
sig_write_order <= write_order;  
write_valid <= sig_write_valid;
read_valid <= sig_read_valid;
sig_startSample <= sample_start;

canClockProcess : process(clk_in)

begin

    if(canClockCounterLimit = 0) then
    
        canClock <= clk_in;
    
    else

        if(rising_edge(clk_in)) then
            if(canClockCounter = canClockCounterLimit - 1) then
            
                canClock <= not canClock;
                canClockCounter <= 0;
            
            else
            
                canClockCounter <= canClockCounter + 1;
            
            end if;
        end if;
    end if;

end process;

-- calculate time quanta on every bit time
-- set valid for write and read depends on bit timing and resynchronisation  
timeQuantaProcess : process(canClock)

variable timeQuantaCounter : integer := 0;   

begin
 
    if(rising_edge(canClock)) then
    
    
        if(sig_write_order_prev = '0' and sig_write_order = '1' and sig_startSample = '0') then
        
            timeQuantaCounter := 0;
            sig_txPin <= '0';
            
        end if;
        
        sig_write_order_prev <= sig_write_order;
    
        if(sig_startSample = '1' or sig_write_order = '1') then
        
            if(timeQuantaCounter >= oneBitQuantaTime - 1) then
            
                timeQuantaCounter := 0;
               
            else
            
                timeQuantaCounter := timeQuantaCounter + 1;
            
            end if;
        else
        
        timeQuantaCounter := 0;
        
        end if;
        
        if(timeQuantaCounter = TIME_SYNC_SEGMENT - 1) then
        
            sig_read_valid <= '0'; 
            sig_write_valid <= '0';
            
            if(sig_write_order = '1') then
                
                sig_txPin <= sig_txBit;  
  
            else
                 
                sig_txPin <= '1';
                     
            end if;
        elsif(timeQuantaCounter >= 1 and timeQuantaCounter < TIME_SYNC_SEGMENT + sig_time_segment_1) then
        
               if(sig_RxPinPrev_receive = '1' and sig_rxPin = '0' and sig_write_order = '0' ) then        -- check if change rx recessive to dominant for re-synchronisaton. this is interpreted as a late edge
                
                    timeQuantaCounter := 1;
                    
                end if;

            if(timeQuantaCounter = TIME_SYNC_SEGMENT + sig_time_segment_1 - 1) then
            
                sig_rxBit <= sig_rxPin;
                sig_read_valid <= '1';
                
                if(sig_write_order = '1') then                 
                        
                    sig_write_valid <= '1';
                    
                else
              
                    sig_txPin <= '1';
                    sig_write_valid <= '0';
               
                end if;
                
            
            end if;
        
        else
          
          if(sig_RxPinPrev_receive = '1' and sig_rxPin = '0' and sig_write_order = '0' ) then         -- check if change rx recessive to dominant for re-synchronisaton. this is interpreted as an early bit

                timeQuantaCounter := 1;
                              
            end if;
            
            sig_read_valid <= '0';
            

                if(sig_write_order = '1') then    
                    
                    sig_write_valid <= '0';
                    
                else
                
                    sig_write_valid <= '0';
                    sig_txPin <= '1';
                    
                end if;    
            
        
        end if;
        
        
        
     sig_RxPinPrev_receive <= sig_rxPin;   
    end if;

end process;

end Behavioral;