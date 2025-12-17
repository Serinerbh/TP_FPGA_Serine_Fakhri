library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hdmi_controler is
    port (
        i_clk          : in  std_logic;  -- horloge pixel (27 MHz)
        i_rst_n        : in  std_logic;  -- reset actif bas

        -- sorties HDMI
        o_hdmi_tx_clk  : out std_logic;
        o_hdmi_tx_de   : out std_logic;
        o_hdmi_tx_hs   : out std_logic;
        o_hdmi_tx_vs   : out std_logic;

        -- signaux utiles
        o_pixel_en     : out std_logic;
        o_pixel_address: out std_logic_vector(18 downto 0);

        -- compteurs pixel
        s_x_counter    : out unsigned(9 downto 0);
        s_y_counter    : out unsigned(9 downto 0)
    );
end entity;

architecture rtl of hdmi_controler is

    -- paramètres VGA 640x480 @ 60 Hz
    constant H_VISIBLE : integer := 640;
    constant H_FRONT   : integer := 16;
    constant H_SYNC    : integer := 96;
    constant H_BACK    : integer := 48;
    constant H_TOTAL   : integer := H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    constant V_VISIBLE : integer := 480;
    constant V_FRONT   : integer := 10;
    constant V_SYNC    : integer := 2;
    constant V_BACK    : integer := 33;
    constant V_TOTAL   : integer := V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    -- compteurs
    signal h_count      : unsigned(9 downto 0) := (others => '0');
    signal v_count      : unsigned(9 downto 0) := (others => '0');

    -- signal interne pour DE (zone visible)
    signal s_hdmi_tx_de : std_logic;

begin

    -- horloge HDMI
    o_hdmi_tx_clk <= i_clk;

    -- génération des compteurs
    process(i_clk, i_rst_n)
    begin
        if i_rst_n = '0' then
            h_count <= (others => '0');
            v_count <= (others => '0');
        elsif rising_edge(i_clk) then
            if h_count = to_unsigned(H_TOTAL-1, h_count'length) then
                h_count <= (others => '0');
                if v_count = to_unsigned(V_TOTAL-1, v_count'length) then
                    v_count <= (others => '0');
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;
        end if;
    end process;

    -- signaux de synchronisation (actifs bas)
    o_hdmi_tx_hs <= '0' when (h_count >= to_unsigned(H_VISIBLE+H_FRONT, h_count'length) and
                              h_count <  to_unsigned(H_VISIBLE+H_FRONT+H_SYNC, h_count'length))
                    else '1';

    o_hdmi_tx_vs <= '0' when (v_count >= to_unsigned(V_VISIBLE+V_FRONT, v_count'length) and
                              v_count <  to_unsigned(V_VISIBLE+V_FRONT+V_SYNC, v_count'length))
                    else '1';

    -- zone visible -> signal interne
    s_hdmi_tx_de <= '1' when (h_count < to_unsigned(H_VISIBLE, h_count'length) and
                              v_count < to_unsigned(V_VISIBLE, v_count'length))
                    else '0';

    -- pixel enable et DE en sortie
    o_pixel_en   <= s_hdmi_tx_de;
    o_hdmi_tx_de <= s_hdmi_tx_de;

    o_pixel_address <= std_logic_vector(to_unsigned(to_integer(v_count) * H_VISIBLE + to_integer(h_count), 19)
    );

    -- sorties compteurs
    s_x_counter <= h_count;
    s_y_counter <= v_count;

end architecture;
