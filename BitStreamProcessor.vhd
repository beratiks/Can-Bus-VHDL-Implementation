    ----------------------------------------------------------------------------------
    -- Company: 
    -- Engineer: 
    -- 
    -- Create Date: 07/25/2019 01:59:40 AM
    -- Design Name: 
    -- Module Name: BitStreamProcessor - Behavioral
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
    use ieee.numeric_std.ALL;
    library work;
    use work.CanTypes.ALL;


    entity BitStreamProcessor is
        Port ( Tx_Pin               : out STD_LOGIC := '1';         -- tx phy pin start with high
               Rx_Pin               : in STD_LOGIC;                 -- rx phy pin
               clk_in               : in STD_LOGIC;                 -- can bus clock come from clock wizard as 24 Mhz
               receivePackage       : out CanPackage;               -- received package to inform top module
               transmitPackage      : in CanPackage;                -- transmit package come from top module to send
               receiving            : out STD_LOGIC;                -- when receiving this signal high
               receiveIT            : out STD_LOGIC;                -- end of receiving interrupt signal at rising edge
               transmitIT           : out STD_LOGIC;                -- end of transmit ,nterrupt at rising edge
               error                : out STD_LOGIC_VECTOR(SIZE_OF_ERRORS - 1 downto 0);    -- can bus error inform to top module
               transmitOrder        : in STD_LOGIC;                 -- transmit start at rising edge this signal
               errorOccured         : out STD_LOGIC                 -- error occur at rising edge
               );
    end BitStreamProcessor;
    
    architecture Behavioral of BitStreamProcessor is
    
    component BitTimeLogic is
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
      end component BitTimeLogic;
      
      type FrameEnumType is (IDLE,SOF,ID,RTR,IDE,DLC,RESERVE,DATA,CRC,CRC_DELIMITER,ACK,ACK_DELIMITER,EOF,IFS,STUFFING,LOCK);  -- enum types for parse and transmit frame

      signal    error_receive               :   std_logic_vector(SIZE_OF_ERRORS - 1 downto 0);  -- error buffer to inform top module
      signal    sig_errorOccured_receive    :   std_logic;          -- error signal valid at rising edge
      signal    sig_RxBit                   :   std_logic;          -- received rx Bit
      signal    sig_read_valid              :   std_logic;          -- received valid every rising edge
      signal    sig_check_arbitration       :   std_logic   :=  '0';       -- check arbitration state
      signal    receiveFrameEnum            :   FrameEnumType  := Idle;         -- receive enum 
      signal    receiveFrameEnumPrev        :   FrameEnumType  := Idle;         -- receive enum
      signal    sig_start_sample            :   std_logic := '0';   -- check rx pin falling edge and set start sample to BTL
      signal    receiveFrame                :   CanFrame;                   -- receive frame for collection all received bits
      signal    receivePackageCounter       :   integer := 0;      -- counter to get all bits of stage frame
      signal    receiveDataByteCounter      :   integer := 0;     -- counter to get all bits data stage
      signal    sig_receiving               :   std_logic   := '0';         -- set high during receiving
      signal    sig_receiveIT               :   std_logic;              -- end of receiving at rising edge
      signal    startSample_receive         :   std_logic := '0';       -- start receiving signal at receive process
      signal    sig_rxPin                   :   std_logic       := '1'; -- rx phy pin signal
      signal    sig_rxPinPrev               :   std_logic := '1';       -- previous rx Pin detect rising or falling
      signal    bitStuffingCounter          :   integer := 0;           -- bit stuffing counter to detect bit stuff
      signal    bitStuffingWillWaitBit      :   std_logic;              -- when  bit stuff occur wait bit stuff bit
      signal    sig_TxBitReceive            :   std_logic := '1';       -- signal tx bit for using receive process
      signal    sig_write_orderReceive      :   std_logic   := '0';     -- write order for use at receive process
      signal    sig_start_sampleReceive     :   std_logic := '0';       -- start receive signal for using at receive process 
             
      signal    sig_start_sampleTransmit    :   std_logic := '0';       -- start receive signal for using at transmit process
      signal    sig_write_order             :   std_logic   := '0';     -- write order
      signal    sig_write_orderTransmit     :   std_logic   := '0';     -- write order for usinbg transmit process
      signal    sig_write_valid             :   std_logic;              -- write valid at rising edge
      signal    sig_TxBit                   :   std_logic;              -- transmit bit to send
      signal    sig_TxBitPrev               :   std_logic;              -- transmit prev bit detect rising or falling
      signal    transmitFrameEnum           :   FrameEnumType  := Idle;         -- receive enum 
      signal    transmitFrame               :   CanFrame;                   -- receive frame for collection all received bits
      signal    sig_transmitIT              :   std_logic;                  -- end of transmit at rising edge
      signal    startTransmit               : std_logic := '1';             -- start transmit to send
      signal    sig_TxBitTransmit           : std_logic := '1';             -- start transmit to send for using at transmit process
      signal    sig_transmitting            : std_logic := '0';             -- transmitting signal high during transmitting
      signal    transmitError               : std_logic := '0';             --transmit error signal to resend
      signal    sig_read_validPrevTransmit  : std_logic;                    -- signal read valid for use at transmit process
      signal    arbitrationLost             : std_logic := '0';             -- arbitration lost signal to cancel transmit
      signal    txBitPrevForArbitration     : std_logic;                    -- tx bit for check lost arbitration
      signal    sig_write_valid_previous    : std_logic;                    -- write valid prev for detect rising edge 
      signal    sig_errorOccured_transmsit  :   std_logic;                  -- error signal valid at rising edge
      signal    error_transmit              :   std_logic_vector(SIZE_OF_ERRORS - 1 downto 0);  -- error buffer to inform top module
      
    begin
    
    BTL : BitTimeLogic port map
    (
        TxPin            =>          Tx_Pin,             
        RxPin            =>          Rx_Pin,                    
        TxBit            =>          sig_TxBit,               
        RxBit            =>          sig_RxBit,             
        clk_in           =>          clk_in,              
        write_order      =>          sig_write_order,        
        write_valid      =>          sig_write_valid,         
        read_valid       =>          sig_read_valid,          
        sample_start     =>          sig_start_sample
    );
    
    
    sig_rxPin <= Rx_Pin;                    
    
    -- for receive and transmit process set tx bit together
    
    sig_TxBit <= sig_TxBitTransmit and sig_TxBitReceive;            
    
    sig_write_order <= sig_write_orderReceive or sig_write_orderTransmit;
    
    sig_start_sample <= sig_start_sampleReceive or sig_start_sampleTransmit;
    
    transmitIT <= sig_transmitIT;
    
    receiving <= sig_receiving;   
    
    receiveIT <= sig_receiveIT;
    
    errorOccured <= sig_errorOccured_transmsit or sig_errorOccured_receive;
    error        <= error_receive or error_transmit;
       
    --receive process to parse frame
    receiveProcess : process
    
    
    variable    dlcIterator             :   std_logic_vector(SIZE_OF_DLC - 1 downto 0);             -- dlc iterator to storage dlc
    variable    receveDataByteSize      : integer := 0;     -- stroge to received dlc as integer format
    variable    receivedCrc             : std_logic_vector(14 downto 0);        -- received crc to check crc
    
    -- for calculate crc
    variable    CrcNextBit                 :  std_logic;                        
    variable    var_CalculatedCrc          :  std_logic_vector(14 downto 0) := "000000000000000";   
     
    -- detect write or read for rising or falling
    variable    sig_read_validPrevReceive  : std_logic;
    variable    sig_write_valid_prev        : std_logic;
    
    begin
    
    if(rising_edge(clk_in) ) then
        
        case(receiveFrameEnum) is
    
            when IDLE =>
                
                sig_receiveIT <= '1';               -- idle state to empty bus
                sig_receiving <= '0';                    
                sig_start_sampleReceive <= '0';
                arbitrationLost <= '0';
                error_receive <= (others => '0');
                sig_errorOccured_receive <= '0';
                if(sig_rxPin = '0') then            -- bus change recessive to dominant start receive
                
                    sig_receiving <= '1';                         
                    receiveFrameEnum <= SOF;
                    receiveFrameEnumPrev <= SOF;
                    sig_start_sampleReceive <= '1';
                    bitStuffingCounter <= 1;
                    var_CalculatedCrc := (others => '0');
                    
                end if;
                sig_rxPinPrev <= sig_rxPin;
                sig_read_validPrevReceive := sig_read_valid;
            
            
            when SOF =>      
                
                  --  start of frame must be '0'
                   --sig_read_validPrev = '0' and 
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then    -- BTL finished to sample receive bit
                     
                    if(sig_RxBit = '0') then            -- sof must be recessive to start of frame
                        
                        CrcNextBit :=  sig_RxBit xor var_CalculatedCrc(14);
                        var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                        var_CalculatedCrc(0) := '0';
                        
                        if (CrcNextBit = '1') then
                              var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                        end if;
                        
                        receiveFrameEnum <= ID;         --  change state to recieve std id
                        sig_check_arbitration <= '1';   -- frame enter to arbitration stage. Arbitration stage consist only std id and rtr stages
                        receivePackageCounter <= SIZE_OF_STD_ID - 1;     -- receivePackageCounter reset to collect std id bits
                        receiveFrame.Sof <= sig_RxBit;  -- storage Sof bit
                        bitStuffingCounter <= 1;
                        receiveFrameEnumPrev <= ID;
                        sig_rxPinPrev <= sig_RxBit;
                    else
                    
                        receiveFrameEnum <= IDLE;   
                        sig_errorOccured_receive <= '1';
                        error_receive(Location_Error_Sof) <= '1';
                    end if;
                    ------------------------

                end if;
            sig_read_validPrevReceive := sig_read_valid;
            when ID =>   
              
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then       
                     
                     -- calculate crc sequance
                        CrcNextBit :=  sig_RxBit xor var_CalculatedCrc(14);
                        var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                        var_CalculatedCrc(0) := '0';                    
                        if (CrcNextBit = '1') then
                              var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                        end if;
                              
                    receiveFrame.StdId(receivePackageCounter) <= sig_RxBit;     -- storage all received bits until received bits counter reach to size of std
                    receivePackageCounter <= receivePackageCounter - 1;
                    if(receivePackageCounter = 0) then             -- if counter reach to size of std set enum to rtr
                      
                      receiveFrameEnum <= RTR;                  
                      
                    end if;
                    
                    -- check bit stuffing
                    receiveFrameEnumPrev <= receiveFrameEnum;       
                    
                    if(sig_RxBit = '0' and txBitPrevForArbitration = '1') then
                    
                        arbitrationLost <= '1';
                    
                    end if;
                    
                    if(sig_RxBit = sig_rxPinPrev) then
                    
                        bitStuffingCounter <= bitStuffingCounter + 1;
                        
                        if(bitStuffingCounter = 4) then
                        
                            bitStuffingWillWaitBit <= not sig_RxBit;
                            receiveFrameEnum <= STUFFING;      
                            bitStuffingCounter <= 1;
                            
                        end if;
                    
                    else
                    
                        bitStuffingCounter <= 1;
                    
                    end if;

                    -- end of check bit stuffing
                    
                    
                    sig_rxPinPrev <= sig_RxBit;
                end if;
            sig_read_validPrevReceive := sig_read_valid;
            
            
            when RTR =>     
                                                -- remote control enum if rtr bit recessive frame is remote frame or rtr bit dominant frame is data    
               
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then

                    CrcNextBit :=  sig_RxBit xor var_CalculatedCrc(14);
                    var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                    var_CalculatedCrc(0) := '0';
                    
                    if (CrcNextBit = '1') then
                          var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                    end if;
                                    
                    
                    receiveFrame.Rtr <= sig_RxBit;                  
                    sig_check_arbitration <= '0';
                    receiveFrameEnum <= IDE;
                     -- check bit stuffing
                    receiveFrameEnumPrev <= IDE;       
                    ------------------------
                       if(sig_RxBit = sig_rxPinPrev) then
                    
                        bitStuffingCounter <= bitStuffingCounter + 1;
                        
                        if(bitStuffingCounter = 4) then
                        
                            bitStuffingWillWaitBit <= not sig_RxBit;
                            receiveFrameEnum <= STUFFING;
                            bitStuffingCounter <= 1;
                            
                        end if;
                    
                    else
                    
                        bitStuffingCounter <= 1;
                    
                    end if;
                ------------------------------------------
                    -- end of check bit stuffing                   
                sig_rxPinPrev <= sig_RxBit;
                end if;
            sig_read_validPrevReceive := sig_read_valid;
            when IDE =>
               
                 if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then

                    CrcNextBit :=  sig_rxBit xor var_CalculatedCrc(14);
                    var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                    var_CalculatedCrc(0) := '0';
                    
                    if (CrcNextBit = '1') then
                          var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                    end if;
                                    
                    receiveFrameEnum <= RESERVE;       -- then check ; if rxBit = '0' stdID or rxBit = '1' extended id. now state machine not check extended frame. it can add in future.
                    receiveFrame.Ide <= sig_RxBit;
                    -- check bit stuffing
                    receiveFrameEnumPrev <= RESERVE;       

                    ------------------------
                       if(sig_RxBit = sig_rxPinPrev) then
                    
                        bitStuffingCounter <= bitStuffingCounter + 1;
                        
                        if(bitStuffingCounter = 4) then
                        
                            bitStuffingWillWaitBit <= not sig_RxBit;
                            receiveFrameEnum <= STUFFING;
                            bitStuffingCounter <= 1;
                            
                        end if;
                    
                    else
                    
                        bitStuffingCounter <= 1;
                    
                    end if;
                ------------------------------------------
                sig_rxPinPrev <= sig_RxBit;
                end if;
             sig_read_validPrevReceive := sig_read_valid;   
             
             when RESERVE =>
           
               if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then

                    CrcNextBit :=  sig_rxBit xor var_CalculatedCrc(14);
                    var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                    var_CalculatedCrc(0) := '0';
                    
                    if (CrcNextBit = '1') then
                          var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                    end if;
                                        
                    if(sig_RxBit = '0') then    
                        receiveFrame.Reserved <= sig_RxBit;
                        receivePackageCounter <= SIZE_OF_DLC - 1;
                        receiveFrameEnum <= DLC;

                     -- check bit stuffing
                    receiveFrameEnumPrev <= DLC;   
                    ------------------------
                       if(sig_RxBit = sig_rxPinPrev) then
                    
                        bitStuffingCounter <= bitStuffingCounter + 1;
                        
                        if(bitStuffingCounter = 4) then
                            
                            bitStuffingWillWaitBit <= not sig_RxBit;
                            receiveFrameEnum <= STUFFING;
                            bitStuffingCounter <= 1;
                        end if;
                        

                    
                    else
                    
                        bitStuffingCounter <= 1;
                    
                    end if;
                    

                ------------------------------------------
                    -- end of check bit stuffing    
                                       
                    else
                       
                        receiveFrameEnum <= IDLE;
                        sig_errorOccured_receive <= '1';
                        error_receive(Location_Error_Reserve) <= '1';
                        -- then check ; if rxBit not '0' add error because reserve bit must be 0 
                    
                    end if;
                sig_rxPinPrev <= sig_RxBit;              
                end if;
            sig_read_validPrevReceive := sig_read_valid;
            
            when DLC => 
            
                   -- collect data bits to receive enum. 
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then  

                    CrcNextBit :=  sig_rxBit xor var_CalculatedCrc(14);
                    var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                    var_CalculatedCrc(0) := '0';
                    
                    if (CrcNextBit = '1') then
                          var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                    end if;
                                         
                    dlcIterator(receivePackageCounter) := sig_RxBit;
                    receivePackageCounter <= receivePackageCounter - 1;
                    if(receivePackageCounter = 0) then
                        receiveFrame.Dlc <= dlcIterator;
                        receveDataByteSize := to_integer(unsigned(dlcIterator));          -- get dlc size as integer to use at another enums.
                        if(receveDataByteSize /= 0  and receiveFrame.Rtr = '0') then       -- if DLC is 0 or frame is remote skip data enum and go to crc field.
                             receiveDataByteCounter <= 0;
                             receivePackageCounter <= 7;
                             receiveFrameEnum <= DATA;    
                             receiveFrameEnumPrev <= DATA;         
                        else                       
                            receiveFrameEnum <= CRC;       
                            receivePackageCounter <= SIZE_OF_CRC - 1;
                            receiveFrameEnumPrev <= CRC;  

                        end if;
                    else
                    
                        receiveFrameEnumPrev <= DLC;  
                        
                    end if;
                    
--                    -- check bit stuffing    
                    ----------------------
                       if(sig_RxBit = sig_rxPinPrev) then
                    
                        bitStuffingCounter <= bitStuffingCounter + 1;
                        
                        if(bitStuffingCounter = 4) then
                        
                            bitStuffingWillWaitBit <= not sig_RxBit;
                            receiveFrameEnum <= STUFFING;
                            bitStuffingCounter <= 1;
                            
                        end if;
                    
                    else
                    
                        bitStuffingCounter <= 1;
                    
                    end if;
                ------------------------------------------
                    -- end of check bit stuffing    
                 sig_rxPinPrev <= sig_RxBit;   
                end if;            
            sig_read_validPrevReceive := sig_read_valid;
            
            when DATA =>            -- collect data bits until received bits size reach to dlc size
            
              if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then

                    CrcNextBit :=  sig_rxBit xor var_CalculatedCrc(14);
                    var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                    var_CalculatedCrc(0) := '0';
                    
                    if (CrcNextBit = '1') then
                          var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                    end if;
                                   
                    receiveFrameEnumPrev <= DATA;
                    receiveFrame.Data(receiveDataByteCounter)(receivePackageCounter) <= sig_RxBit;
                    receivePackageCounter <= receivePackageCounter - 1;
                    if(receivePackageCounter = 0) then
                        receivePackageCounter <= 7;
                        receiveDataByteCounter <= receiveDataByteCounter + 1;
                        if(receiveDataByteCounter = 7) then
                            receiveDataByteCounter <= 0;
                            receivePackageCounter <= SIZE_OF_CRC - 1;
                            receiveFrameEnum <= CRC;
                            receiveFrameEnumPrev <= CRC;
                         else
                         
                             receiveFrameEnumPrev <= DATA;       
                         
                        end if;
                        
                    end if;
                    
                    -- check bit stuffing
                    
                    ------------------------
                      if(sig_RxBit = sig_rxPinPrev) then
                    
                        bitStuffingCounter <= bitStuffingCounter + 1;
                        
                        if(bitStuffingCounter = 4) then
                        
                            bitStuffingWillWaitBit <= not sig_RxBit;
                            receiveFrameEnum <= STUFFING;
                            bitStuffingCounter <= 1;
                            
                        end if;
                    
                    else
                    
                        bitStuffingCounter <= 1;
                    
                    end if;
                ------------------------------------------
                    -- end of check bit stuffing   
                sig_rxPinPrev <= sig_RxBit;   
                end if;
            sig_read_validPrevReceive := sig_read_valid; 
            
            
            when CRC =>                         -- crc stage to collect crc bits
               
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then
                 
                    receivePackageCounter <= receivePackageCounter - 1;
                    receivedCrc(receivePackageCounter) := sig_RxBit;
                    if(receivePackageCounter = 0) then                -- if received bits reach to size of crc compare receive crc and calculated crc
                        receivePackageCounter <= 0;
                         if(receivedCrc(14 downto 0) = var_CalculatedCrc(14 downto 0)) then    -- if calculated crc match with received crc send ack bit at crc delimeter field. if not not send anything.
                           
                           receiveFrameEnum <= CRC_DELIMITER;
                           receiveFrameEnumPrev <= CRC_DELIMITER;   
                           
                         else

                                  receiveFrameEnum <= IDLE;
                                  sig_errorOccured_receive <= '1';
                                  error_receive(Location_Error_Crc) <= '1';
                         end if;
                    else
                    
                        -- check bit stuffing
                        receiveFrameEnumPrev <= CRC;       
                    ------------------------

                ------------------------------------------
                        -- end of check bit stuffing  

                    end if;
                    
                       if(sig_RxBit = sig_rxPinPrev) then
                    
                        bitStuffingCounter <= bitStuffingCounter + 1;
                        
                        if(bitStuffingCounter = 4) then
                        
                            bitStuffingWillWaitBit <= not sig_RxBit;
                            receiveFrameEnum <= STUFFING;
                            bitStuffingCounter <= 1;
                            
                        end if;
                    
                    else
                    
                        bitStuffingCounter <= 1;
                    
                    end if;
                    
                sig_rxPinPrev <= sig_RxBit;     
                end if;
            sig_read_validPrevReceive := sig_read_valid;
            
            when CRC_DELIMITER =>           -- for crc delimeter send dominant bit to transmitter.
            
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then

                    if(sig_transmitting = '0') then 
                        sig_write_orderReceive <= '1';
                        sig_TxBitReceive <= '0';
                        receiveFrameEnum <= ACK;
                    else
                    
                        receiveFrameEnum <= ACK;
                        
                    end if;

                end if;
                sig_read_validPrevReceive := sig_read_valid;  
                sig_write_valid_prev := sig_write_valid;
            when ACK =>                 -- send dominant bit at ack
                
                   if(sig_write_valid_prev = '0' and sig_write_valid = '1') then
                   
                    if(sig_transmitting = '0') then
                        sig_write_orderReceive <= '1';
                        sig_TxBitReceive <= '1';
                        receiveFrameEnum <= ACK_DELIMITER;
                   else
                   
                        receiveFrameEnum <= ACK_DELIMITER;
                   
                   end if;     
                        
                   end if;
                   sig_write_valid_prev := sig_write_valid;
                 sig_read_validPrevReceive := sig_write_valid;
            when ACK_DELIMITER =>               
            
                sig_write_orderReceive <= '0';
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then

                    receiveFrameEnum <= EOF;
                    receivePackageCounter <= SIZE_OF_EOF - 1;

                end if;
               sig_read_validPrevReceive := sig_read_valid; 
                 
            when EOF =>                                                     -- collect all eof bits check all bits if equal to recessive bit.
              
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then
                    
                   if(sig_rxBit = '1') then     
                        receivePackageCounter <= receivePackageCounter - 1;
                        if(receivePackageCounter = 0) then
    
                                receiveFrameEnum <= IFS;
                                receivePackageCounter <= SIZE_OF_IFS - 1;
                            
                        end if;
                    else
                    
                        receiveFrameEnum <= IDLE;
                        sig_errorOccured_receive <= '1';
                        error_receive(Location_Error_EOF) <= '1';    
                        
                  end if; 
                end if; 
           sig_read_validPrevReceive := sig_read_valid;     
           when IFS =>                                      -- collect all ifs bits check all bits if equal to recessive bit.
             
                if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then
                
                  if(sig_rxBit = '1') then 
                    receivePackageCounter <= receivePackageCounter - 1;
                    if(receivePackageCounter = 0) then

                            receiveFrameEnum <= IDLE;
                            sig_start_sampleReceive <= '0';
                            sig_receiveIT   <= '0';
                            
                            
                            receivePackage.StdId <= ReceiveFrame.StdId;
                            receivePackage.Data <= ReceiveFrame.Data;
                            receivePackage.Dlc  <= ReceiveFrame.Dlc;
                            receivePackage.Rtr  <= receiveFrame.Rtr;
                    
                    end if;
                  else
                
                        -- TODO error                  
                        receiveFrameEnum <= IDLE;
                        sig_errorOccured_receive <= '1';
                        error_receive(Location_Error_IFS) <= '1'; 
                        
                  end if;
                end if;
          sig_read_validPrevReceive := sig_read_valid;      
          
          when STUFFING =>
           
            if(sig_read_validPrevReceive = '0' and sig_read_valid = '1') then
                if(sig_RxBit = bitStuffingWillWaitBit) then
                    
                    receiveFrameEnum <= receiveFrameEnumPrev;
                    sig_rxPinPrev <= sig_RxBit;
                    
                else
                
                    receiveFrameEnum <= IDLE;
                    error_receive(Location_Error_BitStuffing) <= '1';
                    -- TODO add bit stuffing error.
                end if;
                
            end if;
           
        sig_read_validPrevReceive := sig_read_valid;  
        
        when LOCK =>
        
           
            sig_start_sampleReceive <= '0';
        
        end case;
        
    
    end if;
    
    end process;
    
    --transmit process to stream to BTL
    transmitProcess : process
    
    variable transmitPackageCounter : integer := 0;         -- for check transmit bits
    variable transmitDataByteCounter : integer := 0;        -- for check transmit data counter
    variable transmitBitStuffingCounter : integer := 0;     -- check bit stuffing counter
    variable transmitNextBit            : std_logic;        -- next bit to send
    -- for calculate crc
    variable    CrcNextBit                 :  std_logic;
    variable    var_CalculatedCrc          :  std_logic_vector(14 downto 0) := "000000000000000";
    
    variable sig_read_validPrevTransmit : std_logic;

    variable transmitOrderPrev : std_logic := '0';
    


    begin
    if(rising_edge(clk_in) ) then
  
        case(transmitFrameEnum) is
        
        when IDLE =>

           
           if(transmitOrderPrev = '0' and transmitOrder = '1') then     -- start transmit order rising edge
        
              startTransmit <= '1';
               
            end if;
            transmitOrderPrev := transmitOrder;
            
            sig_write_orderTransmit <= '0';
            sig_transmitting <= '0'; 
            sig_transmitIT <= '1';
            sig_errorOccured_transmsit <= '0';
            if(startTransmit = '1' and sig_receiving = '0') then 
                -- reset all signals to start
                startTransmit <= '0';
                sig_transmitting <= '1';
                sig_TxBitTransmit <= '0';
                sig_TxBitPrev <= '0';
                sig_write_orderTransmit <= '1';
                transmitFrameEnum <= SOF;                 -- send sof bit to start transmit
                transmitBitStuffingCounter := 1;
                transmitNextBit := '0';
                var_CalculatedCrc := (others => '0');
                
                transmitFrame.StdId <= transmitPackage.StdId;       -- get top module's package to send
                transmitFrame.Dlc <= transmitPackage.Dlc;
                transmitFrame.Rtr <= transmitPackage.Rtr;
                transmitFrame.Data <= transmitPackage.Data;
                
                -- calculate crc sequance to send crc at crc field
                CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                var_CalculatedCrc(0) := '0';
                if (CrcNextBit = '1') then
                    var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                end if;
                
            end if;   
             
        when SOF =>     

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
                
                
                -- start of bit stuffing control
                if(transmitBitStuffingCounter = 5) then         -- if previous 5 bit same send not bit
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;

                else
                
                    transmitPackageCounter := SIZE_OF_STD_ID - 1;                   -- set package counter with std bit size
                    transmitNextBit := transmitFrame.StdId(transmitPackageCounter);
                    transmitFrameEnum <= ID;
 
                    if(sig_TxBitPrev = transmitNextBit) then            -- if transmit next bit same with prev increase counter
                    
                        transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                    
                    else
                    
                        transmitBitStuffingCounter := 1;
                    
                    end if;
                    
                    CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                    var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                    var_CalculatedCrc(0) := '0';
                        
                    if (CrcNextBit = '1') then
                        var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                    end if;
                   
                end if;
                -- end of bit stuffing control
                sig_TxBitTransmit <= transmitNextBit;
                sig_TxBitPrev <= transmitNextBit;
                txBitPrevForArbitration <= transmitNextBit;
            end if;
        
        when ID =>

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
                
                                
                if(arbitrationLost = '1') then      -- if arbitration lost wait to resend at end of receive
                                             
                   startTransmit <= '1';
                   sig_TxBitTransmit <= '1';
                   transmitFrameEnum <= IDLE;
                   
                end if;

                if(transmitBitStuffingCounter = 5) then
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;
                                  
                else

                    if(transmitPackageCounter = 0) then
                        
                        transmitNextBit := transmitFrame.Rtr;
                        transmitFrameEnum <= RTR;
                    else
                    
                        transmitPackageCounter := transmitPackageCounter - 1;
                        transmitNextBit := transmitFrame.StdId(transmitPackageCounter);

                    end if;
                    
                    if(sig_TxBitPrev = transmitNextBit) then
                        
                        transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                       
                    else
                        
                         transmitBitStuffingCounter := 1;
                        
                    end if;
                     
                        CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                        var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                        var_CalculatedCrc(0) := '0';
                            
                        if (CrcNextBit = '1') then
                            var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                        end if;
--                        txBitPrevForArbitration <= transmitNextBit;
                end if;
                -- end of bit stuffing control
                
             
             sig_TxBitTransmit <= transmitNextBit;
             sig_TxBitPrev <= transmitNextBit;
             end if;
              
         when RTR =>

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
          
                if(arbitrationLost = '1') then
                                             
                   startTransmit <= '1';
                   sig_TxBitTransmit <= '1';
                   transmitFrameEnum <= IDLE;
                
                end if;
                
                -- start of bit stuffing control
                if(transmitBitStuffingCounter = 5) then
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;
                    
                else
                    
                    transmitNextBit := '0';
                    transmitFrameEnum <= IDE;
                    
                    if(sig_TxBitPrev = transmitNextBit) then
                        
                        transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                        
                    else
                        
                        transmitBitStuffingCounter := 1;
                        
                    end if;
                    
                   CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                   var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                   var_CalculatedCrc(0) := '0';
                            
                   if (CrcNextBit = '1') then
                       var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                   end if;
                        
                end if;
                sig_TxBitPrev <= transmitNextBit;
                sig_TxBitTransmit <= transmitNextBit;
            end if;

          
          when IDE =>
          

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
                
             
                if(transmitBitStuffingCounter = 5) then
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;
                    
                else
                    
                    transmitNextBit := '0';
                    transmitFrameEnum <= RESERVE;
                    
                    if(sig_TxBitPrev = transmitNextBit) then
                        
                        transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                        
                    else
                        
                        transmitBitStuffingCounter := 1;
                        
                    end if;
                    
                   CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                   var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                   var_CalculatedCrc(0) := '0';
                            
                   if (CrcNextBit = '1') then
                       var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                   end if;
                   
                end if;
                sig_TxBitPrev <= transmitNextBit;
                sig_TxBitTransmit <= transmitNextBit;
                              
            
            end if;
                     
            
          when RESERVE =>

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
                            
              
                if(transmitBitStuffingCounter = 5) then
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;
                    
                else
                    transmitPackageCounter := SIZE_OF_DLC - 1;
                    transmitNextBit := transmitFrame.Dlc(transmitPackageCounter);
                    transmitFrameEnum <= DLC;
                    if(sig_TxBitPrev = transmitNextBit) then
                        
                        transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                    
                    else
                    
                        transmitBitStuffingCounter := 1;
                    
                    end if;
                    
                   CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                   var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                   var_CalculatedCrc(0) := '0';
                            
                   if (CrcNextBit = '1') then
                       var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                   end if;
                
                end if;

                sig_TxBitTransmit <= transmitNextBit;
                sig_TxBitPrev <= transmitNextBit;
                
            end if;
         
          when DLC =>

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
                
                if(transmitBitStuffingCounter = 5) then
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;
                else    
                    if(transmitPackageCounter = 0) then
                        if(transmitFrame.Rtr = '0' and transmitFrame.Dlc /= "0000") then
                            transmitPackageCounter := 7;
                            transmitDataByteCounter := 0;
                            transmitNextBit := transmitFrame.Data(transmitDataByteCounter)(transmitPackageCounter);
                            transmitFrameEnum <= DATA;
                            
                            CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                            var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                            var_CalculatedCrc(0) := '0';        
                            if (CrcNextBit = '1') then
                                 var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                            end if;
                            
                        else
                        
                            transmitPackageCounter := SIZE_OF_CRC - 1;
                            transmitNextBit := var_CalculatedCrc(transmitPackageCounter);
                            transmitFrameEnum <= CRC;
                        
                        end if;
                    else
                        transmitPackageCounter := transmitPackageCounter - 1;
                        transmitNextBit := transmitFrame.Dlc(transmitPackageCounter); 
                        
                        CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                        var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                        var_CalculatedCrc(0) := '0';        
                        if (CrcNextBit = '1') then
                             var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                        end if;

                     end if;
                  
                     if(sig_TxBitPrev = transmitNextBit) then
                        
                        transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                        
                     else
                        
                        transmitBitStuffingCounter := 1;
                        
                     end if; 

                end if;
                -- end of bit stuffing control
             sig_TxBitPrev <= transmitNextBit;
             sig_TxBitTransmit <= transmitNextBit;
             end if;
              
         
          when DATA =>

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then

                if(transmitBitStuffingCounter = 5) then
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;
                else
                    if((transmitDataByteCounter = to_integer(unsigned(transmitFrame.Dlc)) - 1) and transmitPackageCounter = 0) then                
                        
                        transmitPackageCounter := SIZE_OF_CRC - 1;
                        transmitNextBit := var_CalculatedCrc(transmitPackageCounter);
                        transmitFrameEnum <= CRC;

                    else
                        if(transmitPackageCounter = 0) then
                        
                            transmitPackageCounter := 7;
                            transmitDataByteCounter := transmitDataByteCounter + 1;
                        
                        else
                        
                            transmitPackageCounter := transmitPackageCounter - 1;
                        
                        end if;
                        
                        transmitNextBit := transmitFrame.Data(transmitDataByteCounter)(transmitPackageCounter);                       
                        
                       CrcNextBit :=  transmitNextBit xor var_CalculatedCrc(14);
                       var_CalculatedCrc(14 downto 1) := var_CalculatedCrc(13 downto 0);
                       var_CalculatedCrc(0) := '0';
                                
                       if (CrcNextBit = '1') then
                           var_CalculatedCrc(14 downto 0) := var_CalculatedCrc(14 downto 0) xor b"100010110011001"; --! CRC-15-CAN: x"4599"
                       end if;
                       

                    end if;
                        if(sig_TxBitPrev = transmitNextBit) then
                        
                            transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                        
                        else
                        
                            transmitBitStuffingCounter := 1;
                        
                        end if;
                end if;

             sig_TxBitPrev <= transmitNextBit;
             sig_TxBitTransmit <= transmitNextBit;
             end if; 
         
           
         when CRC =>

                if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
                

                if(transmitBitStuffingCounter = 5) then
                
                    transmitNextBit := not sig_TxBitPrev;
                    transmitBitStuffingCounter := 1;
                else
                    if(transmitPackageCounter = 0) then
                        
                        transmitNextBit := '1';
                        transmitFrameEnum <= CRC_DELIMITER;
                        
                    else
                        transmitPackageCounter := transmitPackageCounter - 1;
                        transmitNextBit := var_CalculatedCrc(transmitPackageCounter);
                        if(sig_TxBitPrev = transmitNextBit) then
                        
                            transmitBitStuffingCounter := transmitBitStuffingCounter + 1;
                        
                        else
                        
                            transmitBitStuffingCounter := 1;
                        
                        end if;
                    end if;
                end if;

             sig_TxBitPrev <= transmitNextBit;
             sig_TxBitTransmit <= transmitNextBit;
             end if;   


         when CRC_DELIMITER =>

            if(sig_write_valid_previous = '0' and sig_write_valid = '1') then

                transmitNextBit := '1';
                transmitFrameEnum <= ACK;
                sig_start_sampleTransmit <= '1';

            end if; 
            sig_read_validPrevTransmit := sig_read_valid;
           when ACK =>

            if(sig_read_validPrevTransmit = '0' and sig_read_valid = '1') then
                
                if(sig_RxBit = '0') then
                
                    sig_TxBitTransmit <= '1';
                    transmitFrameEnum <= ACK_DELIMITER;
                    sig_start_sampleTransmit <= '0';
                    
                else
                    sig_TxBitTransmit <= '1';
                    transmitFrameEnum <= ACK_DELIMITER;
                    sig_start_sampleTransmit <= '0';
                    transmitError <= '1';
                    error_transmit(Location_Error_Ack) <= '1';
                    sig_errorOccured_transmsit <= '1';
                       
                end if;
                
            end if;
            sig_read_validPrevTransmit := sig_read_valid; 
        
              when ACK_DELIMITER =>

               if(sig_write_valid_previous = '0' and sig_write_valid = '1') then
                    
                    transmitPackageCounter := SIZE_OF_EOF - 1;
                    sig_TxBitTransmit <= '1';
                    transmitFrameEnum <= EOF;
                                    
               end if;
              
              when EOF =>

                    if(sig_write_valid_previous = '0' and sig_write_valid = '1') then

                        if(transmitPackageCounter = 0) then
                        
                            transmitPackageCounter := SIZE_OF_IFS - 1;
                            sig_TxBitTransmit <= '1';
                            transmitFrameEnum <= IFS;
                        
                        else
                        
                            transmitPackageCounter := transmitPackageCounter - 1;
                            sig_TxBitTransmit <= '1';
                        
                        end if;
                    
                    end if;
             
              when IFS =>

                        if(sig_write_valid_previous = '0' and sig_write_valid = '1') then

                        if(transmitPackageCounter = 0) then
                        
                            sig_TxBitTransmit <= '1';
                            transmitFrameEnum <= IDLE;

                            if(transmitError = '1') then
                            
                               transmitError <= '0';
                                startTransmit <= '1';
                                
                            else
                            
                                startTransmit <= '0';
                                sig_transmitIT <= '0';
                                
                            end if;
                            sig_write_orderTransmit <= '0';
                        else
                            
                            transmitPackageCounter := transmitPackageCounter - 1;
                            sig_TxBitTransmit <= '1';
                            
                        
                        end if;
                      
                    end if;
              
      
        when STUFFING =>        -- not necessary change state. because stuff bit send at avaible state
        
        
        when LOCK =>        -- for test
        
        
              
        end case;
        sig_write_valid_previous <= sig_write_valid;
    end if;                
    end process;
    
        
    end Behavioral;
