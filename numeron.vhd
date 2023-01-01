library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity numeron is
    generic(N: integer := 32;
            K: integer := 4;
            W: integer := 2);
    port(
        CLOCK_50, RESET_N: in std_logic;
        KEY: in std_logic_vector(3 downto 0);
        SW: in std_logic_vector(9 downto 0);
        GPIO_1: inout std_logic_vector (35 downto 0);
        LEDR: out std_logic_vector (9 downto 0);
        HEX0, HEX1, HEX2, HEX3, HEX4, HEX5: out std_logic_vector(6 downto 0));
end numeron;

architecture rtl of numeron is
    constant cnt_max: std_logic_vector(31 downto 0):= X"0000000F";
    signal enable: std_logic := '0';
    signal clk_tx: std_logic;
    signal we: std_logic := '0';
    signal wadr, radr: std_logic_vector (1 downto 0) := "00";
    signal din, dout : std_logic_vector (3 downto 0);

    signal clk, xrst: std_logic;
    type state_type is (s0, s1, s2);
    signal state: state_type;
    signal button : std_logic_vector(3 downto 0);
    signal nSW: std_logic_vector(9 downto 0);
    signal mode: std_logic_vector(1 downto 0);
    signal set_number_flag : std_logic_vector(2 downto 0);
    component clock_gen
        generic(N: integer);
        port(clk, xrst: in  std_logic;
             enable   : in  std_logic;
             cnt_max  : in  std_logic_vector (N-1 downto 0);
             clk_tx   : out std_logic);
    end component;
    component ram_WxK
        generic(K: integer;
                W: integer);
        port(clk : in  std_logic;
             din : in  std_logic_vector (K-1 downto 0);
             wadr: in  std_logic_vector (W-1 downto 0);
             radr: in  std_logic_vector (W-1 downto 0);
             we  : in  std_logic;
             dout: out std_logic_vector (K-1 downto 0));
    end component;
    component seven_seg_decoder is
        port(clk : in  std_logic;
             xrst: in  std_logic;
             din : in  std_logic_vector(3 downto 0);
             dout: out std_logic_vector(6 downto 0));
    end component;
    component dec_decoder is
        port(q  : in  std_logic_vector(3 downto 0);
             ans: out std_logic_vector(3 downto 0));
    end component;
    -- component chattering_bt
    --     port(clk, xrst: in std_logic;  
    --          button   : in std_logic;
    --          no_chattering: out std_logic);
    -- end component;
    -- component chattering_sw
    --     port(clk, xrst: in std_logic;  
    --          button   : in std_logic;
    --          no_chattering: out std_logic);
    -- end component;
begin
    clk <= CLOCK_50;
    xrst <= RESET_N;

    cg: clock_gen generic map(N) port map(clk, xrst, enable, cnt_max, clk_tx);
    ram: ram_WxK generic map(K, W) port map(clk, din, wadr, radr, we, dout);
    dec: dec_decoder port map(nSW(3 downto 0), din); -- 0 - 9 => そのまま，9以上 => 9を返す

    mode <= nSW(9 downto 8);

    nochattering_bt : for i in 0 to 3 generate
        -- cs : chattering_bt port map(clk => clk, xrst => xrst, button => KEY(i), no_chattering => button(i)); -- not test
        button(i) <= not KEY(i); -- test case only 負論理を正論理に
    end generate nochattering_bt;

    nochattering_sw : for i in 0 to 9 generate
        -- cs : chattering_sw port map(clk => clk, xrst => xrst, button => SW(i), no_chattering => nSW(i)); -- not test
        nSW(i) <= SW(i); -- test case only
    end generate nochattering_sw;

    -- 各状態の動作
    process(clk)
    begin
        if (clk'event and clk = '1') then
            case state is
                when s0 => -- 初期状態
                    GPIO_1(0) <= '0';
                    wadr <= "00";
                    set_number_flag <= "000";
                when s1 => -- 数字を選択
                    if (button(1) = '1') then
                        we <= '0';
                        wadr <= "00" when wadr = "10" else wadr + 1;
                    elsif (button(2) = '1') then
                        we <= '0';
                        wadr <= "10" when wadr = "00" else wadr - 1;
                    elsif (button(3) = '1') then
                        we <= '1';
                        if (wadr = "00") then
                            set_number_flag <= set_number_flag or "001";
                        elsif (wadr = "01") then
                            set_number_flag <= set_number_flag or "010";
                        elsif (wadr = "10") then
                            set_number_flag <= set_number_flag or "100";
                        end if;
                    else
                        we <= '0';
                    end if;
                when s2 => -- 準備完了通知
                    GPIO_1(0) <= '1';
            end case;
        end if;
    end process;

    -- 状態遷移
    process(xrst, clk)
    begin
        if (xrst = '0') then
            state <= s0;
        elsif (clk'event and clk = '1' and state = s0) then
            state <= s1;
        elsif (clk'event and clk = '1' and state = s1 and button(0) = '1' and set_number_flag = "111") then
            state <= s2;
        end if;
    end process;

end rtl;

