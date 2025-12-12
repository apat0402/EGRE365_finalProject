library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity phase1_fsm is
    port (
        i_clk           : in  std_logic;                      -- system clock
        i_rstb          : in  std_logic;                      -- active-low reset
        i_start         : in  std_logic;                      -- start pulse
        i_tx_end        : in  std_logic;                      -- SPI transaction complete
        i_rx_data       : in  std_logic_vector(15 downto 0);  -- data from SPI

        o_tx_start      : out std_logic;                      -- start SPI transaction
        o_tx_data       : out std_logic_vector(15 downto 0);  -- SPI command/data

        o_x_axis_data   : out std_logic_vector(15 downto 0);
        o_y_axis_data   : out std_logic_vector(15 downto 0);
        o_z_axis_data   : out std_logic_vector(15 downto 0)
    );
end phase1_fsm;

architecture rtl of phase1_fsm is

    --------------------------------------------------------------------
    -- FSM STATES (explicit sequencing)
    --------------------------------------------------------------------
    type t_state is (
        ST_IDLE,

        ST_WRITE_BW_LOAD,  ST_WRITE_BW_START,  ST_WRITE_BW_WAIT,
        ST_WRITE_PWR_LOAD, ST_WRITE_PWR_START, ST_WRITE_PWR_WAIT,

        ST_READ_X0_LOAD,   ST_READ_X0_START,   ST_READ_X0_WAIT,
        ST_READ_X1_LOAD,   ST_READ_X1_START,   ST_READ_X1_WAIT,

        ST_READ_Y0_LOAD,   ST_READ_Y0_START,   ST_READ_Y0_WAIT,
        ST_READ_Y1_LOAD,   ST_READ_Y1_START,   ST_READ_Y1_WAIT,

        ST_READ_Z0_LOAD,   ST_READ_Z0_START,   ST_READ_Z0_WAIT,
        ST_READ_Z1_LOAD,   ST_READ_Z1_START,   ST_READ_Z1_WAIT,

        ST_DONE
    );

    --------------------------------------------------------------------
    -- SPI COMMAND ARRAY (organizational only)
    --------------------------------------------------------------------
    type t_cmd_array is array (0 to 7) of std_logic_vector(15 downto 0);
    constant C_CMD_ARRAY : t_cmd_array := (
        0 => X"2C08",  -- BW_RATE
        1 => X"2D08",  -- POWER_CTL
        2 => X"B200",  -- DATAX0
        3 => X"B300",  -- DATAX1
        4 => X"B400",  -- DATAY0
        5 => X"B500",  -- DATAY1
        6 => X"B600",  -- DATAZ0
        7 => X"B700"   -- DATAZ1
    );

    --------------------------------------------------------------------
    -- INTERNAL SIGNALS
    --------------------------------------------------------------------
    signal r_state      : t_state := ST_IDLE;
    signal w_next_state : t_state;

    -- start edge detection
    signal r_start_d1   : std_logic := '0';
    signal r_start_d2   : std_logic := '0';
    signal w_start_rise : std_logic;

    -- temporary LSB storage
    signal r_x_lsb      : std_logic_vector(7 downto 0) := (others => '0');
    signal r_y_lsb      : std_logic_vector(7 downto 0) := (others => '0');
    signal r_z_lsb      : std_logic_vector(7 downto 0) := (others => '0');

    -- output registers
    signal r_x_axis     : std_logic_vector(15 downto 0) := (others => '0');
    signal r_y_axis     : std_logic_vector(15 downto 0) := (others => '0');
    signal r_z_axis     : std_logic_vector(15 downto 0) := (others => '0');

begin

    -- output connections
    o_x_axis_data <= r_x_axis;
    o_y_axis_data <= r_y_axis;
    o_z_axis_data <= r_z_axis;

    --------------------------------------------------------------------
    -- CLOCKED PROCESS
    --------------------------------------------------------------------
    process(i_clk, i_rstb)
    begin
        if i_rstb = '0' then
            r_state    <= ST_IDLE;
            r_start_d1 <= '0';
            r_start_d2 <= '0';

            r_x_lsb    <= (others => '0');
            r_y_lsb    <= (others => '0');
            r_z_lsb    <= (others => '0');

            r_x_axis   <= (others => '0');
            r_y_axis   <= (others => '0');
            r_z_axis   <= (others => '0');

        elsif rising_edge(i_clk) then
            r_state    <= w_next_state;
            r_start_d1 <= i_start;
            r_start_d2 <= r_start_d1;

            -- capture data only when SPI transaction completes
            if (r_state = ST_READ_X0_WAIT) and (i_tx_end = '1') then
                r_x_lsb <= i_rx_data(7 downto 0);

            elsif (r_state = ST_READ_X1_WAIT) and (i_tx_end = '1') then
                r_x_axis <= i_rx_data(7 downto 0) & r_x_lsb;

            elsif (r_state = ST_READ_Y0_WAIT) and (i_tx_end = '1') then
                r_y_lsb <= i_rx_data(7 downto 0);

            elsif (r_state = ST_READ_Y1_WAIT) and (i_tx_end = '1') then
                r_y_axis <= i_rx_data(7 downto 0) & r_y_lsb;

            elsif (r_state = ST_READ_Z0_WAIT) and (i_tx_end = '1') then
                r_z_lsb <= i_rx_data(7 downto 0);

            elsif (r_state = ST_READ_Z1_WAIT) and (i_tx_end = '1') then
                r_z_axis <= i_rx_data(7 downto 0) & r_z_lsb;
            end if;
        end if;
    end process;

    w_start_rise <= r_start_d1 and not r_start_d2;

    --------------------------------------------------------------------
    -- NEXT STATE LOGIC
    --------------------------------------------------------------------
    process(r_state, w_start_rise, i_tx_end)
    begin
        case r_state is

            when ST_IDLE =>
                if w_start_rise = '1' then
                    w_next_state <= ST_WRITE_BW_LOAD;
                else
                    w_next_state <= ST_IDLE;
                end if;

            when ST_WRITE_BW_LOAD  => w_next_state <= ST_WRITE_BW_START;
            when ST_WRITE_BW_START => w_next_state <= ST_WRITE_BW_WAIT;
            when ST_WRITE_BW_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_WRITE_PWR_LOAD;
                else
                    w_next_state <= ST_WRITE_BW_WAIT;
                end if;

            when ST_WRITE_PWR_LOAD  => w_next_state <= ST_WRITE_PWR_START;
            when ST_WRITE_PWR_START => w_next_state <= ST_WRITE_PWR_WAIT;
            when ST_WRITE_PWR_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_READ_X0_LOAD;
                else
                    w_next_state <= ST_WRITE_PWR_WAIT;
                end if;

            when ST_READ_X0_LOAD  => w_next_state <= ST_READ_X0_START;
            when ST_READ_X0_START => w_next_state <= ST_READ_X0_WAIT;
            when ST_READ_X0_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_READ_X1_LOAD;
                else
                    w_next_state <= ST_READ_X0_WAIT;
                end if;

            when ST_READ_X1_LOAD  => w_next_state <= ST_READ_X1_START;
            when ST_READ_X1_START => w_next_state <= ST_READ_X1_WAIT;
            when ST_READ_X1_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_READ_Y0_LOAD;
                else
                    w_next_state <= ST_READ_X1_WAIT;
                end if;

            when ST_READ_Y0_LOAD  => w_next_state <= ST_READ_Y0_START;
            when ST_READ_Y0_START => w_next_state <= ST_READ_Y0_WAIT;
            when ST_READ_Y0_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_READ_Y1_LOAD;
                else
                    w_next_state <= ST_READ_Y0_WAIT;
                end if;

            when ST_READ_Y1_LOAD  => w_next_state <= ST_READ_Y1_START;
            when ST_READ_Y1_START => w_next_state <= ST_READ_Y1_WAIT;
            when ST_READ_Y1_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_READ_Z0_LOAD;
                else
                    w_next_state <= ST_READ_Y1_WAIT;
                end if;

            when ST_READ_Z0_LOAD  => w_next_state <= ST_READ_Z0_START;
            when ST_READ_Z0_START => w_next_state <= ST_READ_Z0_WAIT;
            when ST_READ_Z0_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_READ_Z1_LOAD;
                else
                    w_next_state <= ST_READ_Z0_WAIT;
                end if;

            when ST_READ_Z1_LOAD  => w_next_state <= ST_READ_Z1_START;
            when ST_READ_Z1_START => w_next_state <= ST_READ_Z1_WAIT;
            when ST_READ_Z1_WAIT  =>
                if i_tx_end = '1' then
                    w_next_state <= ST_DONE;
                else
                    w_next_state <= ST_READ_Z1_WAIT;
                end if;

            when ST_DONE =>
                w_next_state <= ST_IDLE;

            when others =>
                w_next_state <= ST_IDLE;

        end case;
    end process;

    --------------------------------------------------------------------
    -- OUTPUT LOGIC
    --------------------------------------------------------------------
    process(r_state)
    begin
        o_tx_start <= '0';
        o_tx_data  <= (others => '0');

        case r_state is
            when ST_WRITE_BW_LOAD | ST_WRITE_BW_START | ST_WRITE_BW_WAIT =>
                o_tx_data <= C_CMD_ARRAY(0);

            when ST_WRITE_PWR_LOAD | ST_WRITE_PWR_START | ST_WRITE_PWR_WAIT =>
                o_tx_data <= C_CMD_ARRAY(1);

            when ST_READ_X0_LOAD | ST_READ_X0_START | ST_READ_X0_WAIT =>
                o_tx_data <= C_CMD_ARRAY(2);

            when ST_READ_X1_LOAD | ST_READ_X1_START | ST_READ_X1_WAIT =>
                o_tx_data <= C_CMD_ARRAY(3);

            when ST_READ_Y0_LOAD | ST_READ_Y0_START | ST_READ_Y0_WAIT =>
                o_tx_data <= C_CMD_ARRAY(4);

            when ST_READ_Y1_LOAD | ST_READ_Y1_START | ST_READ_Y1_WAIT =>
                o_tx_data <= C_CMD_ARRAY(5);

            when ST_READ_Z0_LOAD | ST_READ_Z0_START | ST_READ_Z0_WAIT =>
                o_tx_data <= C_CMD_ARRAY(6);

            when ST_READ_Z1_LOAD | ST_READ_Z1_START | ST_READ_Z1_WAIT =>
                o_tx_data <= C_CMD_ARRAY(7);

            when others =>
                null;
        end case;

        if r_state = ST_WRITE_BW_START or
           r_state = ST_WRITE_PWR_START or
           r_state = ST_READ_X0_START or
           r_state = ST_READ_X1_START or
           r_state = ST_READ_Y0_START or
           r_state = ST_READ_Y1_START or
           r_state = ST_READ_Z0_START or
           r_state = ST_READ_Z1_START then
            o_tx_start <= '1';
        end if;
    end process;

end rtl;
