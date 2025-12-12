----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    
-- Design Name: 
-- Module Name:    DisplayMultiplexer - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Display multiplexer for 7-segment displays
--              Cycles through 4 digits with refresh timing
--              Controls anode enables for digit selection
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

entity DisplayMultiplexer is
    port (
        i_clk        : in  std_logic;                      -- 100 MHz system clock
        i_reset      : in  std_logic;                      -- Reset (active low)
        o_digit_sel  : out std_logic_vector(1 downto 0);   -- Current digit selector
        o_anodes     : out std_logic_vector(7 downto 0);   -- Anode outputs (active low)
        o_dp         : out std_logic                       -- Decimal point (active low)
    );
end DisplayMultiplexer;

architecture Behavioral of DisplayMultiplexer is
    -- Refresh rate divider: 100 MHz / 100000 = 1 kHz per digit
    constant REFRESH_DIVISOR : integer := 100000;
    
    signal refresh_count : integer range 0 to REFRESH_DIVISOR - 1 := 0;
    signal refresh_enable : std_logic := '0';
    signal current_digit : unsigned(1 downto 0) := "00";

begin

    -- Output current digit selector
    o_digit_sel <= std_logic_vector(current_digit);
    
    -- Decimal point always off
    o_dp <= '1';

    -- Clock divider to generate refresh timing
    refresh_timer: process(i_clk, i_reset)
    begin
        if i_reset = '0' then
            refresh_count <= 0;
            refresh_enable <= '0';
        elsif rising_edge(i_clk) then
            if refresh_count = REFRESH_DIVISOR - 1 then
                refresh_count <= 0;
                refresh_enable <= '1';
            else
                refresh_count <= refresh_count + 1;
                refresh_enable <= '0';
            end if;
        end if;
    end process refresh_timer;

    -- Digit selector counter
    digit_counter: process(i_clk, i_reset)
    begin
        if i_reset = '0' then
            current_digit <= "00";
        elsif rising_edge(i_clk) then
            if refresh_enable = '1' then
                current_digit <= current_digit + 1;
            end if;
        end if;
    end process digit_counter;

    -- Anode control (active low, only enable 4 rightmost digits)
    anode_control: process(current_digit)
    begin
        case current_digit is
            when "00" =>
                o_anodes <= "11111110";  -- Enable AN0 (rightmost - ones)
            when "01" =>
                o_anodes <= "11111101";  -- Enable AN1 (tens)
            when "10" =>
                o_anodes <= "11111011";  -- Enable AN2 (hundreds)
            when "11" =>
                o_anodes <= "11110111";  -- Enable AN3 (sign position)
            when others =>
                o_anodes <= "11111111";  -- All off
        end case;
    end process anode_control;

end Behavioral;