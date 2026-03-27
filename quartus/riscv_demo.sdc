create_clock -name clk50 -period 20.000 [get_ports {CLOCK}]
derive_pll_clocks
derive_clock_uncertainty
