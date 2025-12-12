----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    
-- Design Name: 
-- Module Name:    top_level - Structural 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Top level design connecting Phase1_fsm, clock_divider, 
--              spi_controller, and display components for ADXL345 interface
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity top_level is
    port (
        -- System signals
        CPU_RESETN : in  std_logic;                       -- Reset button (active low)
        SYS_CLK    : in  std_logic;                       -- 100 MHz clock
        
        -- Board I/O
        LED        : out std_logic_vector(15 downto 0);   -- LEDs for data display
        SW         : in  std_logic_vector(15 downto 0);   -- Switches for axis selection
        
        -- Accelerometer SPI interface
        ACL_SCLK   : out std_logic;                       -- SPI clock line
        ACL_CSN    : out std_logic;                       -- Chip select (active low)
        ACL_MOSI   : out std_logic;                       -- Master out slave in
        ACL_MISO   : in  std_logic;                       -- Master in slave out
        
        -- Seven segment display outputs
        CA, CB, CC, CD, CE, CF, CG : out std_logic;       -- Cathode segments
        DP         : out std_logic;                       -- Decimal point
        AN         : out std_logic_vector(7 downto 0)     -- Anode enables
    );
end top_level;

architecture Structural of top_level is

    --------------------------------------------------------------------
    -- Component declarations
    --------------------------------------------------------------------
    
    component clock_divider is
        generic(
            G_DIVISOR : integer := 50000000
        );
        port(
            i_clk   : in  std_logic;
            i_rstb  : in  std_logic;
            o_clk_out  : out std_logic
        );
    end component;
    
    component Phase1_fsm is
        port (
            i_clk           : in  std_logic;                      -- 100 MHz system clock
            i_rstb          : in  std_logic;                      -- Active-low reset
            i_start         : in  std_logic;                      -- Start signal (2 Hz pulse)
            i_tx_end        : in  std_logic;                      -- SPI transaction complete
            i_rx_data       : in  std_logic_vector(15 downto 0);  -- Data received from SPI
            o_tx_start      : out std_logic;                      -- Start SPI transaction
            o_tx_data       : out std_logic_vector(15 downto 0);  -- Data to send via SPI
            o_x_axis_data   : out std_logic_vector(15 downto 0);  -- X-axis acceleration data
            o_y_axis_data   : out std_logic_vector(15 downto 0);  -- Y-axis acceleration data
            o_z_axis_data   : out std_logic_vector(15 downto 0)   -- Z-axis acceleration data
        );
    end component;
    
    component spi_controller is
        generic(
            N       : integer := 16;
            CLK_DIV : integer := 100
        );
        port (
            i_clk           : in  std_logic;
            i_rstb          : in  std_logic;
            i_tx_start      : in  std_logic;
            o_tx_end        : out std_logic;
            i_data_parallel : in  std_logic_vector(N-1 downto 0);
            o_data_parallel : out std_logic_vector(N-1 downto 0);
            o_sclk          : out std_logic;
            o_ss            : out std_logic;
            o_mosi          : out std_logic;
            i_miso          : in  std_logic
        );
    end component;
    
    component binary_to_bcd is
        port (
            i_binary   : in  std_logic_vector(9 downto 0);
            o_sign     : out std_logic;
            o_hundreds : out std_logic_vector(3 downto 0);
            o_tens     : out std_logic_vector(3 downto 0);
            o_ones     : out std_logic_vector(3 downto 0)
        );
    end component;
    
    component BCDto7Segment is
        port (
            i_digit_sel : in  std_logic_vector(1 downto 0);
            i_sign      : in  std_logic;
            i_hundreds  : in  std_logic_vector(3 downto 0);
            i_tens      : in  std_logic_vector(3 downto 0);
            i_ones      : in  std_logic_vector(3 downto 0);
            o_segments  : out std_logic_vector(6 downto 0)
        );
    end component;
    
    component DisplayMultiplexer is
        port (
            i_clk       : in  std_logic;
            i_reset     : in  std_logic;
            o_digit_sel : out std_logic_vector(1 downto 0);
            o_anodes    : out std_logic_vector(7 downto 0);
            o_dp        : out std_logic
        );
    end component;

    --------------------------------------------------------------------
    -- Internal wire signals
    --------------------------------------------------------------------
    
    -- Reset signal 
    signal w_reset_active_low : std_logic;
    
    -- Clock divider to FSM
    signal w_pulse_2hz : std_logic;
    
    -- FSM to SPI controller interface
    signal w_spi_tx_start      : std_logic;
    signal w_spi_tx_complete   : std_logic;
    signal w_spi_data_to_send  : std_logic_vector(15 downto 0);
    signal w_spi_data_received : std_logic_vector(15 downto 0);
    
    -- Accelerometer axis data from FSM
    signal w_accel_x_data : std_logic_vector(15 downto 0);
    signal w_accel_y_data : std_logic_vector(15 downto 0);
    signal w_accel_z_data : std_logic_vector(15 downto 0);
    
    -- Axis selection and display
    signal w_axis_selected    : std_logic_vector(15 downto 0);
    signal w_ten_bit_data     : std_logic_vector(9 downto 0);
    
    -- BCD conversion outputs
    signal w_bcd_sign     : std_logic;
    signal w_bcd_hundreds : std_logic_vector(3 downto 0);
    signal w_bcd_tens     : std_logic_vector(3 downto 0);
    signal w_bcd_ones     : std_logic_vector(3 downto 0);
    
    -- Display multiplexer to BCD decoder interface
    signal w_digit_selector : std_logic_vector(1 downto 0);
    
    -- Seven segment display
    signal w_segments : std_logic_vector(6 downto 0);

begin

    -- Invert reset for active high logic
    w_reset_active_low <= CPU_RESETN;
    
    --------------------------------------------------------------------
    -- Axis selection multiplexer
    -- SW(1 downto 0): 00=X-axis, 01=Y-axis, 1X=Z-axis
    --------------------------------------------------------------------
    axis_select: process(SW, w_accel_x_data, w_accel_y_data, w_accel_z_data)
    begin
        case SW(1 downto 0) is
            when "00" =>
                w_axis_selected <= w_accel_x_data;
            when "01" =>
                w_axis_selected <= w_accel_y_data;
            when others =>
                w_axis_selected <= w_accel_z_data;
        end case;
    end process axis_select;
    
    -- Extract 10-bit signed data from 16-bit register
    w_ten_bit_data <= w_axis_selected(9 downto 0);
    
    -- Show selected axis on LEDs
    LED <= w_axis_selected;
    
    --------------------------------------------------------------------
    -- Component instantiations
    --------------------------------------------------------------------
    
    -- 2 Hz pulse generator from 100 MHz clock
    inst_clk_div : clock_divider
        generic map (
            G_DIVISOR => 50000000  -- 100 MHz / 50M = 2 Hz
        )
        port map (
            i_clk   => SYS_CLK,
            i_rstb  => w_reset_active_low,
            o_clk_out  => w_pulse_2hz
        );
    
    -- Main control FSM for accelerometer
    inst_phase1_fsm : Phase1_fsm
        port map (
            i_start         => w_pulse_2hz,
            i_clk           => SYS_CLK,
            i_rstb          => w_reset_active_low,
            o_tx_start      => w_spi_tx_start,
            i_tx_end        => w_spi_tx_complete,
            o_tx_data       => w_spi_data_to_send,
            i_rx_data       => w_spi_data_received,
            o_x_axis_data   => w_accel_x_data,
            o_y_axis_data   => w_accel_y_data,
            o_z_axis_data   => w_accel_z_data
        );
    
    -- SPI communication controller
    inst_spi : spi_controller
        generic map (
            N       => 16,
            CLK_DIV => 100
        )
        port map (
            i_clk           => SYS_CLK,
            i_rstb          => w_reset_active_low,
            i_tx_start      => w_spi_tx_start,
            o_tx_end        => w_spi_tx_complete,
            i_data_parallel => w_spi_data_to_send,
            o_data_parallel => w_spi_data_received,
            o_sclk          => ACL_SCLK,
            o_ss            => ACL_CSN,
            o_mosi          => ACL_MOSI,
            i_miso          => ACL_MISO
        );
    
    -- Convert binary acceleration to BCD digits
    inst_bin_to_bcd : binary_to_bcd
        port map (
            i_binary   => w_ten_bit_data,
            o_sign     => w_bcd_sign,
            o_hundreds => w_bcd_hundreds,
            o_tens     => w_bcd_tens,
            o_ones     => w_bcd_ones
        );
    
    -- Display multiplexer (handles timing and digit selection)
    inst_display_mux : DisplayMultiplexer
        port map (
            i_clk       => SYS_CLK,
            i_reset     => w_reset_active_low,
            o_digit_sel => w_digit_selector,
            o_anodes    => AN,
            o_dp        => DP
        );
    
    -- BCD to 7-segment decoder (converts BCD digits to segment codes)
    inst_bcd_decoder : BCDto7Segment
        port map (
            i_digit_sel => w_digit_selector,
            i_sign      => w_bcd_sign,
            i_hundreds  => w_bcd_hundreds,
            i_tens      => w_bcd_tens,
            i_ones      => w_bcd_ones,
            o_segments  => w_segments
        );
    
    -- Connect segment outputs to individual cathode pins
    CA <= w_segments(0);
    CB <= w_segments(1);
    CC <= w_segments(2);
    CD <= w_segments(3);
    CE <= w_segments(4);
    CF <= w_segments(5);
    CG <= w_segments(6);

end Structural;