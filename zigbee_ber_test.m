function results = zigbee_ber_test()

    % ----------------- Параметры PHY -----------------
    Fs   = 8e6;
    Rb   = 250e3;
    Rsym = Rb/4;
    chipsPerSym = 32;
    Rchip = Rsym * chipsPerSym;
    L = Fs / Rchip;
    L = round(L);

    n = 0:L-1;
    pulse = sin(pi*n/(L-1));
    halfChipShift = round(L/2);

    % DSSS-таблица (как у тебя везде)
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

    % ----------------- SNR и итерации -----------------
    SNRrange   = 20:-2:-10;  % dB
    Niters     = 200;        % пакетов на точку
    payload_len = 10;        % байт (как у тебя в примере)

    results = struct([]);

    for si = 1:length(SNRrange)
        SNRdB = SNRrange(si);

        crc_ok_cnt = 0;
        total_pkts = 0;
        bit_errors_total = 0;
        bit_total        = 0;

        for it = 1:Niters

            % ---- 1. Генерируем полезную нагрузку ----
            payload = randi([0 255], 1, payload_len, 'uint8');  % 1xN

            % ---- 2. TX: PHY-формирование ----
            tx = zigbee_phy_transmit(payload);   % твоя функция TX

            % ---- 3. AWGN ----
            rx_noisy = add_awgn(tx, SNRdB);

            % ---- 4. Однопакетный приёмник ----
            pkt = zigbee_rx_one(rx_noisy, Fs, dsss_table, L, pulse, halfChipShift);

            total_pkts = total_pkts + 1;

            % Если не смогли извлечь PSDU — считаем пакет как ошибочный
            if isempty(pkt.psdu_no_fcs)
                continue;
            end

            if pkt.crc_ok
                crc_ok_cnt = crc_ok_cnt + 1;
            end

            % ---- 5. Сравнение payload по битам ----
            bits_ref = bytes2bits(payload);                 % эталон
            bits_rx  = bytes2bits(pkt.psdu_no_fcs(:).');    % принятые

            N = min(length(bits_ref), length(bits_rx));
            bit_errors_total = bit_errors_total + sum(bits_ref(1:N) ~= bits_rx(1:N));
            bit_total        = bit_total + N;
        end

        % ---- 6. Сохраняем результат по SNR ----
        results(si).SNRdB = SNRdB;

        if total_pkts > 0
            results(si).CRC_OK = crc_ok_cnt / total_pkts;    % Packet Success Rate
            results(si).PER    = 1 - results(si).CRC_OK;     % Packet Error Rate
        else
            results(si).CRC_OK = 0;
            results(si).PER    = 1;
        end

        if bit_total > 0
            results(si).BER = bit_errors_total / bit_total;
        else
            results(si).BER = 1;
        end

        fprintf("SNR = %3d dB → PSR = %.3f, PER = %.3f, BER = %.6f\n", ...
            SNRdB, results(si).CRC_OK, results(si).PER, results(si).BER);
    end

    % ---- 7. Графики ----
    figure; 
    semilogy([results.SNRdB], [results.BER], '-o','LineWidth',1.5);
    grid on; xlabel('SNR, dB'); ylabel('BER');
    title(sprintf('BER vs SNR (Niters = %d)', Niters));

    figure;
    plot([results.SNRdB], [results.PER], '-o','LineWidth',1.5);
    grid on; xlabel('SNR, dB'); ylabel('PER');
    title(sprintf('PER vs SNR (Niters = %d)', Niters));

end
