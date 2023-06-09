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
        -- GPIO_1(0) : 先攻数字決定 => '1'
        -- GPIO_1(1) : 後攻数字決定 => '1'
        -- -- 先攻
        -- GPIO_1(2) : 予想数字送信周期 => '0'
        -- GPIO_1(6-3) : 予想数字送信 => expect_number
        -- GPIO_1(7) : EAT・BITE送信周期 => '0'
        -- GPIO_1(9-8) : EAT・BITE送信 => EAT or BITE
        -- -- 後攻
        -- GPIO_1(10) : 予想数字送信周期 => '0'
        -- GPIO_1(14-11) : 予想数字送信 => expect_number
        -- GPIO_1(15) : EAT・BITE送信周期 => '0'
        -- GPIO_1(17-16) : EAT・BITE送信 => EAT or BITE
        GPIO_1: inout std_logic_vector (35 downto 0);
        LEDR: out std_logic_vector (9 downto 0);
        HEX0, HEX1, HEX2, HEX3, HEX4, HEX5: out std_logic_vector(6 downto 0));
end numeron;

architecture rtl of numeron is
    constant cnt_max: std_logic_vector(31 downto 0):= X"0000000F";
    signal enable: std_logic := '0';
    signal clk_tx: std_logic;

    signal send_expect_cycle, send_eatbite_cycle, recv_expect_cycle, recv_eatbite_cycle : std_logic;
    signal send_expect_signal, recv_expect_signal : std_logic_vector(3 downto 0);
    signal send_eatbite_signal, recv_eatbite_signal : std_logic_vector(1 downto 0);

    signal clk, xrst: std_logic;
    -- 10 予想数字送信
    -- 20 EAT・BITE受信
    -- 30 予想数字受信
    -- 40 EAT・BITE送信
    type state_type is (s0, s1, s2, s10, s11, s12, s13, s14, s20, s21, s22, s23, s30, s31, s32, s40, s41, s42, s43, s50);
    type mem is array(0 to 2) of std_logic_vector(3 downto 0);
    signal state: state_type;
    signal button : std_logic_vector(3 downto 0);
    signal nSW: std_logic_vector(9 downto 0);
    signal mode1, mode2: std_logic_vector(1 downto 0);
    signal din: std_logic_vector(3 downto 0);
    signal view_led1, view_led2, view_led3, view_led4, view_led5 : std_logic_vector(3 downto 0);
    signal state_view_low, state_view_high : std_logic_vector(3 downto 0);
    signal buf : std_logic_vector(2 downto 0) := "000";

    -- 自分の数字
    signal set_my_flag : std_logic_vector(2 downto 0);
    signal my_address : integer  := 0;
    signal my_number : mem;

    -- 予想の数字
    signal set_expect_flag : std_logic_vector(2 downto 0);
    signal expect_address : integer := 0;
    signal expect_number : mem;

    --送受信
    signal send_num : integer;
    signal cnt1, cnt2 : std_logic_vector(31 downto 0);
    signal received_num : integer;
    signal send_eat, send_bite, receive_eat, receive_bite : std_logic;
    signal EAT, BITE, rcvEAT, rcvBITE : std_logic_vector(1 downto 0) := "00";

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
    component chattering_bt
        port(clk, xrst: in std_logic;  
             button   : in std_logic;
             no_chattering: out std_logic);
    end component;
    component chattering_sw
        port(clk, xrst: in std_logic;  
             button   : in std_logic;
             no_chattering: out std_logic);
    end component;
begin
    clk <= CLOCK_50;
    xrst <= RESET_N;

    -- 先攻
    -- GPIO_1(2) <= send_expect_cycle;
    -- GPIO_1(7) <= send_eatbite_cycle;
    -- GPIO_1(6 downto 3) <= send_expect_signal;
    -- GPIO_1(9 downto 8) <= send_eatbite_signal;
    -- recv_expect_cycle <= GPIO_1(10);
    -- recv_eatbite_cycle <= GPIO_1(15);
    -- recv_expect_signal <= GPIO_1(14 downto 11);
    -- recv_eatbite_signal <= GPIO_1(17 downto 16);

    -- 後攻
    GPIO_1(10) <= send_expect_cycle;
    GPIO_1(15) <= send_eatbite_cycle;
    GPIO_1(14 downto 11) <= send_expect_signal;
    GPIO_1(17 downto 16) <= send_eatbite_signal;
    recv_expect_cycle <= GPIO_1(2);
    recv_eatbite_cycle <= GPIO_1(7);
    recv_expect_signal <= GPIO_1(6 downto 3);
    recv_eatbite_signal <= GPIO_1(9 downto 8);

    cg: clock_gen generic map(N) port map(clk, xrst, enable, cnt_max, clk_tx);
    dec: dec_decoder port map(nSW(3 downto 0), din); -- 0 - 9 => そのまま，9以上 => 9を返す

    mode1 <= nSW(9 downto 8);
    mode2 <= nSW(7 downto 6);

    nochattering_bt : for i in 0 to 3 generate
        cs : chattering_bt port map(clk => clk, xrst => xrst, button => KEY(i), no_chattering => button(i)); -- not test
        -- button(i) <= not KEY(i); -- test case only 負論理を正論理に
    end generate nochattering_bt;

    nochattering_sw : for i in 0 to 9 generate
        cs : chattering_sw port map(clk => clk, xrst => xrst, button => SW(i), no_chattering => nSW(i)); -- not test
        -- nSW(i) <= SW(i); -- test case only
    end generate nochattering_sw;

    hex_0: seven_seg_decoder port map (clk, xrst, din, HEX0);
    hex_1: seven_seg_decoder port map (clk, xrst, view_led1, HEX1);
    hex_2: seven_seg_decoder port map (clk, xrst, view_led2, HEX2);
    hex_3: seven_seg_decoder port map (clk, xrst, view_led3, HEX3);
    hex_4: seven_seg_decoder port map (clk, xrst, view_led4, HEX4);
    hex_5: seven_seg_decoder port map (clk, xrst, view_led5, HEX5);
    
    view_led1 <= my_number(0)     when mode1 = "00" else
                 expect_number(0) when mode1 = "01" else
                 "00" & EAT       when mode1 = "10" else
                 "00" & rcvEAT    when mode1 = "11" else
                 "0000";
    view_led2 <= my_number(1)     when mode1 = "00" else
                 expect_number(1) when mode1 = "01" else
                 "00" & BITE      when mode1 = "10" else
                 "00" & rcvBITE   when mode1 = "11" else
                 "0000";
    view_led3 <= my_number(2)     when mode1 = "00" else
                 expect_number(2) when mode1 = "01" else
                 "0000";
    view_led4 <= conv_std_logic_vector(my_address, 4)     when mode2 = "00" else state_view_low;
    view_led5 <= conv_std_logic_vector(expect_address, 4) when mode2 = "00" else state_view_high;

    LEDR <= "1111111111" when state = s50 else GPIO_1(1) & GPIO_1(0) & "00" & set_expect_flag & set_my_flag;

    process(clk)
    begin
        if (clk'event and clk = '1') then
            case state is
                when s0 => 
                    state_view_high <= "0000";
                    state_view_low  <= "0000";
                when s1 => 
                    state_view_high <= "0000";
                    state_view_low  <= "0001";
                when s2 => 
                    state_view_high <= "0000";
                    state_view_low  <= "0010";
                when s10 => 
                    state_view_high <= "0001";
                    state_view_low  <= "0000";
                when s11 => 
                    state_view_high <= "0001";
                    state_view_low  <= "0001";
                when s12 => 
                    state_view_high <= "0001";
                    state_view_low  <= "0010";
                when s13 => 
                    state_view_high <= "0001";
                    state_view_low  <= "0011";
                when s14 => 
                    state_view_high <= "0001";
                    state_view_low  <= "0100";
                when s20 => 
                    state_view_high <= "0010";
                    state_view_low  <= "0000";
                when s21 => 
                    state_view_high <= "0010";
                    state_view_low  <= "0001";
                when s22 => 
                    state_view_high <= "0010";
                    state_view_low  <= "0010";
                when s23 => 
                    state_view_high <= "0010";
                    state_view_low  <= "0011";
                when s30 => 
                    state_view_high <= "0011";
                    state_view_low  <= "0000";
                when s31 => 
                    state_view_high <= "0011";
                    state_view_low  <= "0001";
                when s32 => 
                    state_view_high <= "0011";
                    state_view_low  <= "0010";
                when s40 => 
                    state_view_high <= "0100";
                    state_view_low  <= "0000";
                when s41 => 
                    state_view_high <= "0100";
                    state_view_low  <= "0001";
                when s42 => 
                    state_view_high <= "0100";
                    state_view_low  <= "0010";
                when s43 => 
                    state_view_high <= "0100";
                    state_view_low  <= "0011";
                when s50 => 
                    state_view_high <= "0101";
                    state_view_low  <= "0000";
            end case;
        end if;
    end process;

    -- 各状態の動作
    process(clk)
    begin
        if (clk'event and clk = '1') then
            case state is
                when s0 => -- 初期状態
                    -- GPIO_1(0) <= '0'; -- 先攻
                    GPIO_1(1) <= '0'; -- 後攻
                    send_expect_cycle  <= '1';
                    send_eatbite_cycle <= '1';
                    enable <= '0';
                    my_address <= 0;
                    set_my_flag <= "000";
                    expect_address <= 0;
                    set_expect_flag <= "000";
                    buf <= buf + 1;
                when s1 => -- 数字を選択
                    if (button(1) = '1') then
                        if (my_address = 2) then
                            my_address <= 0;
                        else
                            my_address <= my_address + 1;
                        end if;
                    elsif (button(2) = '1') then
                        if (my_address = 0) then
                            my_address <= 2;
                        else
                            my_address <= my_address - 1;
                        end if;
                    elsif (button(3) = '1') then
                        if (my_number(0) /= din and my_number(1) /= din and my_number(2) /= din) then
                            my_number(my_address) <= din;
                            if (my_address = 0) then
                                set_my_flag <= set_my_flag or "001";
                            elsif (my_address = 1) then
                                set_my_flag <= set_my_flag or "010";
                            elsif (my_address = 2) then
                                set_my_flag <= set_my_flag or "100";
                            end if;
                        end if;
                    end if;
                when s2 => -- 準備完了通知
                    -- GPIO_1(0) <= '1'; -- 先攻
                    GPIO_1(1) <= '1'; -- 後攻

                when s10 => -- 予想数字決定
                    if (button(1) = '1') then
                        if (expect_address = 2) then
                            expect_address <= 0;
                        else
                            expect_address <= expect_address + 1;
                        end if;
                    elsif (button(2) = '1') then
                        if (expect_address = 0) then
                            expect_address <= 2;
                        else
                            expect_address <= expect_address - 1;
                        end if;
                    elsif (button(3) = '1') then
                        if (expect_number(0) /= din and expect_number(1) /= din and expect_number(2) /= din) then
                            expect_number(expect_address) <= din;
                            if (expect_address = 0) then
                                set_expect_flag <= set_expect_flag or "001";
                            elsif (expect_address = 1) then
                                set_expect_flag <= set_expect_flag or "010";
                            elsif (expect_address = 2) then
                                set_expect_flag <= set_expect_flag or "100";
                            end if;
                        end if;
                    end if;
                when s11 => -- 予想数字送信準備
                    expect_address <= 0;
                    set_expect_flag <= "000";
                    send_num <= 0;
                    enable <= '1';
                    if (clk_tx = '1') then
                        send_expect_cycle <= '0';
                    end if;
                when s12 => -- 予想数字送信準備完了
                    if (clk_tx = '1') then
                        send_expect_cycle  <= '1';
                        send_expect_signal <= expect_number(0);
                        send_num <= send_num + 1;
                    end if;
                when s13 => -- 予想数字送信シークエンス
                    if (clk_tx = '1') then
                        send_expect_signal <= expect_number(send_num);
                        send_num <= send_num + 1;
                    end if;
                when s14 => -- 予想数字送信終了
                    enable <= '0';
                    expect_number(0) <= "0000";
                    expect_number(1) <= "0000";
                    expect_number(2) <= "0000";

                when s20 => -- EAT・BITE受信準備
                    cnt1 <= (others => '0');
                    cnt2 <= (others => '0');
                    receive_eat <= '0';
                    receive_bite <= '0';
                when s21 => -- EAT・BITE送信側周期測定
                    if (recv_eatbite_cycle /= '1') then
                        cnt1 <= cnt1 + 1;
                    end if;
                when s22 => -- EAT受信
                    if (cnt2 < cnt1) then
                        if (conv_integer(cnt2) = conv_integer(cnt1)/2) then
                            cnt2 <= cnt2 + 1;
                            rcvEAT <= recv_eatbite_signal;
                        else
                            cnt2 <= cnt2 + 1;
                        end if;
                    else
                        receive_eat <= '1';
                        cnt2 <= (others => '0');
                    end if;
                when s23 => -- BITE受信
                    if (cnt2 < cnt1) then
                        if (conv_integer(cnt2) = conv_integer(cnt1)/2) then
                            cnt2 <= cnt2 + 1;
                            rcvBITE <= recv_eatbite_signal;
                        else
                            cnt2 <= cnt2 + 1;
                        end if;
                    else
                        receive_bite <= '1';
                        cnt2 <= (others => '0');
                    end if;

                when s30 => -- 予想数字受信準備
                    cnt1 <= (others => '0');
                    cnt2 <= (others => '0');
                    EAT <= (others => '0');
                    BITE <= (others => '0');
                    received_num <= 0;
                when s31 => -- 予想数字送信側周期測定
                    if (recv_expect_cycle /= '1') then
                        cnt1 <= cnt1 + 1;
                    end if;
                when s32 => -- 予想数字からEAT・BITEを決定
                    if (cnt2 < cnt1) then
                        if (conv_integer(cnt2) = conv_integer(cnt1)/2) then
                            cnt2 <= cnt2 + 1;
                            if (my_number(received_num) = recv_expect_signal) then
                                EAT <= EAT + 1;
                            elsif (my_number(0) = recv_expect_signal or my_number(1) = recv_expect_signal or my_number(2) = recv_expect_signal) then
                                BITE <= BITE + 1;
                            end if;
                        else
                            cnt2 <= cnt2 + 1;
                        end if;
                    else
                        cnt2 <= (others => '0');
                        received_num <= received_num + 1;
                    end if;
                
                when s40 => -- EAT・BITE送信準備
                    send_eat <= '0';
                    send_bite <= '0';
                    enable <= '1';
                    if (clk_tx = '1') then
                        send_eatbite_cycle <= '0';
                    end if;
                when s41 => -- EAT送信
                    if (clk_tx = '1') then
                        send_eatbite_cycle <= '1';
                        send_eatbite_signal <= EAT;
                        send_eat <= '1';
                    end if;
                when s42 => -- BITE送信
                    if (clk_tx = '1') then
                        send_eatbite_signal <= BITE;
                        send_bite <= '1';
                    end if;
                when s43 => -- EAT・BITE送信完了
                    enable <= '0';

                when s50 => -- 終了
                    my_number(0) <= "0000";
                    my_number(1) <= "0000";
                    my_number(2) <= "0000";
                    EAT <= "00";
                    BITE <= "00";
                    rcvEAT <= "00";
                    rcvBITE <= "00";
                    buf <= "000";
            end case;
        end if;
    end process;

    -- 状態遷移
    process(xrst, clk)
    begin
        if (xrst = '0') then
            state <= s0;
        elsif (clk'event and clk = '1' and state = s0 and buf = "111") then
            state <= s1;
        elsif (clk'event and clk = '1' and state = s1 and button(0) = '1' and set_my_flag = "111") then
            state <= s2;
        elsif (clk'event and clk = '1' and state = s2 and GPIO_1(0) = '1' and GPIO_1(1) = '1') then
            -- state <= s10; -- 先攻
            state <= s30; -- 後攻
        
        elsif (clk'event and clk = '1' and state = s10 and button(0) = '1' and set_expect_flag = "111") then
            state <= s11;
        elsif (clk'event and clk = '1' and state = s11 and send_expect_cycle = '0') then
            state <= s12;
        elsif (clk'event and clk = '1' and state = s12 and send_num = 1) then
            state <= s13;
        elsif (clk'event and clk = '1' and state = s13 and send_num = 3) then
            state <= s14;
        elsif (clk'event and clk = '1' and state = s14 and enable = '0') then 
            state <= s20;

        elsif (clk'event and clk = '1' and state = s20 and recv_eatbite_cycle /= '1') then
            state <= s21;
        elsif (clk'event and clk = '1' and state = s21 and recv_eatbite_cycle = '1') then
            state <= s22;
        elsif (clk'event and clk = '1' and state = s22 and receive_eat = '1') then
            state <= s23;
        elsif (clk'event and clk = '1' and state = s23 and receive_bite = '1' and rcvEAT = "11") then
            state <= s50;
        elsif (clk'event and clk = '1' and state = s23 and receive_bite = '1') then
            state <= s30;
        
        elsif (clk'event and clk = '1' and state = s30 and recv_expect_cycle /= '1') then
            state <= s31;
        elsif (clk'event and clk = '1' and state = s31 and recv_expect_cycle = '1') then
            state <= s32;
        elsif (clk'event and clk = '1' and state = s32 and received_num = 3) then
            state <= s40;

        elsif (clk'event and clk = '1' and state = s40 and send_eatbite_cycle = '0') then
            state <= s41;
        elsif (clk'event and clk = '1' and state = s41 and send_eat = '1') then
            state <= s42;
        elsif (clk'event and clk = '1' and state = s42 and send_bite = '1') then
            state <= s43;
        elsif (clk'event and clk = '1' and state = s43 and enable = '0' and EAT = "11") then
            state <= s50;
        elsif (clk'event and clk = '1' and state = s43 and enable = '0') then
            state <= s10;

        elsif (clk'event and clk = '1' and state = s50 and button(0) = '1') then
            state <= s0;
        end if;
    end process;

end rtl;

