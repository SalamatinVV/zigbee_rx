function bits = bytes2bits(bytes)
    bits = zeros(1, numel(bytes)*8);
    for i = 1:numel(bytes)
        for b = 1:8
            bits((i-1)*8+b) = bitget(bytes(i), b);
        end
    end
end
