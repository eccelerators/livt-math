library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.livt_lang_icontext_package.all;
use work.livt_math_arithmetic_iintegerdivision_g_unsignedinteger_sig_809b61f6ff02_package.all;

-- Exercise cancellation during a real iteration, then a fresh request.

entity integer_division_reset_tb is
    generic (ASYNC_RESET : boolean := false);
end;

architecture test of integer_division_reset_tb is
    signal ctx : t_icontext_in := ('0', '1', to_unsigned(100000000, 32), to_unsigned(10, 32), to_unsigned(5, 32), to_unsigned(5, 32));
    signal request : t_iintegerdivision_g_unsignedinteger_sig_809b61f6ff02_compute_in := (to_unsigned(2147483647, 32), to_unsigned(3, 32), '0');
    signal response : t_iintegerdivision_g_unsignedinteger_sig_809b61f6ff02_compute_out;
    signal divide_request : t_iintegerdivision_g_unsignedinteger_sig_809b61f6ff02_divide_in := (to_unsigned(100, 32), to_unsigned(7, 32), '0');
    signal divide_response : t_iintegerdivision_g_unsignedinteger_sig_809b61f6ff02_divide_out;
begin
    ctx.clk <= not ctx.clk after 5 ns;
    dut : entity work.livt_math_arithmetic_unsigneddivision_g_32_sig_db0f7854530e
        generic map (LVT_RESET_ASYNC => ASYNC_RESET)
        port map (
    ctor_lvt_context_in => ctx,
    compute_in => request, compute_out => response,
    divide_in => divide_request, divide_out => divide_response,
    getquotient_in => (run => '0'), getquotient_out => open,
    getremainder_in => (run => '0'), getremainder_out => open,
    remainder_in => ((others => '0'), (others => '0'), '0'), remainder_out => open,
    moduloeuclidean_in => ((others => '0'), (others => '0'), '0'), moduloeuclidean_out => open,
    failed_in => (run => '0'), failed_out => open);

    process
    begin
        wait for 30 ns;
        ctx.rst <= '0';
        wait for 20 ns;
        request.run <= '1';
        wait until response.busy = '1' for 1 us;
        assert response.busy = '1' report "request not accepted" severity failure;
        request.run <= '0';
        wait for 200 ns;
        assert response.busy = '1' report "division completed before serial bit steps" severity failure;
        ctx.rst <= '1';
        wait for 30 ns;
        assert response.busy = '0' and not response.return_value report "reset did not cancel compute" severity failure;
        ctx.rst <= '0';
        wait for 50 ns;
        divide_request.run <= '1';
        wait until divide_response.busy = '1' for 1 us;
        assert divide_response.busy = '1' report "fresh request not accepted" severity failure;
        divide_request.run <= '0';
        wait until divide_response.busy = '0' for 20 us;
        assert divide_response.busy = '0' and divide_response.return_value = to_unsigned(14, 32)
        report "post-reset division incorrect or timed out" severity failure;
        report "PASS division reset cancellation and recovery";
        stop;
    end process;

    process
    begin
        wait for 25 us;
        assert false report "watchdog" severity failure;
    end process;
end;
