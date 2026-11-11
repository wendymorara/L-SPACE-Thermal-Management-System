function write_csv(fname, header, data)
%WRITE_CSV  Minimal CSV writer that runs identically in MATLAB and Octave.
%
%   write_csv(fname, header, data)
%     header  cell array of column names
%     data    cell array (rows x cols) of numbers or char, or a numeric matrix

if isnumeric(data), data = num2cell(data); end
fid = fopen(fname, 'w');
fprintf(fid, '%s', header{1});
fprintf(fid, ',%s', header{2:end});
fprintf(fid, '\n');
for r = 1:size(data,1)
    for c = 1:size(data,2)
        v = data{r,c};
        if c > 1, fprintf(fid, ','); end
        if ischar(v), fprintf(fid, '"%s"', v); else, fprintf(fid, '%.6g', v); end
    end
    fprintf(fid, '\n');
end
fclose(fid);
end
