library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_icontext_package.all;

entity livt_math_arithmetic_checkedblockmacprimitive is
    port (
        ctor_lvt_context_in : in t_icontext_in;
        ctor_abits, ctor_bbits, ctor_accumulatorbits, ctor_productstages : in signed(31 downto 0);
        ctor_request : in std_logic;
        ctor_operation, ctor_index : in signed(31 downto 0);
        ctor_values : in std_logic_vector(511 downto 0);
        ctor_scalar : in signed(31 downto 0);
        ctor_seed : in std_logic_vector(63 downto 0);
        ctor_acknowledge : out std_logic;
        ctor_result : out std_logic_vector(64 downto 0)
    );
end;

architecture rtl of livt_math_arithmetic_checkedblockmacprimitive is
    constant ERROR_RESULT : std_logic_vector(64 downto 0) := (64 => '1', others => '0');
    type phase_t is (idle, loading, clearing, precomputing, computing, reading);
    type words_t is array (0 to 31) of signed(31 downto 0);
    type sums_t is array (0 to 31) of signed(63 downto 0);
    type tags_t is array (0 to 2) of natural range 0 to 31;
    type bases_t is array (0 to 2) of signed(63 downto 0);
    signal phase : phase_t := idle;
    signal left_words : words_t;
    signal sums : sums_t;
    attribute ram_style : string;
    attribute ram_style of sums : signal is "block";
    -- RAM contents need no reset: validity makes all sums logically zero.
    signal sums_valid : std_logic_vector(31 downto 0) := (others => '0');
    signal read_address, write_address : natural range 0 to 31 := 0;
    signal read_value, ram_read_value, forwarded_value, write_value : signed(63 downto 0);
    signal forwarded : boolean := false;
    signal read_valid, write_enable : boolean := false;
    signal loaded : std_logic_vector(1 downto 0) := "00";
    signal poisoned, failed, weighted : boolean := false;
    signal pending : std_logic := '0';
    signal scalar, operand_a, operand_b : signed(31 downto 0);
    signal product, delayed_product, total : signed(63 downto 0);
    signal low_product : signed(48 downto 0);
    signal high_product : signed(47 downto 0);
    signal valid, bad : std_logic_vector(2 downto 0) := "000";
    signal tags : tags_t;
    signal bases : bases_t;
    signal cursor : natural range 0 to 32 := 0;
    signal block_base : natural range 0 to 16 := 0;

    function fits(value : signed; bits : integer) return boolean is
    begin
        if bits < 2 or bits > value'length then
            return false;
        end if;
        -- Static loop bounds also synthesize when the configured width is a port.
        for i in value'range loop
            if i >= bits - 1 and value(i) /= value(value'high) then
                return false;
            end if;
        end loop;
        return true;
    end;
begin
    -- Read one lane ahead while computing. The precompute phase primes lane zero.
    process(all)
        variable idx : integer;
    begin
        read_address <= block_base;
        if phase = idle then
            idx := to_integer(ctor_index);
            if idx >= 0 and idx < 32 then read_address <= idx; end if;
        elsif phase = computing then
            if cursor < 15 then
                read_address <= block_base + cursor + 1;
            else
                read_address <= block_base + 15;
            end if;
        end if;
    end process;

    read_value <= forwarded_value when forwarded else ram_read_value;

    -- One synchronous read and one write port infer a block RAM. Forwarding
    -- preserves immediate read-after-write across command boundaries.
    process(ctor_lvt_context_in.clk)
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            if write_enable then sums(write_address) <= write_value; end if;
            ram_read_value <= sums(read_address);
            forwarded <= write_enable and write_address = read_address;
            forwarded_value <= write_value;
            read_valid <= sums_valid(read_address) = '1';
            if write_enable and write_address = read_address then
                read_valid <= true;
            end if;
        end if;
    end process;

    process(ctor_lvt_context_in.clk)
        variable op, idx, a_bits, b_bits, acc_bits, stages : integer;
        variable selected : natural range 1 to 2;
        variable lane_bad, failed_now : boolean;
        variable lane_value : signed(31 downto 0);
        variable selected_product, base : signed(63 downto 0);
        variable added : signed(64 downto 0);
    begin
        if rising_edge(ctor_lvt_context_in.clk) then
            write_enable <= false;
            if ctor_lvt_context_in.rst = '1' then
                phase <= idle;
                loaded <= "00";
                sums_valid <= (others => '0');
                poisoned <= false;
                failed <= false;
                weighted <= false;
                pending <= '0';
                valid <= "000";
                bad <= "000";
                cursor <= 0;
                block_base <= 0;
                ctor_acknowledge <= '0';
                ctor_result <= (others => '0');
            else
                a_bits := to_integer(ctor_abits);
                b_bits := to_integer(ctor_bbits);
                acc_bits := to_integer(ctor_accumulatorbits);
                stages := to_integer(ctor_productstages);

                case phase is
                    when loading =>
                        lane_value := signed(ctor_values((cursor + 1) * 32 - 1 downto cursor * 32));
                        failed_now := failed or not fits(lane_value, a_bits);
                        left_words(block_base + cursor) <= lane_value;
                        failed <= failed_now;
                        if cursor = 15 then
                            loaded(block_base / 16) <= '0';
                            ctor_result <= ERROR_RESULT;
                            if not failed_now then
                                loaded(block_base / 16) <= '1';
                                ctor_result <= (others => '0');
                            end if;
                            ctor_acknowledge <= pending;
                            phase <= idle;
                        else
                            cursor <= cursor + 1;
                        end if;

                    when clearing =>
                        write_enable <= true;
                        write_address <= cursor;
                        write_value <= (others => '0');
                        sums_valid(cursor) <= '1';
                        if cursor = 31 then
                            poisoned <= false;
                            ctor_result <= (others => '0');
                            ctor_acknowledge <= pending;
                            phase <= idle;
                        else
                            cursor <= cursor + 1;
                        end if;

                    when precomputing =>
                        phase <= computing;

                    when reading =>
                        ctor_result <= (others => '0');
                        if read_valid then ctor_result <= '0' & std_logic_vector(read_value); end if;
                        ctor_acknowledge <= pending;
                        phase <= idle;

                    when computing =>
                        valid <= valid(1 downto 0) & '0';
                        bad <= bad(1 downto 0) & '0';
                        tags(1) <= tags(0);
                        tags(2) <= tags(1);
                        bases(1) <= bases(0);
                        bases(2) <= bases(1);
                        if valid(0) = '1' then
                            if stages = 1 then
                                product <= operand_a * operand_b;
                            else
                                -- Split the signed multiplier before the registered join.
                                low_product <= operand_a * signed('0' & std_logic_vector(operand_b(15 downto 0)));
                                high_product <= operand_a * operand_b(31 downto 16);
                            end if;
                        end if;
                        if valid(1) = '1' and stages = 2 then
                            delayed_product <= resize(low_product, 64) + shift_left(resize(high_product, 64), 16);
                        end if;
                        selected := 1;
                        selected_product := product;
                        if stages = 2 then
                            selected := 2;
                            selected_product := delayed_product;
                        end if;

                        if valid(selected) = '1' then
                            base := total;
                            if weighted then
                                base := bases(selected);
                            end if;
                            added := resize(base, 65) + resize(selected_product, 65);
                            failed_now := failed or bad(selected) = '1' or not fits(added, acc_bits);
                            failed <= failed_now;
                            -- Keep the wide data registers independent of the overflow
                            -- decision. Failure is sticky, failed results are zero, and
                            -- a failed weighted bank is unreadable until clear/reset.
                            -- Internal values after failure are therefore unobservable.
                            if weighted then
                                write_enable <= true;
                                write_address <= tags(selected);
                                write_value <= resize(added, 64);
                                sums_valid(tags(selected)) <= '1';
                            else
                                total <= resize(added, 64);
                            end if;
                            if tags(selected) = block_base + 15 then
                                ctor_result <= (others => '0');
                                if failed_now then
                                    ctor_result <= ERROR_RESULT;
                                    if weighted then
                                        poisoned <= true;
                                    end if;
                                elsif not weighted then
                                    ctor_result <= '0' & std_logic_vector(resize(added, 64));
                                end if;
                                ctor_acknowledge <= pending;
                                valid <= "000";
                                phase <= idle;
                            end if;
                        end if;

                        if cursor < 16 then
                            lane_value := signed(ctor_values((cursor + 1) * 32 - 1 downto cursor * 32));
                            operand_b <= lane_value;
                            lane_bad := not fits(lane_value, b_bits);
                            operand_a <= left_words(block_base + cursor);
                            if weighted then
                                operand_a <= scalar;
                            end if;
                            bases(0) <= (others => '0');
                            if read_valid then bases(0) <= read_value; end if;
                            tags(0) <= block_base + cursor;
                            bad(0) <= '0';
                            if lane_bad then
                                bad(0) <= '1';
                            end if;
                            valid(0) <= '1';
                            cursor <= cursor + 1;
                        end if;

                    when idle =>
                        if ctor_request /= ctor_acknowledge then
                            op := to_integer(ctor_operation);
                            idx := to_integer(ctor_index);
                            pending <= ctor_request;
                            failed <= false;
                            valid <= "000";
                            bad <= "000";
                            cursor <= 0;
                            if a_bits < 2 or a_bits > 32 or b_bits < 2 or b_bits > 32 or
                               acc_bits < 2 or acc_bits > 64 or (stages /= 1 and stages /= 2) then
                                ctor_result <= ERROR_RESULT;
                                ctor_acknowledge <= ctor_request;
                                if op = 3 then poisoned <= true; end if;
                            elsif op = 2 then
                                phase <= clearing;
                            elsif op = 4 then
                                if idx >= 0 and idx < 32 and not poisoned then
                                    if sums_valid(idx) = '0' then
                                        ctor_result <= (others => '0');
                                        ctor_acknowledge <= ctor_request;
                                    else
                                        phase <= reading;
                                    end if;
                                else
                                    ctor_result <= ERROR_RESULT;
                                    ctor_acknowledge <= ctor_request;
                                end if;
                            elsif (op = 0 or op = 1 or op = 3) and idx >= 0 and idx < 2 then
                                block_base <= idx * 16;
                                if op = 0 then
                                    loaded(idx) <= '0';
                                    phase <= loading;
                                elsif op = 1 then
                                    if loaded(idx) = '1' and fits(signed(ctor_seed), acc_bits) then
                                        total <= signed(ctor_seed);
                                        weighted <= false;
                                        phase <= precomputing;
                                    else
                                        ctor_result <= ERROR_RESULT;
                                        ctor_acknowledge <= ctor_request;
                                    end if;
                                elsif not poisoned and fits(ctor_scalar, a_bits) then
                                    scalar <= ctor_scalar;
                                    weighted <= true;
                                    phase <= precomputing;
                                else
                                    poisoned <= true;
                                    ctor_result <= ERROR_RESULT;
                                    ctor_acknowledge <= ctor_request;
                                end if;
                            else
                                if op = 3 then poisoned <= true; end if;
                                ctor_result <= ERROR_RESULT;
                                ctor_acknowledge <= ctor_request;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;
end;
