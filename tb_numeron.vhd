library ieee;
library modelsim_lib;
use ieee.std_logic_1164.all;
use modelsim_lib.util.all;

entity tb_numeron is
  generic(K: integer := 4;
          W: integer := 2);
end tb_numeron;

architecture testbench of tb_numeron is
  type mem is array(0 to (2**W)-1) of std_logic_vector(K-1 downto 0);
  type test_vec_t is record
    key: std_logic_vector (3 downto 0);
    sw: std_logic_vector (9 downto 0);
  end record;
  type test_vec_array_t is array(natural range <>) of test_vec_t;
  constant input_table1: test_vec_array_t :=
    (("0111", "0000000001"),
     ("1111", "0000000001"),
     ("0111", "0000000011"),
     ("1101", "0000000011"),
     ("0111", "0000000111"),
     ("1101", "0000000111"),
     ("0111", "0000001111"),
     ("1101", "0000001111"),
     ("0111", "0000001111"),
     ("1110", "0000001111"));
  constant input_table2: test_vec_array_t :=
    (("1111", "0100000000"),
     ("1011", "0100000001"),
     ("0111", "0100000001"),
     ("1011", "0100000010"),
     ("0111", "0100000010"),
     ("1011", "0100000011"),
     ("0111", "0100000011"),
     ("1011", "0100000100"),
     ("0111", "0100000100"),
     ("1011", "0100000101"),
     ("0111", "0100000101"),
     ("1011", "0100000110"),
     ("0111", "0100000110"),
     ("1011", "0100000111"),
     ("0111", "0100000111"),
     ("1011", "0100001000"),
     ("0111", "0100001000"),
     ("1111", "0000000000"));
  constant period1: time := 20 ns;
  constant period2: time := 20 ns;
  signal clk1, clk2: std_logic := '0';
  signal xrst1, xrst2: std_logic;
  signal key1, key2: std_logic_vector(3 downto 0);
  signal sw1, sw2: std_logic_vector(9 downto 0);
  signal gpio: std_logic_vector (35 downto 0);
  signal tx_ram, rx_ram: mem;
  component numeron is
    port(
      CLOCK_50, RESET_N: in std_logic;
      KEY: in std_logic_vector(3 downto 0);
      SW: in std_logic_vector(9 downto 0);
      GPIO_1: inout std_logic_vector (35 downto 0);
      LEDR: out std_logic_vector (9 downto 0);
      HEX0, HEX1, HEX2, HEX3, HEX4, HEX5: out std_logic_vector(6 downto 0));
  end component;
begin

  clock1: process
  begin
    wait for period1*0.25;
    clk1 <= not clk1;
    wait for period1*0.25;
  end process;

  clock2: process
  begin
    wait for period2*0.4;
    clk2 <= not clk2;
    wait for period2*0.1;
  end process;

  stim1: process
  begin
    xrst1 <= '1';
    key1 <= (others => '1');
    sw1 <= (others => '0');
    wait for period1*2;
    xrst1 <= '0';
    wait for period1;
    xrst1 <= '1';
    wait for period1*5;
    for i in input_table1'range loop
      key1 <= input_table1(i).key;
      sw1 <= input_table1(i).sw;
      wait for period1;
    end loop;
    wait;
  end process;

  -- stim2: process
  -- begin
  --   xrst2 <= '1';
  --   key2 <= (others => '1');
  --   sw2 <= (others => '0');
  --   wait for period2/2;
  --   wait for period2*3;
  --   xrst2 <= '0';
  --   wait for period2;
  --   xrst2 <= '1';
  --   wait for period2*5;
  --   for i in input_table2'range loop
  --     key <= input_table(i).key;
  --     sw <= input_table(i).sw;
  --     wait for period2;
  --   end loop;
  --   wait;
  -- end process;

  -- check: process
  -- begin
  --   init_signal_spy("tb_txrx/tx1/ram/ram_block","/tx_ram",1);
  --   init_signal_spy("tb_txrx/rx1/ram/ram_block","/rx_ram",1);
  --   wait until key(0) = '0' and gpio(5) = '1';
  --   wait for period2;
  --   wait until gpio(5) = '0';
  --   wait for period2;
  --   wait until gpio(5) = '1';
  --   assert (tx_ram = rx_ram) report "Received data is different from transferred data!" severity failure;
  --   wait for period2*100;
  --   assert (false) report "Simulation successfully completed!" severity failure;
  -- end process;

  numeron1: numeron port map(CLOCK_50 => clk1,
                             RESET_N => xrst1,
                             KEY => key1,
                             SW => sw1,
                             GPIO_1 => gpio,
                             LEDR => open,
                             HEX0 => open,
                             HEX1 => open,
                             HEX2 => open,
                             HEX3 => open,
                             HEX4 => open,
                             HEX5 => open);

  -- numeron2: numeron port map(CLOCK_50 => clk2,
  --                            RESET_N => xrst2,
  --                            KEY => key2,
  --                            SW => sw2,
  --                            GPIO_1 => gpio,
  --                            LEDR => open,
  --                            HEX0 => open,
  --                            HEX1 => open,
  --                            HEX2 => open,
  --                            HEX3 => open,
  --                            HEX4 => open,
  --                            HEX5 => open);

end testbench;

