function peakIdxs = find_peaks_simple(corrP, thr, minDist)
    N = length(corrP);
    cand = [];
    for i = 2:N-1
        if corrP(i) > thr && corrP(i) >= corrP(i-1) && corrP(i) >= corrP(i+1)
            cand(end+1) = i; %#ok<AGROW>
        end
    end
    peakIdxs = [];
    last = -inf;
    for i = 1:numel(cand)
        if cand(i) - last >= minDist
            peakIdxs(end+1) = cand(i); %#ok<AGROW>
            last = cand(i);
        end
    end
end
