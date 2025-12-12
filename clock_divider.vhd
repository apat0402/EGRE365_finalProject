----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:51:54 03/09/2016 
-- Design Name: 
-- Module Name:    clock_divider - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Generates a single-cycle pulse at 2 Hz from 100 MHz input clock
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

entity clock_divider is
  generic(
    CLK_FREQ        : positive := 100_000_000;  -- input clock frequency in Hz
    PULSE_FREQ      : positive := 2             -- output pulse frequency in Hz
  );
  port(
    i_mclk   : in  std_logic;  -- master clock input
    i_reset  : in  std_logic;  -- synchronous reset (active high)
    o_pulse  : out std_logic   -- output pulse
  );
end clock_divider;

architecture Behavioral of clock_divider is
    -- Calculate divisor from frequencies
    constant C_DIVISOR : positive := CLK_FREQ / PULSE_FREQ;
    
    -- Internal signals
    signal r_count      : integer range 0 to C_DIVISOR-1 := 0;
    signal r_pulse_out  : std_logic := '0';
  
begin
    -- Connect internal signal to output port
    o_pulse <= r_pulse_out;
    
    -- Pulse generation process
    pulse_gen : process(i_mclk)
    begin
        if rising_edge(i_mclk) then
            if i_reset = '1' then
                -- Reset counter and pulse
                r_count     <= 0;
                r_pulse_out <= '0';
            else
                -- Check if we've reached the terminal count
                if r_count = C_DIVISOR - 1 then
                    -- Generate single-cycle pulse and reset counter
                    r_pulse_out <= '1';
                    r_count     <= 0;
                else
                    -- Increment counter, no pulse
                    r_pulse_out <= '0';
                    r_count     <= r_count + 1;
                end if;
            end if;
        end if;
    end process pulse_gen;
	 
end Behavioral;