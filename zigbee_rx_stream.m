function packets = zigbee_rx_stream(rx, Fs, dsss_table, L, pulse, halfChipShift)
% Ищет ВСЕ преамбулы по корреляции и декодирует каждый пакет.

    % Эталонная преамбула (как в zigbee_rx_one)
    numPreambleBytes = 4;
    numPreambleBits  = numPreambleBytes * 8;
    bitsPreamble = zeros(1, numPreambleBits);
    symbolsPreamble = reshape(bitsPreamble, 4, []).';
    symValsPreamble = symbolsPreamble * [1 2 4 8].';

    chipsPreamble = [];
    for s = symValsPreamble.'
        chipsPreamble = [chipsPreamble dsss_table(s+1,:)]; %#ok<AGROW>
    end
    Ichips = chipsPreamble(1:2:end);
    Qchips = chipsPreamble(2:2:end);
    Iup = kron(Ichips, pulse);
    Qup = kron(Qchips, pulse);
    Qup = circshift(Qup, halfChipShift);
    refPreamble = Iup + 1j*Qup;
    refLen = length(refPreamble);

    % Корреляция по всему сигналу
    corrP = abs(conv(rx, fliplr(conj(refPreamble))));

    % Поиск пиков выше порога
    thr = 0.5 * max(corrP);
    minDist = refLen;      % чтобы пики не налезали
    peakIdxs = find_peaks_simple(corrP, thr, minDist);

    % Шаблон структуры
    packets = struct('start_sample', {}, 'peak_sample', {}, 'pkt', {});

    for i = 1:numel(peakIdxs)
        peakIdx = peakIdxs(i);
        startPreamble = peakIdx - refLen + 1;
        if startPreamble < 1 || startPreamble > length(rx)
            continue;
        end

        rx_tail = rx(startPreamble:end);
        pkt = zigbee_rx_one(rx_tail, Fs, dsss_table, L, pulse, halfChipShift);

        packets(i).start_sample = startPreamble;
        packets(i).peak_sample  = peakIdx;
        packets(i).pkt          = pkt;
    end
end
