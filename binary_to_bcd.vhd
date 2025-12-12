library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity binary_to_bcd is
    port (
        i_binary   : in  std_logic_vector(9 downto 0);    -- signed 10-bit input
        o_sign     : out std_logic;                        -- sign output: '1' if negative
        o_hundreds : out std_logic_vector(3 downto 0);    -- hundreds place (0-5)
        o_tens     : out std_logic_vector(3 downto 0);    -- tens place (0-9)
        o_ones     : out std_logic_vector(3 downto 0)     -- ones place (0-9)
    );
end binary_to_bcd;

architecture Behavioral of binary_to_bcd is
begin

    binToBCD: process(i_binary)
        variable temp_signed_val : signed(9 downto 0);
        variable magnitude       : unsigned(9 downto 0);
        variable shift_reg       : unsigned(21 downto 0);
        variable i               : integer;
    begin
        -- Convert input to signed type
        temp_signed_val := signed(i_binary);
        
        -- Determine sign and calculate magnitude
        if temp_signed_val < 0 then
            o_sign <= '1';
            magnitude := unsigned(-temp_signed_val);
        else
            o_sign <= '0';
            magnitude := unsigned(temp_signed_val);
        end if;
        
        -- Initialize shift register with magnitude in lower bits
        shift_reg := (others => '0');
        shift_reg(9 downto 0) := magnitude;
        
        -- Perform shift-and-add-3 algorithm for 10 bits
        for i in 0 to 9 loop
            -- Add 3 to ones digit if value is 5 or greater
            if shift_reg(13 downto 10) >= 5 then
                shift_reg(13 downto 10) := shift_reg(13 downto 10) + 3;
            end if;
            
            -- Add 3 to tens digit if value is 5 or greater
            if shift_reg(17 downto 14) >= 5 then
                shift_reg(17 downto 14) := shift_reg(17 downto 14) + 3;
            end if;
            
            -- Add 3 to hundreds digit if value is 5 or greater
            if shift_reg(21 downto 18) >= 5 then
                shift_reg(21 downto 18) := shift_reg(21 downto 18) + 3;
            end if;
            
            -- Perform left shift by one position
            shift_reg := shift_reg(20 downto 0) & '0';
        end loop;
        
        -- Assign BCD outputs from shift register
        o_ones     <= std_logic_vector(shift_reg(13 downto 10));
        o_tens     <= std_logic_vector(shift_reg(17 downto 14));
        o_hundreds <= std_logic_vector(shift_reg(21 downto 18));
        
    end process binToBCD;

end Behavioral;