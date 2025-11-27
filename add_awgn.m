function y = add_awgn(x, SNRdB)
    P = mean(abs(x).^2);
    N0 = P / (10^(SNRdB/10));
    noise = sqrt(N0/2) * (randn(size(x)) + 1j*randn(size(x)));
    y = x + noise;
end
