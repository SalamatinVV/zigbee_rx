function rx_shifted = add_phase_shift(rx, phase_deg)
    phi = deg2rad(phase_deg);
    rx_shifted = rx .* exp(1j * phi);   % поэлементно!
end
