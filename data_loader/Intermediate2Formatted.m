function [Data, IncrState] = Intermediate2Formatted( iData, IncrState)

    dbstop if error;

    % default path for data_loader module
    srcdir = [getenv('ROBOTSRC') '/data_loader'];
    
    % if there is already a path set for data_loader module, use it instead
    check_path = which('Intermediate2Formatted', '-all');
    if ~isempty(check_path),  srcdir = fileparts(check_path{:});   end

    Data = [];
    if (nargin < 2)
        IncrState = [];
    end

    if ~isfield(iData, 'Version')
        error('ERROR: intermediate data does not have a ''Version'' field');
    else
        func = ['Intermediate2Formatted_' iData.Version];
        if ~exist(func)
            
            avail_ver = dir([srcdir '/v*']);
            avail_ver = {avail_ver.name};
            
            if ~isempty(find(strcmp(iData.Version, avail_ver)==1))
                addpath([srcdir '/' iData.Version]);
            else
                error('ERROR: unknown intermediate data version');
            end
        end
    end

    [Data, IncrState] = feval( func, iData, IncrState);
    
