function rx = load_complex_txt(filename)
    data = load(filename);     % две колонки: Re Im
    rx = data(:,1) + 1j*data(:,2);
end
