function X = rP_read_resultsfile (file)

% function X = rP_read_resultsfile (file)
% 
% Read and parse data in ruediPy results data file (see rP_calibrate_batch).
% 
% INPUT:
% file: name of results data file.
% 
% OUPUT:
% X: struct object with data from file. Stuct fields correspond to the header / columns in the results file.
%	- The first column is blindly assumed to be the sample name
%	- All other columns are assued to be EPOCHTIME/VALUE/ERROR triples
%	- Time/date is returned in Octave/Matlab datenum format
%
% DISCLAIMER:
% This file is part of ruediPy, a toolbox for operation of RUEDI mass spectrometer systems.
% 
% ruediPy is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% ruediPy is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with ruediPy.  If not, see <http://www.gnu.org/licenses/>.
% 
% ruediPy: toolbox for operation of RUEDI mass spectrometer systems
% Copyright (C) 2016, 2017, Matthias Brennwald (brennmat@gmail.com)
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% 
% Copyright 2017, Matthias Brennwald (brennmat@gmail.com)

% try to get read access to the file:
[fid, msg] = fopen (file, 'rt');

if fid == -1 % could not get read access to file, issue error:
	error (sprintf('ruediPy_read_resultsfile: could not get read access to file %s (%s)',file,msg))
	
% read and parse data from file:
else
	
	header = fgetl (fid);
	if header == -1
		error (sprintf('ruediPy_read_resultsfile: could not read first header line in file %s.',file))	
	end

	columns = strsplit (header,';');
	f = repmat (' %f',1,length(columns)-1);
	f = [ '%s' f ];
	frewind (fid);
	x = textscan (fid,f,'delimiter',';','HeaderLines',1,'EmptyValue',NA);	
	
	fclose (fid);
	clear f
	
	if length (x) == 0
		error (sprintf('ruediPy_read_resultsfile: could not read data in file %s.',file))	
	end

	X.SAMPLES = x{1,1};
	
	N = ( length(columns) -1) / 3; % number of data items (time/value/error columns)
	
	% determine field names and units:
	for i = 1:N
		f = columns{1+3*i-1};
		k = strfind (f,' (')(end);
		
		% field name:
		ff = f(1:k-1);
		ff = strrep (ff,' ','_');
		ff = strrep (ff,'-','_');
		ff = strrep (ff,'(','');
		ff = strrep (ff,')','');
		ff = strrep (ff,'_TIME','');
		
		% units:
		u = f(k+1:end)(2:end-1);
		
		fields{i} = ff;
		units{i}  = u;
		
	end
	
	% parse data to struct
	for i = 1:N
		f = struct('TIME',rP_epochtime2datenum (x{3*i-1}),'VAL',x{3*i},'ERR',x{3*i+1},'UNIT',units{i});
		eval (sprintf ('X.%s = f;',fields{i}))
	end

end % if / else
end % function
