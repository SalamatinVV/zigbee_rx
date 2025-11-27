function pkt = zigbee_rx_one(rx, Fs, dsss_table, L, pulse, halfChipShift)
% Принимает ОДИН Zigbee пакет в сигнале rx (можно с шумом).
% Возвращает структуру:
%   pkt.bytesHat, pkt.psdu_no_fcs, pkt.fcs_rx, pkt.crc_ok и т.п.

    chipsPerSym = 32;
    Rb   = 250e3;
    Rsym = Rb/4;
    Rchip = Rsym * chipsPerSym; %#ok<NASGU> % оставлено на случай доработки

    %% --- Эталонная преамбула (4 байта 0x00) ---
    numPreambleBytes = 4;
    numPreambleBits  = numPreambleBytes * 8;
    bitsPreamble = zeros(1, numPreambleBits);  % LSB-first нули
    symbolsPreamble = reshape(bitsPreamble, 4, []).';
    symValsPreamble = symbolsPreamble * [1 2 4 8].';     % все 0

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

    %% --- Корреляция с преамбулой ---
    corrP = abs(conv(rx, fliplr(conj(refPreamble))));
    [~, peakIdx] = max(corrP);

    startPreamble = peakIdx - refLen + 1;
    startPreamble = max(startPreamble, 1);

    rx_sync = rx(startPreamble:end);

    %% --- DEMOD OQPSK → ЧИПЫ ---
    I_branch = real(rx_sync);
    Q_branch = imag(rx_sync);

    numSamplesBranch = min(length(I_branch), length(Q_branch));
    numChipsBranch   = floor(numSamplesBranch / L);

    I_branch = I_branch(1:numChipsBranch*L);
    Q_branch = Q_branch(1:numChipsBranch*L);

    Ichips_est = zeros(1, numChipsBranch);
    Qchips_est = zeros(1, numChipsBranch);

    for k = 1:numChipsBranch
        segI = I_branch((k-1)*L+1 : k*L);
        segI = segI(:).';
        valI = sum(segI .* pulse);

        q_start = (k-1)*L + 1 + halfChipShift;
        q_end   = k*L + halfChipShift;
        if q_end > length(Q_branch)
            break;
        end
        segQ = Q_branch(q_start:q_end);
        segQ = segQ(:).';
        valQ = sum(segQ .* pulse);

        Ichips_est(k) = sign(valI);
        Qchips_est(k) = sign(valQ);
    end

    chips_est = zeros(1, 2*numChipsBranch);
    chips_est(1:2:end) = Ichips_est;
    chips_est(2:2:end) = Qchips_est;

    %% --- DESPREAD → символы ---
    numSymbols = floor(length(chips_est) / chipsPerSym);
    chips_est = chips_est(1:numSymbols*chipsPerSym);

    chips_matrix = reshape(chips_est, chipsPerSym, []).';
    symHat = zeros(1, numSymbols);
    for k = 1:numSymbols
        seg = chips_matrix(k,:);
        metrics = dsss_table * seg.';
        [~, idxMax] = max(metrics);
        symHat(k) = idxMax - 1;
    end

    %% --- Символы → биты → байты ---
    bitsHat = zeros(1, numSymbols*4);
    for k = 1:numSymbols
        s = symHat(k);
        for b = 1:4
            bitsHat(4*(k-1)+b) = bitget(s, b);
        end
    end

    numBytesMax = floor(length(bitsHat)/8);
    bitsHat = bitsHat(1:numBytesMax*8);

    bytesHat = zeros(1, numBytesMax, 'uint8');
    for k = 1:numBytesMax
        bbits = bitsHat(8*(k-1)+1 : 8*k);
        val = uint8(0);
        for i = 1:8
            val = bitor(val, bitshift(uint8(bbits(i)), i-1));
        end
        bytesHat(k) = val;
    end

    %% --- Парсинг PHY кадра ---
    pkt = struct();
    pkt.bytesHat = bytesHat;
    pkt.bitsHat  = bitsHat;

    if numBytesMax < 6
        % недостаточно байт, чтобы выделить PHY
        pkt.preamble_rx = [];
        pkt.sfd_rx      = [];
        pkt.phr_rx      = [];
        pkt.psdu_rx     = [];
        pkt.psdu_no_fcs = [];
        pkt.fcs_rx      = [];
        pkt.crc_ok      = false;
        return;
    end

    preamble_rx = bytesHat(1:4);
    sfd_rx      = bytesHat(5);
    phr_rx      = bytesHat(6);

    pkt.preamble_rx = preamble_rx;
    pkt.sfd_rx      = sfd_rx;
    pkt.phr_rx      = phr_rx;

    if 6+double(phr_rx) > numBytesMax
        pkt.psdu_rx     = [];
        pkt.psdu_no_fcs = [];
        pkt.fcs_rx      = [];
        pkt.crc_ok      = false;
        return;
    end

    psdu_rx = bytesHat(7 : 6+double(phr_rx));
    pkt.psdu_rx = psdu_rx;

    if numel(psdu_rx) >= 2
        pkt.psdu_no_fcs = psdu_rx(1:end-2);
        pkt.fcs_rx      = psdu_rx(end-1:end);
    else
        pkt.psdu_no_fcs = [];
        pkt.fcs_rx      = [];
    end

    % --- CRC-16 KERMIT ---
    if ~isempty(pkt.psdu_no_fcs)
        crc_calc = crc16_kermit_bytes(pkt.psdu_no_fcs);
        crc_bytes = uint8([bitand(crc_calc,255), bitshift(crc_calc,-8)]);
        pkt.crc_calc_bytes = crc_bytes;
        if ~isempty(pkt.fcs_rx) && all(crc_bytes == pkt.fcs_rx)
            pkt.crc_ok = true;
        else
            pkt.crc_ok = false;
        end
    else
        pkt.crc_ok = false;
        pkt.crc_calc_bytes = [];
    end
end
