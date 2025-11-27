function zigbee_compare_clean_vs_noisy(filename, SNRdB)
% Загружает оригинальный Zigbee файл, добавляет шум, декодирует снова
% и сравнивает два MAC кадра.

    fprintf("\n=== ШАГ 1: Загружаем чистый сигнал ===\n");
    pkt_clean = zigbee_decode_from_file(filename);

    fprintf("\n=== ШАГ 2: Парсим MAC ===\n");
    info_clean = mac_parse(pkt_clean.psdu_no_fcs);

    fprintf("\n=== MAC кадр (без шума) ===\n");
    mac_print(info_clean);

    % --------------------------------------------------------
    %  СЧИТЫВАЕМ СИГНАЛ С ДИСКА
    % --------------------------------------------------------
    data = load(filename);
    rx = data(:,1) + 1j*data(:,2);
    Fs = 8e6;

    % Мощность сигнала
    Ps = mean(abs(rx).^2);
    SNRlin = 10^(SNRdB/10);
    Pn = Ps / SNRlin;

    % Шум
    noise = sqrt(Pn/2) * (randn(size(rx)) + 1j*randn(size(rx)));

    rx_noisy = rx + noise;

    % Сохраняем NOISY версию в файл
    noisy_file = "zigbee_noisy.txt";
    dlmwrite(noisy_file, [real(rx_noisy), imag(rx_noisy)], 'delimiter', ' ');

    fprintf("\n=== ШАГ 3: Добавили шум %.1f dB → записали в %s ===\n", SNRdB, noisy_file);

    % --------------------------------------------------------
    %  ДЕКОДИРУЕМ НОВЫЙ СИГНАЛ
    % --------------------------------------------------------
    fprintf("\n=== ШАГ 4: Декодируем noisy ===\n");
    pkt_noisy = zigbee_decode_from_file(noisy_file);

    fprintf("\n=== ШАГ 5: Парсим MAC noisy ===\n");
    info_noisy = mac_parse(pkt_noisy.psdu_no_fcs);

    fprintf("\n=== MAC кадр (с шумом) ===\n");
    mac_print(info_noisy);

    % --------------------------------------------------------
    %  СРАВНЕНИЕ PAYLOAD
    % --------------------------------------------------------
 
    % === 6. Compare clean vs noisy ===
    fprintf("\n=== ШАГ 6: Сравнение clean vs noisy ===\n");
    
    % CRC сравниваем на уровне PHY
    if pkt_noisy.crc_ok
        fprintf("CRC noisy: OK\n");
    else
        fprintf("CRC noisy: ERROR\n");
    end
    
    % сравнение payload
    payload_clean = info_clean.payload;
    payload_noisy = info_noisy.payload;
    
    N = min(length(payload_clean), length(payload_noisy));
    diff_bits = sum(payload_clean(1:N) ~= payload_noisy(1:N));
    BER = diff_bits / (N*8);
    
    fprintf("Payload сравнение: совпадает на %.2f%%\n", ...
        100 * (1 - BER));
    fprintf("BER = %.6f\n", BER);
%% === ШАГ 7: Фазовый сдвиг ===
    phase_deg = -91;   % можно менять: 10, 30, 60, 90, 120, 180, ...
    clean = load_complex_txt("zigbee_phy_baseband.txt");
    rx_phase = add_phase_shift(clean, phase_deg);
    scatterplot(clean)
    scatterplot(rx_phase)
    dlmwrite("zigbee_phase_shifted.txt", [real(rx_phase), imag(rx_phase)], 'delimiter', ' ');
   
    fprintf("\n=== ФАЗОВЫЙ СДВИГ: %d° ===\n", phase_deg);
    
    pkt_phase = zigbee_decode_from_file("zigbee_phase_shifted.txt");
    info_phase = mac_parse(pkt_phase.psdu_no_fcs);
    mac_print(info_phase);
    
    %% сравнение фазового варианта с оригиналом
    bits_clean  = bytes2bits(pkt_clean.psdu_no_fcs);
    bits_phase  = bytes2bits(pkt_phase.psdu_no_fcs);
    
    N = min(length(bits_clean), length(bits_phase));
    ber_phase = sum(bits_clean(1:N) ~= bits_phase(1:N)) / N;
    
    fprintf("BER (phase shift %d°) = %.6f\n", phase_deg, ber_phase);

end
