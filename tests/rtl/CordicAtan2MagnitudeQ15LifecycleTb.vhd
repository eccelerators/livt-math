library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
use work.livt_lang_icontext_package.all;
use work.livt_math_trigonometry_cordicatan2magnitudeq15_package.all;

entity cordic_atan2_magnitude_q15_lifecycle_tb is
end;

architecture test of cordic_atan2_magnitude_q15_lifecycle_tb is
    signal ctx : t_icontext_in := (
        '0', '1', to_unsigned(100000000, 32), to_unsigned(10, 32),
        to_unsigned(5, 32), to_unsigned(5, 32));
    signal compute_request : t_cordicatan2magnitudeq15_compute_in := (
        to_signed(0, 32), to_signed(0, 32), '0');
    signal compute_response : t_cordicatan2magnitudeq15_compute_out;
    signal phase_request : t_cordicatan2magnitudeq15_getphase_in := (run => '0');
    signal phase_response : t_cordicatan2magnitudeq15_getphase_out;
    signal magnitude_request : t_cordicatan2magnitudeq15_getmagnitude_in := (run => '0');
    signal magnitude_response : t_cordicatan2magnitudeq15_getmagnitude_out;
begin
    ctx.clk <= not ctx.clk after 5 ns;

    dut : entity work.livt_math_trigonometry_cordicatan2magnitudeq15
        port map (
            ctor_lvt_context_in => ctx,
            compute_in => compute_request,
            compute_out => compute_response,
            getphase_in => phase_request,
            getphase_out => phase_response,
            getmagnitude_in => magnitude_request,
            getmagnitude_out => magnitude_response);

    process
        procedure tick is
        begin
            wait until rising_edge(ctx.clk);
            wait for 1 ns;
        end;

        procedure read_results(
            expected_phase : integer;
            expected_magnitude : natural;
            tolerance : natural := 4) is
        begin
            phase_request.run <= '1';
            tick;
            phase_request.run <= '0';
            while phase_response.busy = '1' loop
                tick;
            end loop;

            magnitude_request.run <= '1';
            tick;
            magnitude_request.run <= '0';
            while magnitude_response.busy = '1' loop
                tick;
            end loop;

            assert abs(to_integer(phase_response.return_value) - expected_phase) <= tolerance
                report "phase result outside tolerance" severity failure;
            assert abs(to_integer(magnitude_response.return_value) - expected_magnitude) <= tolerance
                report "magnitude result outside tolerance" severity failure;
        end;

        procedure run_compute(
            x_value : integer;
            y_value : integer;
            expected_success : boolean;
            expected_phase : integer;
            expected_magnitude : natural;
            variable cycles : out natural) is
        begin
            compute_request.x <= to_signed(x_value, 32);
            compute_request.y <= to_signed(y_value, 32);
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
            assert compute_response.return_value = expected_success
                report "unexpected compute status" severity failure;
            read_results(expected_phase, expected_magnitude);
        end;

        variable reference_cycles, measured_cycles : natural;
    begin
        tick;
        tick;
        ctx.rst <= '0';
        tick;

        run_compute(1, 2, true, 11548, 2, reference_cycles);
        assert reference_cycles = 68 report "valid public-call latency changed" severity failure;
        report "vectoring valid public-call latency: "
            & integer'image(reference_cycles) & " cycles";
        run_compute(32767, 32767, true, 8192, 46340, measured_cycles);
        assert measured_cycles = reference_cycles report "valid latency changed by input" severity failure;

        run_compute(0, 0, false, 0, 0, measured_cycles);
        assert measured_cycles = 14 report "invalid public-call latency changed" severity failure;
        report "vectoring invalid public-call latency: "
            & integer'image(measured_cycles) & " cycles";

        compute_request.x <= to_signed(12345, 32);
        compute_request.y <= to_signed(-23456, 32);
        compute_request.run <= '1';
        tick;
        compute_request.run <= '0';
        for cycle in 1 to 20 loop
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

        run_compute(-1, 2, true, 21220, 2, measured_cycles);
        assert measured_cycles = reference_cycles report "post-reset latency differs" severity failure;
        report "PASS vectoring lifecycle, fixed latency, reset, and recovery";
        stop;
    end process;

    process
    begin
        wait for 50 us;
        assert false report "watchdog" severity failure;
    end process;
end;
