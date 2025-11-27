%% ============================================================
%  Полный MATLAB-приёмник PHY IEEE 802.15.4 (2.4 GHz, OQPSK)
%  Совместим с твоим Python-генератором zigbee.py
% ============================================================
clear; clc; close all;

%% ---------------- ПАРАМЕТРЫ PHY ----------------
Rb   = 250e3;           % бит/с
Rsym = Rb/4;            % 4 бита на символ => 62.5 ksym/s
chipsPerSym = 32;
Rchip = Rsym * chipsPerSym;         % 2 Mchips/s

Fs   = 8e6;                           % как в Python (если файл с Fs=4e6, можно заменить)
L    = Fs / Rchip;                    % samples per chip (ожидаем целое)
if abs(L - round(L)) > 1e-9
    error('Fs / Rchip не целое. Подбери Fs кратным 2 МГц.');
end
L = round(L);
halfChipShift = round(L/2);

% Half-sine pulse
n = 0:L-1;
pulse = sin(pi * n/(L-1));
pulse = pulse(:).';   % делаем из pulse строку

%% ------------- DSSS таблица (как в твоём Python) -------------
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
dsss_table = 2*dsss_table_bits - 1;   % 0->-1, 1->+1

%% ------------- ЗАГРУЗКА СИГНАЛА ОТ PYTHON -------------
data = load("zigbee_phy_baseband.txt");   % [N x 2]
rx = data(:,1) + 1j*data(:,2);
%% --- ДОБАВЛЕНИЕ AWGN ШУМА ---
SNRdB = -5;   % <-- меняй тут SNR, например 20, 10, 5, 0, -5 dB

signalPower = mean(abs(rx).^2);
SNRlinear = 10^(SNRdB/10);
noisePower = signalPower / SNRlinear;

noise = sqrt(noisePower/2) * (randn(size(rx)) + 1j*randn(size(rx)));

rx = rx + noise;

fprintf("Добавлен AWGN шум: SNR = %.1f dB\n", SNRdB);
%% Нормировка
% Нормировка мощности
rx = rx / rms(rx);

%% ------------- ЭТАЛОННАЯ ПРЕАМБУЛА (4 байта 0x00) -------------
numPreambleBytes = 4;
numPreambleBits  = numPreambleBytes * 8;
bitsPreamble = zeros(1, numPreambleBits);  % LSB-first нули
symbolsPreamble = reshape(bitsPreamble, 4, []).';
symValsPreamble = symbolsPreamble * [1 2 4 8].';     % все 0

% DSSS
chipsPreamble = [];
for s = symValsPreamble.'
    chipsPreamble = [chipsPreamble dsss_table(s+1,:)];
end

% OQPSK half-sine модуляция эталона
Ichips = chipsPreamble(1:2:end);
Qchips = chipsPreamble(2:2:end);

Iup = kron(Ichips, pulse);
Qup = kron(Qchips, pulse);
Qup = circshift(Qup, halfChipShift);

refPreamble = Iup + 1j*Qup;           % эталонная преамбула

%% ------------- КОРРЕЛЯЦИЯ С ПРЕАМБУЛОЙ -------------
corrP = abs(conv(rx, fliplr(conj(refPreamble))));
[peakVal, peakIdx] = max(corrP);
refLen = length(refPreamble);

startPreamble = peakIdx - refLen + 1;   % ← ВОТ ТАК, а не -refLen/2
startPreamble = max(startPreamble, 1);

fprintf("Исправленное начало преамбулы ≈ %d\n", startPreamble);

rx_sync = rx(startPreamble:end);

figure;
plot(corrP); grid on;
title('Корреляция входного сигнала с эталонной преамбулой');
xlabel('Сэмпл'); ylabel('Амплитуда');
fprintf("peakIdx = %d\n", peakIdx);
fprintf("refLen  = %d\n", refLen);
fprintf("startPreamble = %d\n", startPreamble);

%% ------------- DEMOD OQPSK → ЧИПЫ -------------------
I_branch = real(rx_sync);
Q_branch = imag(rx_sync);

% Длина по веткам (берём только целое число чипов)
numSamplesBranch = min(length(I_branch), length(Q_branch));
numChipsBranch   = floor(numSamplesBranch / L);

I_branch = I_branch(1:numChipsBranch*L);
Q_branch = Q_branch(1:numChipsBranch*L);

fprintf("Length rx_sync = %d\n", length(rx_sync));
fprintf("Samples per chip L = %d\n", L);
fprintf("numSamplesBranch = %d\n", numSamplesBranch);
fprintf("numChipsBranch  = %d\n", numChipsBranch);

Ichips_est = zeros(1, numChipsBranch);
Qchips_est = zeros(1, numChipsBranch);

for k = 1:numChipsBranch
    % I-сегмент строго по L сэмплов
    segI = I_branch((k-1)*L+1 : k*L);
    segI = segI(:).';               % %%% FIX: делаем строку
    valI = sum(segI .* pulse);      % скаляр

    % Q-сегмент со сдвигом на полчипа
    q_start = (k-1)*L + 1 + halfChipShift;
    q_end   = k*L + halfChipShift;
    if q_end > length(Q_branch)
        break;
    end
    segQ = Q_branch(q_start:q_end);
    segQ = segQ(:).';               % %%% FIX: тоже строка
    valQ = sum(segQ .* pulse);      % скаляр

    Ichips_est(k) = sign(valI);
    Qchips_est(k) = sign(valQ);
end

% Восстанавливаем чередующийся поток чипов [I0,Q0,I1,Q1,...]
chips_est = zeros(1, 2*numChipsBranch);
chips_est(1:2:end) = Ichips_est;
chips_est(2:2:end) = Qchips_est;

%% ------------- DESPREADING: 32 chips → символ 0..15 -------------
numSymbols = floor(length(chips_est) / chipsPerSym);
chips_est = chips_est(1:numSymbols*chipsPerSym);

chips_matrix = reshape(chips_est, chipsPerSym, []).';   % [numSymbols x 32]

symHat = zeros(1, numSymbols);
for k = 1:numSymbols
    seg = chips_matrix(k,:);
    metrics = dsss_table * seg.';   % 16 x 1
    [~, idxMax] = max(metrics);
    symHat(k) = idxMax - 1;         % символ 0..15
end

%% ------------- СИМВОЛЫ → БИТЫ → БАЙТЫ ----------------
bitsHat = zeros(1, numSymbols*4);
for k = 1:numSymbols
    s = symHat(k);
    % LSB-first: b0..b3
    for b = 1:4
        bitsHat(4*(k-1)+b) = bitget(s, b);
    end
end

% Обрежем до кратности 8
numBytesMax = floor(length(bitsHat)/8);
bitsHat = bitsHat(1:numBytesMax*8);

bytesHat = zeros(1, numBytesMax, 'uint8');
for k = 1:numBytesMax
    bbits = bitsHat(8*(k-1)+1 : 8*k);   % b0..b7 LSB-first
    val = uint8(0);
    for i = 1:8
        val = bitor(val, bitshift(uint8(bbits(i)), i-1));
    end
    bytesHat(k) = val;
end

%% ------------- ПАРСИНГ PHY КАДРА ----------------
fprintf("\nПолученные первые 16 байт (hex):\n");
for k = 1:min(16, numBytesMax)
    fprintf("%02X ", bytesHat(k));
end
fprintf("\n");

if numBytesMax < 6
    error('Слишком мало байт для полноценного PHY кадра.');
end

preamble_rx = bytesHat(1:4);
sfd_rx      = bytesHat(5);
phr_rx      = bytesHat(6);

fprintf("Преамбула: %s\n", mat2str(preamble_rx));
fprintf("SFD: 0x%02X (ожидалось 0xA7)\n", sfd_rx);
fprintf("PHR (длина PSDU): %d байт\n", phr_rx);

psdu_rx = bytesHat(7 : 6+double(phr_rx));
if length(psdu_rx) < double(phr_rx)
    warning('PSDU обрезано: не хватает байт.');
end

if length(psdu_rx) >= 2
    psdu_no_fcs = psdu_rx(1:end-2);
    fcs_rx      = psdu_rx(end-1:end);
else
    error('PSDU слишком короткое для FCS.');
end

fprintf("PSDU без FCS (%d байт):\n", length(psdu_no_fcs));
disp(dec2hex(psdu_no_fcs));

fprintf("Принятый FCS: [%02X %02X]\n", fcs_rx(1), fcs_rx(2));

%% ------------- ПРОВЕРКА CRC-16 KERMIT ----------------
crc_calc = crc16_kermit_bytes(psdu_no_fcs);
crc_bytes = uint8([bitand(crc_calc,255), bitshift(crc_calc,-8)]); % LSB first

fprintf("Вычисленный FCS: [%02X %02X]\n", crc_bytes(1), crc_bytes(2));

if all(crc_bytes == fcs_rx)
    fprintf("\n*** CRC OK: кадр принят без ошибок (в идеальной модели) ***\n");
else
    fprintf("\n*** CRC MISMATCH: что-то не сошлось ***\n");
end

%% ============================================================
%       ЛОКАЛЬНАЯ ФУНКЦИЯ CRC-16 KERMIT (как в Python)
% ============================================================
function crc = crc16_kermit_bytes(dataBytes)
    crc = uint16(0);
    poly = uint16(hex2dec('8408'));    % реверс 0x1021

    for b = dataBytes
        crc = bitxor(crc, uint16(b));
        for i = 1:8
            if bitand(crc, uint16(1))
                crc = bitxor(bitshift(crc, -1), poly);
            else
                crc = bitshift(crc, -1);
            end
        end
    end
    crc = bitand(crc, uint16(65535));
end
