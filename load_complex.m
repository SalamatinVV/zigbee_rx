function x = load_complex(filename)
% Загружает текстовый файл формата:
%   Re Im
%   Re Im
% и возвращает комплексный вектор x = Re + j*Im

    data = load(filename);   % Nx2
    if size(data,2) ~= 2
        error("Файл %s должен содержать 2 столбца (Re, Im).", filename);
    end

    x = data(:,1) + 1j*data(:,2);
end
