function data = read_polars(filename)
% Reads the csv file into a table
T = readtable(filename);

% Access columns directly by their names
alpha = T.Alpha;   % assumes header is exactly "Alpha"
cl    = T.Cl;
cd    = T.Cd;

% --- Detect whether Alpha is in radians or degrees ---
% Simple heuristic: if max(|alpha|) <= 2*pi, it's radians
% if max(abs(alpha)) <= 2*pi
%     alpha = rad2deg(alpha);  % convert to degrees
% end

% Output [Alpha[deg], Cl, Cd]
data = [alpha cl cd];
end