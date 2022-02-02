function new_preprocessMHA(conf_f)
%Name: new_preprocessMHA.m
%Description: Code to preprocess Insight Meta-Image imaging data for ICC project. Generated
%             based on DataGeneration.m, adapted from preprocessMHA.m Travis Williams
%             2020.
%
%INPUT: conf_f: configuration file for certain variables 
%OUTPUT: bin files of images, cropped to largest tumor size, background set
%       to -1000
%Environment: MATLAB R2021a
%Notes: 
%Author: Katy Scott

    if ischar(conf_f) || isstring(conf_f)
        conf_f = str2func(conf_f);
        options = conf_f();   
    elseif isstruct(conf_f)
        options = conf_f();
    else
       error("Input must be struct or name of .m config file") 
    end
    % For debugging purposes use either of below two
%     options = erasmus_tumors();
%     options = msk_tumor();
    
    % Getting list of MHD tumor files (captures Tumor and tumor)
    baseDirs = dir(strcat(options.ImageLoc, "*umor*.mhd"));
    
    % Counter for loop
    nData = size(baseDirs, 1);
    
    % Recording max height and width for crop/rescaling
    maxHeight = 0;
    maxWidth = 0;
    
    % Initiate container for processed slice images
    procImages = cell(nData, 1);
%     tumorCenters = zeros(nData, 2);
    
    % Reading each individual MHD file to find the max height and width
    % from the images
    for currFile = 1:nData
        fprintf('Computing Size for %i \n', currFile)
        filename = strcat(options.ImageLoc, baseDirs(currFile).name);
        info = mha_read_header(filename);
        vol = single(mha_read_volume(info));
        
        % This particular patient has 740 slices and only 10 of them
        % contain tumor pixels. To prevent MATLAB from crashing during
        % processing, an outer 300 slices are removed (these have been
        % confirmed to not contain the tumor pixels)
        if contains(filename, "ICC_Radiogen_Add28_Tumor")
            vol = vol(:,:,300:600);
        end
        
        % Getting tumor mask to use for finding empty images and the
        % largest tumor dimensions
        maskVol = generateMask(vol);
        
        % Sum the volume by the 3rd dimension to get largest tumour
        % dimensions
        max_tumor_mask = sum(maskVol, 3);
        
        % Sum the rows to get max width
        max_tumor_cols = sum(max_tumor_mask, 1);
        % Find the non-zero elements in the row (edges of largest tumor)
        non_zero_cols = find(max_tumor_cols);
        % Find the distance between the left and right edges of the tumor
        temp_width = non_zero_cols(end) - non_zero_cols(1);
        
        % sum the rows to get max height
        max_tumor_rows = sum(max_tumor_mask, 2);
        % Find the non-zero elements in the column (edges of largest tumor)
        non_zero_rows = find(max_tumor_rows);
        % Find the distance between the upper and lower edges of the tumor
        temp_height = non_zero_rows(end) - non_zero_rows(1);
        
        % Note: might remove this, calculating center in second loop
        % instead
        % Find the center x coordinate of the tumor
%         ctr_x = non_zero_cols(1) + floor(temp_width/2);
%         % Find the center y coordinate of the tumor
%         ctr_y = non_zero_rows(1) + floor(temp_height/2);
%         tumorCenters(currFile,:) = [ctr_x, ctr_y];
        
        % Check if width and height are larger than existing
        if temp_width > maxWidth
            maxWidth = temp_width;
        end
        if temp_height > maxHeight
            maxHeight = temp_height;
        end
        
        % Sum processed volume by 1st and 2nd dimension
        % Result is 1 if tumor pixels in slice, 0 if not
        tumor_marker = sum(maskVol,2);
        tumor_marker = sum(tumor_marker,1);
        tumor_marker = reshape(tumor_marker, [size(tumor_marker,3),1]);
        
        % Finding slice indices that have tumor pixels
%         tumor_slice_ind = tumor_marker > 0;
%         tumor_slice_ind = find(tumor_marker);

        % Selecting out tumor slices
%         tumor_slices = vol(:,:,tumor_slice_ind);
        
        % Storing only tumor slices for cropping
        procImages{currFile} = find(tumor_marker);
        
        clear vol tumor_slices maskVol max_tumor_mask max_tumor_cols max_tumor_rows
    end
    
    % Second loop to crop images based on max height and width
    
    % Want to crop in a square, so take maximum of max height and width
    cropDim = max(maxHeight, maxWidth);
    
    % Image cropping to end up with the tumor piece centered in the image
    % Have to loop over every slice individually and find the center
    for currFile = 1:nData
        fprintf('Cropping images for %i \n', currFile)
        filename = strcat(options.ImageLoc, baseDirs(currFile).name);
        info = mha_read_header(filename);
        vol = double(mha_read_volume(info));
        
        % This particular patient has 740 slices and only 10 of them
        % contain tumor pixels. To prevent MATLAB from crashing during
        % processing, an outer 300 slices are removed (these have been
        % confirmed to not contain the tumor pixels)
        if contains(filename, "ICC_Radiogen_Add28_Tumor")
            vol = vol(:,:,300:600);
        end
       
        tumor_vol = vol(:,:, procImages{currFile});
        tumor_mask = generateMask(tumor_vol);
        [nRows, nCols, nSlice] = size(tumor_vol);
        sliceID = 1; % part of naming the binfile
        clear vol
        % Iterating through each slice of the volume to crop around tumor
        for currSlice = 1:nSlice
            slice_mask = tumor_mask(:,:,currSlice);
            % Find tumor pixels in the slice
            
            % Sum rows to find which columns contain tumor
            slice_cols = sum(slice_mask,1);
            % Find tumor pixels (all non-zero elements)
            tumor_cols = find(slice_cols);
            % Find width of the tumor
            tumor_width = tumor_cols(end) - tumor_cols(1);
            % Find x coordinate of center of the tumor
            ctr_x = tumor_cols(1) + floor(tumor_width/2);
            
            % Sum cols to find which columns contain tumor
            slice_rows = sum(slice_mask,2);
            % Find tumor pixels (all non-zero elements)
            tumor_rows = find(slice_rows);
            % Find height of tumor
            tumor_height = tumor_rows(end) - tumor_rows(1);
            % Find y coordinate of center of tumor
            ctr_y = tumor_rows(1) + floor(tumor_height/2);
            
            % Get top left corner of crop window
            startCol = ctr_x - floor(cropDim/2);
            startRow = ctr_y - floor(cropDim/2);
            
            % Checking if crop window falls outside of image in any
            % direction
            if startRow <= 0
                startRow = 1;
            end
            if startCol <= 0
                startCol = 1;
            end
            if startRow + cropDim > nRows
                startRow = nRows - cropDim;
            end
            if startCol + cropDim > nCols
                startCol = nCols - cropDim;
            end
            
            % Cropping around tumor based on max tumor height and width
            imageCr = imcrop(tumor_vol(:,:,currSlice), [startCol startRow cropDim cropDim]);
            
            % Resize image to desired dimension
%             imageCrR = imresize(imageCr, options.ImageSize);
            
%             figure(1)
%             image(imageCr)
% %             figure(2)
%             image(imageCrR)
            
            % replace background 0s with -1000
%             imageCrRB = imageCrR;
%             imageCrRB(imageCrRB == 0) = -1000;
            
            % Create new file name, drop .mhd, add slice number and .bin
            % suffix
            binFileName = strcat(baseDirs(currFile).name(1:end-4), '_Slice_', num2str(sliceID), '.bin');
            
            % Check if Zero and Thousand directory exists, create if not
%             zero_dir = strcat(options.BinLoc, 'Zero/');
            thous_dir = strcat(options.BinLoc, 'Original/');
%             if ~exist(zero_dir, 'dir')
%                 mkdir(zero_dir)
%             end
            if ~exist(thous_dir, 'dir')
                mkdir(thous_dir)
            end
            
            % Save new image version with zeros background
%             zeroFileID = fopen(strcat(zero_dir, binFileName), 'w');
%             fwrite(zeroFileID, imageCrR, 'double');
%             fclose(zeroFileID);
            
            % Save new image version with -1000 background
            thousFileID = fopen(strcat(thous_dir, binFileName), 'w');
            fwrite(thousFileID, imageCr, 'double');
            fclose(thousFileID);
            
            sliceID = sliceID + 1;
            
            clear imageCr imageCrR rows cols slice_mask slice_rows slice_cols;
            
        end

    end

end