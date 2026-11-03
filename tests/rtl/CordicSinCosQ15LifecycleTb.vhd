library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.livt_lang_icontext_package.all;
use work.livt_math_trigonometry_cordicsincosq15_package.all;

-- Measure public-call latency and exercise reset, overlap, retention, and recovery.

entity cordic_sin_cos_q15_lifecycle_tb is
end;

architecture test of cordic_sin_cos_q15_lifecycle_tb is
    signal ctx : t_icontext_in := (
        '0', '1', to_unsigned(100000000, 32), to_unsigned(10, 32),
        to_unsigned(5, 32), to_unsigned(5, 32));
    signal compute_request : t_cordicsincosq15_compute_in := (to_signed(0, 32), '0');
    signal compute_response : t_cordicsincosq15_compute_out;
    signal sine_request : t_cordicsincosq15_getsin_in := (run => '0');
    signal sine_response : t_cordicsincosq15_getsin_out;
    signal cosine_request : t_cordicsincosq15_getcos_in := (run => '0');
    signal cosine_response : t_cordicsincosq15_getcos_out;
begin
    ctx.clk <= not ctx.clk after 5 ns;

    dut : entity work.livt_math_trigonometry_cordicsincosq15
        port map (
            ctor_lvt_context_in => ctx,
            compute_in => compute_request,
            compute_out => compute_response,
            getsin_in => sine_request,
            getsin_out => sine_response,
            getcos_in => cosine_request,
            getcos_out => cosine_response);

    process
        procedure tick is
        begin
            wait until rising_edge(ctx.clk);
            wait for 1 ns;
        end;

        procedure read_results(
            expected_sine : integer;
            expected_cosine : integer;
            tolerance : natural := 4) is
            variable difference : integer;
        begin
            sine_request.run <= '1';
            tick;
            assert sine_response.busy = '1' report "sine read not accepted" severity failure;
            sine_request.run <= '0';
            while sine_response.busy = '1' loop
                tick;
            end loop;

            cosine_request.run <= '1';
            tick;
            assert cosine_response.busy = '1' report "cosine read not accepted" severity failure;
            cosine_request.run <= '0';
            while cosine_response.busy = '1' loop
                tick;
            end loop;

            difference := abs(to_integer(sine_response.return_value) - expected_sine);
            assert difference <= tolerance report "sine result outside tolerance" severity failure;
            difference := abs(to_integer(cosine_response.return_value) - expected_cosine);
            assert difference <= tolerance report "cosine result outside tolerance" severity failure;
        end;

        procedure run_compute(
            phase : integer;
            expected_success : boolean;
            expected_sine : integer;
            expected_cosine : integer;
            variable cycles : out natural) is
        begin
            compute_request.phase <= to_signed(phase, 32);
            compute_request.run <= '1';
            tick;
            assert compute_response.busy = '1' report "compute request not accepted" severity failure;
            compute_request.run <= '0';
            cycles := 0;

            while compute_response.busy = '1' loop
                tick;
                cycles := cycles + 1;
                assert cycles < 100 report "compute timeout" severity failure;
            end loop;

            assert compute_response.return_value = expected_success report "unexpected compute status" severity failure;
            read_results(expected_sine, expected_cosine);
        end;

        variable reference_cycles, measured_cycles : natural;
    begin
        tick;
        tick;
        ctx.rst <= '0';
        tick;

        run_compute(0, true, 0, 32767, reference_cycles);
        assert reference_cycles = 32 report "valid public-call latency changed" severity failure;
        report "CORDIC valid public-call latency: " & integer'image(reference_cycles) & " cycles";

        run_compute(8192, true, 23170, 23170, measured_cycles);
        assert measured_cycles = reference_cycles report "quadrant-one latency differs" severity failure;
        run_compute(24576, true, 23170, -23170, measured_cycles);
        assert measured_cycles = reference_cycles report "quadrant-two latency differs" severity failure;
        run_compute(-24576, true, -23170, -23170, measured_cycles);
        assert measured_cycles = reference_cycles report "negative-quadrant latency differs" severity failure;

        run_compute(32768, false, 0, 0, measured_cycles);
        assert measured_cycles = 14 report "invalid public-call latency changed" severity failure;
        report "CORDIC invalid public-call latency: " & integer'image(measured_cycles) & " cycles";

        -- A one-cycle request pulse while busy is not accepted or replayed.
        compute_request.phase <= to_signed(8192, 32);
        compute_request.run <= '1';
        tick;
        compute_request.run <= '0';
        for cycle in 1 to 8 loop
            tick;
        end loop;
        compute_request.phase <= to_signed(0, 32);
        compute_request.run <= '1';
        tick;
        compute_request.run <= '0';
        while compute_response.busy = '1' loop
            tick;
        end loop;
        assert compute_response.return_value report "original overlapped call failed" severity failure;
        read_results(23170, 23170);
        for cycle in 1 to 10 loop
            tick;
            assert compute_response.busy = '0' report "overlapped request was replayed" severity failure;
        end loop;

        -- Reset in the iterative region cancels the call and clears observations.
        compute_request.phase <= to_signed(12345, 32);
        compute_request.run <= '1';
        tick;
        compute_request.run <= '0';
        for cycle in 1 to 12 loop
            tick;
        end loop;
        assert compute_response.busy = '1' report "compute finished before reset point" severity failure;
        ctx.rst <= '1';
        tick;
        assert compute_response.busy = '0' and not compute_response.return_value
            report "reset did not cancel compute" severity failure;
        ctx.rst <= '0';
        tick;
        read_results(0, 0, 0);

        run_compute(-8192, true, -23170, 23170, measured_cycles);
        assert measured_cycles = reference_cycles report "post-reset latency differs" severity failure;

        -- The next request is accepted on the first clock after completion.
        compute_request.phase <= to_signed(0, 32);
        compute_request.run <= '1';
        tick;
        compute_request.run <= '0';
        while compute_response.busy = '1' loop
            tick;
        end loop;
        compute_request.phase <= to_signed(8192, 32);
        compute_request.run <= '1';
        tick;
        assert compute_response.busy = '1' report "next request not accepted immediately" severity failure;
        compute_request.run <= '0';
        while compute_response.busy = '1' loop
            tick;
        end loop;
        read_results(23170, 23170);
        report "CORDIC minimum acceptance interval: 33 cycles";
        report "PASS CORDIC lifecycle, fixed latency, overlap rejection, reset, and recovery";
        stop;
    end process;

    process
    begin
        wait for 50 us;
        assert false report "watchdog" severity failure;
    end process;
end;
