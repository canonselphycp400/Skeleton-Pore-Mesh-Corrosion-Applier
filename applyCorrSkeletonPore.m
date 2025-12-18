function applyCorrSkeletonPore_COMPLETE()
    % --- Configuration ---
    mainFilePath = 'pari_s1_sklt.dat';
    corrosionFilePath = 'corrosion_setting.txt';
    outputFilePath = 'pari_s1_sklt_corr.dat';

    fprintf('--- Starting Fixed-Width Processing ---\n');

    % ---------------------------------------------------------
    % STEP 1: LOAD CORROSION SETTINGS (FIXED WIDTH PARSING)
    % ---------------------------------------------------------
    try
        if ~exist(corrosionFilePath, 'file'), error('Settings file not found.'); end
        
        fid = fopen(corrosionFilePath, 'r');
        % Skip the first header line "247 :(I10)..."
        fgetl(fid); 
        
        keys = [];
        values = [];
        lineNum = 1;
        
        while ~feof(fid)
            line = fgetl(fid);
            lineNum = lineNum + 1;
            
            % Ensure line is long enough to contain data
            if length(line) >= 11
                % FIXED WIDTH PARSING
                % Columns 1-10: ID
                % Columns 11-End: Value
                idStr = line(1:10);
                valStr = line(11:end);
                
                idVal = str2double(idStr);
                corrVal = str2double(valStr);
                
                if ~isnan(idVal) && ~isnan(corrVal)
                    keys(end+1) = idVal;     %#ok<AGROW>
                    values(end+1) = corrVal; %#ok<AGROW>
                end
            end
        end
        fclose(fid);
        
        % Create the Map
        corrosionMap = containers.Map(keys, values);
        fprintf('Configuration: Successfully loaded %d corrosion rules.\n', length(keys));
        
    catch ME
        if exist('fid', 'var') && fid ~= -1, fclose(fid); end
        error('Error reading settings file: %s', ME.message);
    end

    % ---------------------------------------------------------
    % STEP 2: PROCESS MAIN FILE (FIXED WIDTH PARSING)
    % ---------------------------------------------------------
    try
        inputFileID = fopen(mainFilePath, 'r');
        outputFileID = fopen(outputFilePath, 'w');
        
        changesMade = 0;
        lineCount = 0;
        
        while ~feof(inputFileID)
            line = fgetl(inputFileID);
            lineCount = lineCount + 1;
            
            % 1. Check for PORE0 tag
            % We look for "PORE0" specifically.
            idx = strfind(line, 'PORE0');
            
            if ~isempty(idx)
                % Found PORE0. The ID is strictly the NEXT 5 characters.
                % PORE0 is 5 chars long.
                startCol = idx(1) + 5; 
                endCol   = startCol + 4; % Total 5 chars for ID
                
                % Ensure line has enough characters for the ID
                if length(line) >= endCol
                    rawIDStr = line(startCol:endCol);
                    elementID = str2double(rawIDStr);
                    
                    % 2. Look up ID in our loaded Map
                    if ~isnan(elementID) && isKey(corrosionMap, elementID)
                        valueToInsert = corrosionMap(elementID);
                        
                        % 3. Modify the CURRENT Line
                        % Format: 10 chars wide, 6 decimal places (e.g. "  0.123456")
                        newValueStr = sprintf('%10.6f', valueToInsert);
                        
                        % Target Columns: 41-50
                        if length(line) >= 50
                            line = [line(1:40), newValueStr, line(51:end)];
                            changesMade = changesMade + 1;
                        else
                             fprintf('WARNING Line %d (ID %d): Line too short to update.\n', lineCount, elementID);
                        end
                    end
                end
            end
            
            % 4. Write Line to Output
            fprintf(outputFileID, '%s\n', line);
        end
        
        fclose(inputFileID);
        fclose(outputFileID);
        
        % Final Report
        fprintf('--- Finished ---\n');
        fprintf('Success: %d values updated out of %d loaded settings.\n', changesMade, length(keys));
        fprintf('Output saved to %s\n', outputFilePath);
        
    catch ME
        if exist('inputFileID', 'var') && inputFileID ~= -1, fclose(inputFileID); end
        if exist('outputFileID', 'var') && outputFileID ~= -1, fclose(outputFileID); end
        rethrow(ME);
    end
end