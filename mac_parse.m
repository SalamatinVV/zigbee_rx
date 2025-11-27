function info = mac_parse(psdu)
% psdu — массив uint8 без FCS

    psdu = uint8(psdu);   % гарантируем тип
    psdu16 = uint16(psdu);  % для арифметики

    %% --- FRAME CONTROL FIELD (FCF) ---
    fc = bitor(psdu16(1), bitshift(psdu16(2), 8));   % little-endian

    frame_type = bitand(fc, 7);           % биты 0–2
    security    = bitget(fc, 4);
    frame_pending = bitget(fc, 5);
    ack_req        = bitget(fc, 6);
    pan_compress   = bitget(fc, 7);

    dst_addr_mode = bitand(bitshift(fc,-10), 3);   % bits 10-11
    src_addr_mode = bitand(bitshift(fc,-14), 3);   % bits 14-15

    %% --- SEQ NUM ---
    seq_num = psdu(3);

    %% --- Адресация ---
    index = 4;

    % Destination PAN ID
    if dst_addr_mode ~= 0
        dst_pan = bitor(psdu16(index), bitshift(psdu16(index+1),8));
        index = index + 2;
    else
        dst_pan = [];
    end

    % Destination Address
    if dst_addr_mode == 2      % short 16-bit
        dst_addr = bitor(psdu16(index), bitshift(psdu16(index+1),8));
        index = index + 2;
    elseif dst_addr_mode == 3  % long 64-bit
        dst_addr = uint64(0);
        for k=0:7
            dst_addr = dst_addr + bitshift(uint64(psdu(index+k)), 8*k);
        end
        index = index + 8;
    else
        dst_addr = [];
    end

    % Source PAN ID
    if src_addr_mode ~= 0
        if pan_compress
            src_pan = dst_pan;  % PAN Compression
        else
            src_pan = bitor(psdu16(index), bitshift(psdu16(index+1),8));
            index = index + 2;
        end
    else
        src_pan = [];
    end

    % Source Address
    if src_addr_mode == 2
        src_addr = bitor(psdu16(index), bitshift(psdu16(index+1),8));
        index = index + 2;
    elseif src_addr_mode == 3
        src_addr = uint64(0);
        for k=0:7
            src_addr = src_addr + bitshift(uint64(psdu(index+k)), 8*k);
        end
        index = index + 8;
    else
        src_addr = [];
    end

    %% --- Payload ---
    payload = psdu(index:end);

    %% --- Формируем структуру ---
    info = struct( ...
        'frame_type',       frame_type, ...
        'security',         security, ...
        'frame_pending',    frame_pending, ...
        'ack_request',      ack_req, ...
        'pan_compression',  pan_compress, ...
        'seq_num',          seq_num, ...
        'dst_pan',          dst_pan, ...
        'dst_addr',         dst_addr, ...
        'src_pan',          src_pan, ...
        'src_addr',         src_addr, ...
        'payload',          payload ...
    );
    % Разбор FCF (Frame Control Field)
    fc = typecast(uint8(psdu(1:2)), 'uint16');
    info.fcf = fc;
    
    info.frame_type = bitand(fc, 0x0007);
    ft_names = {"Beacon","Data","Ack","Command","Reserved","Reserved","Reserved","Reserved"};
    info.frame_type_str = ft_names{info.frame_type+1};
    
    info.security_enabled = bitget(fc, 4);
    info.frame_pending    = bitget(fc, 5);
    info.ack_request      = bitget(fc, 6);
    info.pan_compression  = bitget(fc, 7);
    
    % Адресные режимы
    info.dest_mode = bitshift(bitand(fc, hex2dec('0C00')), -10);
    info.src_mode  = bitshift(bitand(fc, hex2dec('C000')), -14);
    
    mode_names = {"None","Reserved","16-bit","64-bit"};
    info.dest_mode_str = mode_names{info.dest_mode+1};
    info.src_mode_str  = mode_names{info.src_mode+1};

end
