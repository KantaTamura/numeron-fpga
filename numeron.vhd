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

    signal clk, xrst: std_logic;
    --10 予想の数字決定
    --20 送信
    --30 受信
    type state_type is (s0, s1, s2, s10, s11);
    type mem is array(0 to 2) of std_logic_vector(3 downto 0);
    subtype mem_range is integer range 0 to 2;
    signal state: state_type;
    signal button : std_logic_vector(3 downto 0);
    signal nSW: std_logic_vector(9 downto 0);
    signal mode: std_logic_vector(1 downto 0);
    signal din: std_logic_vector(3 downto 0);

    -- 自分の数字
    signal set_my_flag : std_logic_vector(2 downto 0);
    signal my_address : mem_range;
    signal my_number : mem;

    -- 予想の数字
    signal set_expect_flag : std_logic_vector(2 downto 0);
    signal expect_address : mem_range;
    signal expect_number : mem;

    --送受信
    signal cnt1, cnt2 : std_logic_vector(31 downto 0);
    signal received_num : integer;
    -- ヌメロン関連
    
    
    --予想数字の格納用
    signal ram_block1 : mem;
    signal BITE, EAT : std_logic_vector(1 downto 0) := "00"; --相手の予想に対する自分の
    -- 表示用
    signal display, displayradr, displaywadr : std_logic_vector(3 downto 0);
    signal displaybite, displayeat : std_logic_vector(3 downto 0);

    component clock_gen
        generic(N: integer);
        port(clk, xrst: in  std_logic;
             enable   : in  std_logic;
             cnt_max  : in  std_logic_vector (N-1 downto 0);
             clk_tx   : out std_logic);
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
                    GPIO_1(0) <= '0'; -- 先攻
                    GPIO_1(1) <= '0'; -- 後攻
                    my_address <= 0;
                    set_my_flag <= "000";
                when s1 => -- 数字を選択
                    if (button(1) = '1') then
                        my_address <= my_address + 1;
                    elsif (button(2) = '1') then
                        my_address <= my_address - 1;
                    elsif (button(3) = '1') then
                        my_number(my_address) <= din;
                        
                        if (my_address = 0) then
                            set_my_flag <= set_my_flag or "001";
                        elsif (my_address = 1) then
                            set_my_flag <= set_my_flag or "010";
                        elsif (my_address = 2) then
                            set_my_flag <= set_my_flag or "100";
                        end if;
                    end if;
                when s2 => -- 準備完了通知
                    GPIO_1(0) <= '1'; -- 先攻
                    -- GPIO_1(1) <= '1'; -- 後攻
                when s10 => -- 予想数字決定
                    if (button(1) = '1') then
                        expect_address <= expect_address + 1;
                    elsif (button(2) = '1') then
                        expect_address <= expect_address - 1;
                    elsif (button(3) = '1') then
                        expect_number(expect_address) <= din;
                        if (expect_address = 0) then
                            set_expect_flag <= set_expect_flag or "001";
                        elsif (expect_address = 1) then
                            set_expect_flag <= set_expect_flag or "010";
                        elsif (expect_address = 2) then
                            set_expect_flag <= set_expect_flag or "100";
                        end if;
                    end if;
                when s11 => -- 送信準備
                    
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
        elsif (clk'event and clk = '1' and state = s1 and button(0) = '1' and set_my_flag = "111") then
            state <= s2;
        elsif (clk'event and clk = '1' and state = s2 and GPIO_1(0) = '1' and GPIO_1(1) = '1') then
            state <= s10;
        elsif (clk'event and clk = '1' and state = s10 and button(0) = '1' and set_expect_flag = "111") then
            state <= s11;
        end if;
    end process;

end rtl;

