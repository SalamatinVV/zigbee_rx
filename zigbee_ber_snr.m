function results = zigbee_ber_snr()
% zigbee_ber_snr
%   Строит BER–SNR кривую для твоего Python-сигнала zigbee_phy_baseband.txt
%   Использует твой собственный алгоритм приёма (из скрипта выше),
%   только вынесенный в функцию zigbee_rx_one.

    clc; close all;

    %% --- Параметры PHY ---
    Rb   = 250e3;
    Rsym = Rb/4;
    chipsPerSym = 32;
    Rchip = Rsym * chipsPerSym;   % 2 Mchips/s

    Fs   = 8e6;
    L    = Fs / Rchip;
    if abs(L - round(L)) > 1e-9
        error('Fs / Rchip не целое, Fs должен быть кратным 2 МГц');
    end
    L = round(L);
    halfChipShift = round(L/2);

    % half-sine импульс (как у тебя)
    n = 0:L-1;
    pulse = sin(pi*n/(L-1));
    pulse = pulse(:).';  % строка

    % DSSS-таблица (один-в-один как в твоём скрипте)
    dsss_table_bits = zigbee_dsss_table_bits();
    dsss_table = 2*dsss_table_bits - 1;

    %% --- Загружаем исходный чистый сигнал от Python ---
    data = load("zigbee_phy_baseband.txt");   % [N x 2]
    tx = data(:,1) + 1j*data(:,2);
    tx = tx / rms(tx);

    %% --- Эталонный PSDU payload (как в Python) ---
    % psdu_payload = [0x61, 0x88, 0x00, 0xCD, 0xAB, 0x34, 0x12, 0x01, 0x02, 0x03]
    true_payload = uint8([0x61 0x88 0x00 0xCD 0xAB 0x34 0x12 0x01 0x02 0x03]);
    Nbits_payload = numel(true_payload)*8;

    %% --- SNR и число итераций ---
    SNRdB_vec = 20:-2:-10;
    Niters = 200;               % можно увеличить до 1000

    BER = zeros(size(SNRdB_vec));

    %% --- Monte-Carlo цикл по SNR ---
    for isnr = 1:numel(SNRdB_vec)
        SNRdB = SNRdB_vec(isnr);

        err_bits_sum = 0;
        bits_sum     = 0;

        for it = 1:Niters
            % --- добавляем шум к исходному tx ---
            sigP = mean(abs(tx).^2);
            SNRlin = 10^(SNRdB/10);
            noiseP = sigP / SNRlin;

            noise = sqrt(noiseP/2) * (randn(size(tx)) + 1j*randn(size(tx)));
            rx_noisy = tx + noise;

            % --- приём одного пакета ---
            pkt = zigbee_rx_one(rx_noisy, Fs, dsss_table, L, pulse, halfChipShift);

            if isempty(pkt.psdu_no_fcs)
                % не смогли распарсить кадр → считаем, что все биты payload ошибочны
                err_bits_sum = err_bits_sum + Nbits_payload;
                bits_sum     = bits_sum     + Nbits_payload;
                continue;
            end

            rx_payload = pkt.psdu_no_fcs(:).';
            Lb = min(numel(rx_payload), numel(true_payload));

            % сравниваем только Lb байт payload
            for k = 1:Lb
                x = bitxor(rx_payload(k), true_payload(k));
                err_bits_sum = err_bits_sum + sum(bitget(x,1:8));
            end
            bits_sum = bits_sum + Lb*8;
        end

        BER(isnr) = err_bits_sum / bits_sum;
        fprintf("SNR = %3d dB → BER = %.4g (по payload), средний CRC_OK не считаем тут\n", ...
                SNRdB, BER(isnr));
    end

    %% --- График BER vs SNR ---
    figure;
    semilogy(SNRdB_vec, BER, '-o','LineWidth',1.5);
    grid on;
    xlabel('SNR, dB');
    ylabel('BER');
    title(sprintf('BER vs SNR (Niters = %d)', Niters));

    results.SNRdB = SNRdB_vec;
    results.BER   = BER;
end
