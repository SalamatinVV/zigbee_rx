function mac_print(info)
    fprintf("===== RAW MAC HEADER =====\n");
    fprintf("FCF: 0x%04X\n", info.fcf);
    fprintf("  Frame Type: %d (%s)\n", info.frame_type, info.frame_type_str);
    fprintf("  Security Enabled: %d\n", info.security_enabled);
    fprintf("  Frame Pending: %d\n", info.frame_pending);
    fprintf("  Ack Request: %d\n", info.ack_request);
    fprintf("  PAN ID Compression: %d\n", info.pan_compression);
    fprintf("  Dest Addr Mode: %d (%s)\n", info.dest_mode, info.dest_mode_str);
    fprintf("  Src Addr Mode: %d (%s)\n", info.src_mode, info.src_mode_str);
    fprintf("\n");
    fprintf("\n===== MAC FRAME INFO =====\n");

    % Тип кадра
    types = ["Beacon","Data","Ack","Command","Reserved","Reserved","Reserved","Reserved"];
    fprintf("Frame Type: %s\n", types(info.frame_type+1));

    fprintf("Seq Num: %d (0x%02X)\n", info.seq_num, info.seq_num);
    fprintf("Ack Request: %d\n", info.ack_request);

    if ~isempty(info.dst_pan)
        fprintf("Destination PAN ID: 0x%04X\n", info.dst_pan);
    end
    if ~isempty(info.dst_addr)
        fprintf("Destination Addr: 0x%04X\n", info.dst_addr);
    end

    if ~isempty(info.src_pan)
        fprintf("Source PAN ID: 0x%04X\n", info.src_pan);
    end
    if ~isempty(info.src_addr)
        fprintf("Source Addr: 0x%04X\n", info.src_addr);
    end

    fprintf("Payload (%d bytes): ", length(info.payload));
    fprintf("%02X ", info.payload);
    fprintf("\n");
    

end
