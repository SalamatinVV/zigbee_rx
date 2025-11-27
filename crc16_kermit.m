function crc = crc16_kermit(data)
    crc = uint16(0);
    poly = uint16(hex2dec('8408'));
    for b = data(:).'
        crc = bitxor(crc, uint16(b));
        for i = 1:8
            if bitand(crc,1)
                crc = bitxor(bitshift(crc,-1), poly);
            else
                crc = bitshift(crc, -1);
            end
        end
    end
end
