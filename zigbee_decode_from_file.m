function pkt = zigbee_decode_from_file(filename)
% Декодирует один Zigbee PHY-пакет из файла complex baseband (txt)

pkt = [];   % значение по умолчанию

%% ------------------- ПАРАМЕТРЫ PHY -------------------
Fs   = 8e6;
Rb   = 250e3;
Rsym = Rb/4;
chipsPerSym = 32;
Rchip = Rsym * chipsPerSym;
L = round(Fs/Rchip);
halfChipShift = round(L/2);

n = 0:L-1;
pulse = sin(pi*n/(L-1));

%% ------------------- DSSS таблица -------------------
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

%% ------------------- ЗАГРУЗКА -----------------------
data = load(filename);
rx = data(:,1) + 1j*data(:,2);

fprintf("Файл загружен: %d семплов\n", length(rx));

%% ------------------- ДЕКОД --------------------------
pkt = zigbee_rx_one(rx, Fs, dsss_table, L, pulse, halfChipShift);

%% ------------------- ВЫВОД --------------------------
if isempty(pkt.psdu_no_fcs)
    fprintf("Ошибка: пакет не найден!\n");
    return;
end

fprintf("\n===== РЕЗУЛЬТАТ ДЕКОДИРОВАНИЯ =====\n");
fprintf("Преамбула: %s\n", mat2str(pkt.preamble_rx));
fprintf("SFD: 0x%02X\n", pkt.sfd_rx);
fprintf("PHR: %d байт\n", pkt.phr_rx);

fprintf("PSDU (hex): ");
fprintf("%02X ", pkt.psdu_no_fcs);
fprintf("\n");

fprintf("FCS RX: [%02X %02X]\n", pkt.fcs_rx(1), pkt.fcs_rx(2));
fprintf("FCS CALC: [%02X %02X]\n", pkt.crc_calc_bytes(1), pkt.crc_calc_bytes(2));

if pkt.crc_ok
    fprintf("\n*** CRC OK — пакет принят корректно! ***\n");
else
    fprintf("\n*** CRC ERROR — пакет повреждён! ***\n");
end

end
