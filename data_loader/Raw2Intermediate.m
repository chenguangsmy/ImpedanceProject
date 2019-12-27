function [iData, IncrState] = Raw2Intermediate( RawDataDir, IncrState)

%    dbstop if error;

    % default path for data_loader module
    %srcdir = [getenv('ROBOTSRC') '/data_loader'];
    srcpath = mfilename('fullpath');
    srcdir = fileparts(srcpath);
    
    % if there is already a path set for data_loader module, use it instead
    check_path = which('Raw2Intermediate', '-all');
    if ~isempty(check_path),  srcdir = fileparts(check_path{:});   end    

    iData = [];
    if (nargin < 2), IncrState = [];  end

    
    if (RawDataDir(end) == '/' || RawDataDir(end) == '\')
        basedir = RawDataDir;
    else
        basedir = [RawDataDir '/'];
    end

    files = dir([basedir '*QL*.bin']);

    if (length(files) >= 1)
   
        filename = {files(1).name};

        % oldest, v1 naming convention
        V1 = regexp(filename, '^.+\.QL\.Trial\d{4}\.\d*\.?bin', 'match');
        if (~isempty(V1{1}))
            addpath([srcdir '/v1']);
            [iData, IncrState] = Raw2Intermediate_v1(RawDataDir, IncrState);
            return;
        end
        % v2 naming convention
        V2 = regexp(filename, '^QL\.Trial\d{4}\.\d*\.?bin', 'match');
        if (~isempty(V2{1}))
            addpath([srcdir '/v2']);
            [iData, IncrState] = Raw2Intermediate_v2(RawDataDir, IncrState);
            return;
        end

        % newest, v3 naming convention
        V3 = regexp(filename, '^QL\.\d{4}\.\d*\.?bin', 'match');
        if (~isempty(V3{1}))
            addpath([srcdir '/v4']);
            [iData, IncrState] = Raw2Intermediate_v4(RawDataDir, IncrState);
            return;
        end

        fprintf('ERROR: unrecognized data file naming convention\n\n');
        return;
    end
    
    fprintf('ERROR: folder does not have enough files\n\n');
