function X = rP_read_datafile (file,dict)

% function X = rP_read_datafile (file,dict)
% 
% Read and parse data in ruediPy datafiles.
% (work in progress!)
% 
% INPUT:
% file: file name. Either the full path to the file must be specified or the file name only. If only the filename is given, then the first file in the search path matching this file name is used. If file contains a wildcard, all files matching the pattern are loaded.
% dict: cellstring with names / types of objects with non-standard labels / names (e.g., the SELECTORVALVE and SRSRGA objects):
%		format:  dict ={ LABEL-NAME-1 OBJECT-TYPE-1 ; LABEL-NAME-2 , OBJECT-TYPE-2 ; ... }
%
%		known object types:
%		- 'SRSRGA' (may have custom object label)
%		- 'SELECTORVALVE' (may have custom object label)
%		- 'DATAFILE' (generic / does not allow custom object label) 
%
%		example: dict ={ 'RGA-MS' , 'SRSRGA' ; 'INLETSELECTOR' , 'SELECTORVALVE' }		
% 
% OUPUT:
% X: struct object with data from file. Stuct fields correspond to OBJECT and TYPE keys found in the data file.
% 
% EXAMPLE 1 (read datafile ~/ruedi_data/2016-03-30_13-27-02.txt, where the RGAMS object was called 'RGA-MS' and the SELECTORVALVE object was called 'INLETSELECTVALVE'):
% DAT = rP_read_datafile('~/ruedi_data/2016-03-30_13-27-02.txt',{'RGA-MS' 'SRSRGA' ; 'INLETSELECTVALVE' 'SELECTORVALVE'})
%
% EXAMPLE 2 (read datafiles from March 2016):
% x = rP_read_datafile('~/ruedi_data/2016-03-*.txt',{'RGA-MS' 'SRSRGA' ; 'INLETSELECTVALVE' 'SELECTORVALVE'});
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
% Copyright (C) 2016  Matthias Brennwald
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
% Copyright 2016, Matthias Brennwald (brennmat@gmail.com)


% check for wildcards in file, determine file(s) to be loaded:
files = glob (tilde_expand(file)); % cell string containing all file names matching 'file'
if length(files) > 1 % more than one file, so loop through all files
    for i = 1:length(files)
        u = rP_read_datafile (files{i},dict);
        if ~isempty(u) % only append if loading data file was successful
            X{i} = u;
        else
        	X{i} = [];
        end
    end
    return % return to caller, don't execute code below, which is for single files only
end

% try to get read access to the file:
[fid, msg] = fopen (file, 'rt');

if fid == -1 % could not get read access to file, issue error:
	error (sprintf('ruediPy_read_datafile: could not get read access to file %s (%s)',file,msg))
	
else % read file line by line:

	if ~exist('dict','var')
		dict = {};
	end
	if isempty (dict)
		warning ('rP_read_datafile: not dictionary for object-labels and object-types given. Assuming generic names/types...')
		dict = { '' '' }; % add empty label - type pair so the code below works well
	end

	disp (sprintf('rP_read_datafile: reading file %s...',file)); fflush (stdout);
	t = [];	OBJKEY = TYPEKEY = DATA = {};
	line = fgetl (fid); k = 1;
	while line != -1
		% parse line (format: "TIMESTAMP OBJECT-KEY TYPE-KEY: ...DATA...")
		l = strsplit (line,': '); % split time / data keys from data part
		
		% get TIME, OBJECT, and TYPE parts:
		time_keys = strsplit (l{1},' ');
		t = [ t ; str2num(time_keys{1}) ]; % append time value
		OBJKEY{k}  = time_keys{2}; % label of the ruediPy object that sent the data to the data file
		TYPEKEY{k} = time_keys{3}; % type of data
		
		% get DATA part:
		DATA{k} = l{2};
		
		% read next line:
		line = fgetl (fid); k = k + 1;
	end % while line != -1
	
	% close the file after reading it:
	ans = fclose (fid);
	if ans == -1
		error (sprintf('ruediPy_read_datafile: could not close file %s',file))
	end % ans = fclose(...)
	
	% parse file data into struct object, parse data for each object type
	X.file = file;
	
	O  = unique (OBJKEY);
	NO = length (O); % number of object types in the data file
			
	for i = 1:NO % get data for each of the requested object types
		j = find (strcmp(OBJKEY,O{i})); % find index to lines with object-label = O{i}
		% parse lines j, which have object-label = O{i} and object-type = dict{i,2}
    	
    	% Determine generic object type:
    	k = strcmp ({dict{:,1}},O{i}); % check if O{i} matches any of the non-standard / non-fixed object types
    	if any(k) % 'translate' custom object label to generic object type
    		OTYPE = dict{k,2};
    	else      % no 'translation' needed (or at least assume so, as there is n
    		OTYPE = O{i};
    	end
    	
    	% try to assure Octave compatible field names:
    	O{i} = strrep (O{i},'--','_');
    	O{i} = strrep (O{i},'-','_');
    	O{i} = strrep (O{i},'*','_');
    	O{i} = strrep (O{i},'/','_');
    	
    	% disp (sprintf('*** DEBUG INFO: parsing object-label=%s *** object-type=%s...',O{i},OTYPE))
    	
    	switch toupper(OTYPE)
    		
    		case 'DATAFILE'
    			u = __parse_DATAFILE (TYPEKEY(j),DATA(j),t(j));
    			X = setfield (X,O{i},u); % add DATAFILE data
    		
    		case 'SRSRGA'
    			u = __parse_SRSRGA (TYPEKEY(j),DATA(j),t(j));
    			X = setfield (X,O{i},u); % add SRSRGA data
    		
    		case 'SELECTORVALVE'
    			u = __parse_SELECTORVALVE (TYPEKEY(j),DATA(j),t(j));
    			X = setfield (X,O{i},u); % add SELECTORVALVE data
    		
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% OTHERWISE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    		otherwise
    			warning (sprintf('rP_read_datafile: Unknown object type %s, skipping...',OTYPE))
    		
    	end % switch
	end % for i = ...
end % if / else
end % function


%%%%%%%%%%% HELPER FUNCTIONS (DATA PARSING) %%%%%%%%%%%

function X = __parse_DATAFILE (TYPE,DATA,t) % parse DATAFILE object data
	X = [];
	T  = unique (TYPE);

	for i = 1:length(T)
		j = find (strcmp(TYPE,T{i})); % index to lines with type = T{i}
		tt = t(j); TT = TYPE(j); DD = DATA(j);
		
		% parse line by line
		switch toupper(T{i})
			
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% COMMENT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			case 'COMMENT'
				for k = 1:length(TT)
					
					% timestamp:
					p.epochtime = tt(k);
					
					% comment text:
					p.comment = strtrim (DD{k}); % remove leading and trailing whitespace from s

					% append to COMMENTs:
					if k == 1 % first iteration
						X.COMMENT = p;
					else
						X.COMMENT = [ X.COMMENT p ];
					end
					
				end % for k = ...

			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% OTHERWISE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			otherwise
				warning (sprintf('rP_read_datafile: type = %s unknown for DATAFILE object, skipping...',T{i}))

		end % switch
	end % for i = ...
end % function




function X = __parse_SRSRGA (TYPE,DATA,t) % parse SRSRGA object data
	X = [];
	T  = unique (TYPE);

	for i = 1:length(T)
		j = find (strcmp(TYPE,T{i})); % index to lines with type = T{i}
		tt = t(j); TT = TYPE(j); DD = DATA(j);
		
		% parse line by line
		switch toupper(T{i})
			
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PEAK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			case 'PEAK'
				for k = 1:length(TT)
					
					% timestamp:
					p.epochtime = tt(k);
					
					% split data line entries:
					u = strtrim (strsplit(DD{k},';')); % remove leading and trailing whitespace from s
					
					% mz value:
					l = find (index(u,'mz') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''mz'' field in PEAK data of SRSRGA object data. Using mz = NA...')
						p.mz = NA;
					else
						p.mz = str2num (strsplit(u{l},'='){2});
					end
									
					% intensity value:
					l = find (index(u,'intensity') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''intensity'' field in PEAK data of SRSRGA object data. Using intensity.val = NA and intensity.unit = ''?''...')
						p.intensity.val = NA;
						p.intensity.unit = '?';
					else
						uu = strsplit ( strsplit(strtrim(u{l}),'='){2} , ' ' );
						p.intensity.val  = str2num (uu{1});
						p.intensity.unit = strtrim(uu{2});
					end

					% gate value:
					l = find (index(u,'gate') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''gate'' field in PEAK data of SRSRGA object data. Using gate.val = NA and gate.unit = ''?''...')
						p.gate.val = NA;
						p.gate.unit = '?';
					else
						uu = strsplit ( strsplit(strtrim(u{l}),'='){2} , ' ' );
						p.gate.val  = str2num (uu{1});
						p.gate.unit = strtrim(uu{2});
					end
					
					% detector:
					l = find (index(u,'detector') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''detector'' field in PEAK data of SRSRGA object data. Using detector = ''?''...')
						p.detector = '?';
					else
						p.detector = strtrim (strsplit(u{l},'='){2});
					end
					
					% append to PEAKs:
					if k == 1 % first iteration
						X.PEAK = p;
					else
						X.PEAK = [ X.PEAK p ];
					end
													
				end % for k = ...

			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ZERO %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			case 'ZERO'
				for k = 1:length(TT)
					
					% timestamp:
					p.epochtime = tt(k);
					
					% split data line entries:
					u = strtrim (strsplit(DD{k},';')); % remove leading and trailing whitespace from s
					
					% mz value:
					l = find (index(u,'mz=') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''mz'' field in ZERO data of SRSRGA object data. Using mz = NA...')
						p.mz = NA;
					else
						p.mz = str2num (strsplit(u{l},'='){2});
					end
									
					% mz-offset value:
					l = find (index(u,'mz-offset') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''mz-offset'' field in ZERO data of SRSRGA object data. Using mz = NA...')
						p.mz = NA;
					else
						p.mz = str2num (strsplit(u{l},'='){2});
					end
									
					% intensity value:
					l = find (index(u,'intensity') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''intensity'' field in ZERO data of SRSRGA object data. Using intensity.val = NA and intensity.unit = ''?''...')
						p.intensity.val = NA;
						p.intensity.unit = '?';
					else
						uu = strsplit ( strsplit(strtrim(u{l}),'='){2} , ' ' );
						p.intensity.val  = str2num (uu{1});
						p.intensity.unit = strtrim (uu{2});
					end

					% gate value:
					l = find (index(u,'gate') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''gate'' field in ZERO data of SRSRGA object data. Using gate.val = NA and gate.unit = ''?''...')
						p.gate.val = NA;
						p.gate.unit = '?';
					else
						uu = strsplit ( strsplit(strtrim(u{l}),'='){2} , ' ' );
						p.gate.val  = str2num (uu{1});
						p.gate.unit = strtrim(uu{2});
					end
					
					% detector:
					l = find (index(u,'detector') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''detector'' field in ZERO data of SRSRGA object data. Using detector = ''?''...')
						p.detector = '?';
					else
						p.detector = strtrim (strsplit(u{l},'='){2});
					end
					
					% append to ZEROs:
					if k == 1 % first iteration
						X.ZERO = p;
					else
						X.ZERO = [ X.ZERO p ];
					end
													
				end % for k = ...

			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% SCAN %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			case 'SCAN'
				for k = 1:length(TT)
					
					% timestamp:
					p.epochtime = tt(k);
					
					% split data line entries:
					u = strtrim (strsplit(DD{k},';')); % remove leading and trailing whitespace from s
										
					% mz values:
					l = find (index(u,'mz=') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''mz'' field in SCAN data of SRSRGA object data. Using mz = NA...')
						p.mz = NA;
					else
						p.mz = str2num (strsplit(u{l},'='){2});
					end
					
					% intensity values:
					l = find (index(u,'intensity') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''intensity'' field in SCAN data of SRSRGA object data. Using intensity.val = NA and intensity.unit = ''?''...')
						p.intensity.val = NA;
						p.intensity.unit = '?';
					else
						uu = strrep (strtrim(u{l}),', ',',');
						uu = strsplit ( strsplit(uu,'='){2} , ' ' );						
						p.intensity.val  = str2num (uu{1});
						p.intensity.unit = strtrim (uu{2});
					end

					% gate value:
					l = find (index(u,'gate') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''gate'' field in SCAN data of SRSRGA object data. Using gate.val = NA and gate.unit = ''?''...')
						p.gate.val = NA;
						p.gate.unit = '?';
					else
						uu = strsplit ( strsplit(strtrim(u{l}),'='){2} , ' ' );
						p.gate.val  = str2num (uu{1});
						p.gate.unit = strtrim(uu{2});
					end
					
					% detector:
					l = find (index(u,'detector') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''detector'' field in SCAN data of SRSRGA object data. Using detector = ''?''...')
						p.detector = '?';
					else
						p.detector = strtrim (strsplit(u{l},'='){2});
					end
					
					% append to SCANs:
					if k == 1 % first iteration
						X.SCAN = p;
					else
						X.SCAN = [ X.SCAN p ];
					end
													
				end % for k = ...

			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% OTHERWISE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			otherwise
				warning (sprintf('rP_read_datafile: type = %s unknown for SRSRGA object, skipping...',T{i}))

		end % switch
	end % for i = ...
end % function



function X = __parse_SELECTORVALVE (TYPE,DATA,t) % parse SELECTORVALVE object data
	X = [];
	T  = unique (TYPE);

	for i = 1:length(T)
		j = find (strcmp(TYPE,T{i})); % index to lines with type = T{i}
		tt = t(j); TT = TYPE(j); DD = DATA(j);
		
		% parse line by line
		switch toupper(T{i})
			
			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% PEAK %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			case 'POSITION'
				for k = 1:length(TT)
					
					% timestamp:
					p.epochtime = tt(k);
										
					% split data line entries (there is currently only one single entry for SELECTORVALVE POSITION, but who knows if this might change in the future):
					u = strtrim (strsplit(DD{k},';')); % remove leading and trailing whitespace from s
															
					% position value:
					l = find (index(u,'position') == 1);
					if isempty(l)
						warning ('rP_read_datafile: could not find ''position'' field in POSITION data of SELECTORVALVE object data. Using position = NA...')
						p.position = NA;
					else
						p.position = str2num (strsplit(u{l},'='){2});
					end
										
					% append to POSITIONs:
					if k == 1 % first iteration
						X.POSITION = p;
					else
						X.POSITION = [ X.POSITION p ];
					end
													
				end % for k = ...

			%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% OTHERWISE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
			otherwise
				warning (sprintf('rP_read_datafile: type = %s unknown for SELECTORVALVE object, skipping...',T{i}))

		end % switch
	end % for i = ...
end % function