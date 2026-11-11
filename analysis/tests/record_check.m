function [rows, nfail] = record_check(rows, nfail, id, name, val, tol, unit)
%RECORD_CHECK  Print and store one PASS/FAIL verification result.
pass = val <= tol;
if pass, s = 'PASS'; else, s = 'FAIL'; nfail = nfail + 1; end
fprintf('%-4s %-48s %10.4g <= %-8.3g %-4s %s\n', id, name, val, tol, unit, s);
rows(end+1,:) = {id, name, val, tol, unit, s};
end
