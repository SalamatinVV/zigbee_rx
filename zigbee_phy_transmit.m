function tx = zigbee_phy_transmit(psdu_no_fcs)

    %% ---- Параметры PHY ----
    Rb   = 250e3;
    Rsym = Rb/4;
    chipsPerSym = 32;
    Rchip = Rsym * chipsPerSym;       % 2 Mchips/s

    Fs = 8e6;                         % должна совпадать с RX
    L = Fs / Rchip;                   % Samples per chip
    L = round(L);

    %% ---- CRC-16 KERMIT ----
    crc = crc16_kermit(psdu_no_fcs);
    fcs = uint8([bitand(crc,255), bitshift(crc,-8)]);

    psdu = [psdu_no_fcs(:).'  fcs];   % добавляем FCS

    %% ---- Формируем PHY: преамбула + SFD + PHR ----
    preamble = uint8([0 0 0 0]);
    sfd = uint8(167);                 % 0xA7
    phr = uint8(length(psdu));

    phy = [preamble sfd phr psdu];

    %% ---- Байты → биты (LSB-first) ----
    bits = zeros(1, 8*length(phy));
    for k = 1:length(phy)
        b = phy(k);
        for j = 1:8
            bits(8*(k-1)+j) = bitget(b, j); % LSB-first
        end
    end

    %% ---- Биты → символы ----
    nSymbols = length(bits)/4;
    bits_4 = reshape(bits,4,[]);
    symVals = bits_4.' * [1;2;4;8];

    %% ---- DSSS таблица ----
    dsss_table_bits = [
        1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0;
        1 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1;
        0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0;
        0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1;
        0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0 0 0 1 1;
        0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1 1 1 0 0;
        1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1 1 0 0 1;
        1 0 0 1 1 1 0 0 0 0 1 1 0 1 0 1 0 0 1 0 0 0 1 0 1 1 1 0 1 1 0 1;
        1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1;
        1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1;
        0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1;
        0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0;
        0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1 0 1 1 0;
        0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0 1 0 0 1;
        1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0 1 1 0 0;
        1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 0 0 1 1 1 0 1 1 1 1 0 1 1 1 0 0 0];
    dsss_table = 2*dsss_table_bits - 1;

    %% ---- Расширение DSSS ----
    chips = [];
    for s = symVals.'
        chips = [chips  dsss_table(s+1, :)];
    end

    %% ---- OQPSK half-sine ----
    Ichips = chips(1:2:end);
    Qchips = chips(2:2:end);

    n = 0:L-1;
    pulse = sin(pi*n/(L-1));

    Iup = kron(Ichips, pulse);
    Qup = kron(Qchips, pulse);

    % !! ТОЧНО КАК В PYTHON !!
    Qup = circshift(Qup, L/2);

    tx = Iup + 1j*Qup;
end
