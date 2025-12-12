----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    
-- Design Name: 
-- Module Name:    BCDto7Segment - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: BCD to 7-segment decoder with sign handling
--              Converts BCD digits (0-9) to 7-segment display codes
--              Handles sign digit to show minus symbol for negative numbers
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

entity BCDto7Segment is
    port (
        i_digit_sel : in  std_logic_vector(1 downto 0);  -- Which digit is active (0-3)
        i_sign      : in  std_logic;                      -- Sign bit: '1' = negative
        i_hundreds  : in  std_logic_vector(3 downto 0);   -- Hundreds BCD digit
        i_tens      : in  std_logic_vector(3 downto 0);   -- Tens BCD digit
        i_ones      : in  std_logic_vector(3 downto 0);   -- Ones BCD digit
        o_segments  : out std_logic_vector(6 downto 0)    -- 7-segment output (active low)
    );
end BCDto7Segment;

architecture Behavioral of BCDto7Segment is
    signal current_bcd : std_logic_vector(3 downto 0);
    signal display_minus : std_logic;
begin

    -- Select which BCD digit to display based on digit_sel
    digit_mux: process(i_digit_sel, i_sign, i_hundreds, i_tens, i_ones)
    begin
        display_minus <= '0';
        case i_digit_sel is
            when "00" =>
                -- Rightmost digit: ones place
                current_bcd <= i_ones;
            when "01" =>
                -- Second digit: tens place
                current_bcd <= i_tens;
            when "10" =>
                -- Third digit: hundreds place
                current_bcd <= i_hundreds;
            when "11" =>
                -- Leftmost digit: sign position
                current_bcd <= "1111";  -- Blank by default
                display_minus <= i_sign;
            when others =>
                current_bcd <= "1111";
        end case;
    end process digit_mux;

    -- BCD to 7-segment decoder (active low outputs)
    -- Segment order: gfedcba (bit 6 = g, bit 0 = a)
    decode: process(i_digit_sel, current_bcd, display_minus)
    begin
        if i_digit_sel = "11" then
            -- Handle sign position
            if display_minus = '1' then
                o_segments <= "0111111";  -- Minus sign (only segment g on)
            else
                o_segments <= "1111111";  -- Blank (all segments off)
            end if;
        else
            -- Decode BCD digit to 7-segment
            case current_bcd is
                when "0000" => o_segments <= "1000000";  -- 0
                when "0001" => o_segments <= "1111001";  -- 1
                when "0010" => o_segments <= "0100100";  -- 2
                when "0011" => o_segments <= "0110000";  -- 3
                when "0100" => o_segments <= "0011001";  -- 4
                when "0101" => o_segments <= "0010010";  -- 5
                when "0110" => o_segments <= "0000010";  -- 6
                when "0111" => o_segments <= "1111000";  -- 7
                when "1000" => o_segments <= "0000000";  -- 8
                when "1001" => o_segments <= "0010000";  -- 9
                when others => o_segments <= "1111111";  -- Blank for invalid
            end case;
        end if;
    end process decode;

end Behavioral;