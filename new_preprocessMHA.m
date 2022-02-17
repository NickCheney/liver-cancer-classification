function new_preprocessMHA(conf_f)
%Name: new_preprocessMHA.m
%Description: Code to preprocess Insight Meta-Image imaging data for ICC project. Generated
%             based on DataGeneration.m, adapted from preprocessMHA.m Travis Williams
%             2020.
%
%INPUT: conf_f: configuration file for certain variables 
%OUTPUT: bin files of liver images, cropped patient by patient by largest
%        liver dimensions
%Environment: MATLAB R2022a
%Notes:         
%Author: Katy Scott
%Last Edited by: Nick Cheney

    if ischar(conf_f) || isstring(conf_f)
        conf_f = str2func(conf_f);
        options = conf_f();   
    elseif isstruct(conf_f)
        options = conf_f();
    else
       error("Input must be struct or name of .m config file") 
    end

    
    % Getting list of MHD liver files
    mhd_liver_fpaths = dir(strcat(options.img_loc, "*/*/*iver*.mhd"));

    % get column of liver file full and base names
    liver_base_names = {mhd_liver_fpaths.name}';
    liver_full_names= strcat({mhd_liver_fpaths.folder}', '\', liver_base_names);

    % get column of liver file cancer types
    liver_fname_comps = cellfun(@(x) split(x,"\"), liver_full_names, 'UniformOutput', false);
    cancer_types = cellfun(@(x) x{end-2}, liver_fname_comps, 'UniformOutput', false);

    %get column of unique liver file name keys
    key = cell(size(liver_full_names,1),1);
    for i=1:size(key,1)
        ctype = cancer_types{i};
        fname = liver_base_names{i};

        if strcmp(ctype,'ICC')
            key{i} = [ctype fname(1:end-20)];
        else
            key{i} = [ctype fname(1:3)];
        end
    end
    % create table of liver files
    liver_table = table(liver_full_names, cancer_types, key);

    % Getting list of MHD tumor files
    mhd_tumor_fpaths = dir(strcat(options.img_loc, "*/*/*umor*.mhd"));

    % get column of tumor file full and base names
    tumor_base_names = {mhd_tumor_fpaths.name}';
    tumor_full_names= strcat({mhd_tumor_fpaths.folder}', '\', tumor_base_names);

    % get column of tumor file cancer types
    tumor_fname_comps = cellfun(@(x) split(x,"\"), tumor_full_names, 'UniformOutput', false);
    cancer_types = cellfun(@(x) x{end-2}, tumor_fname_comps, 'UniformOutput', false);

    %get column of tumor keys matching liver file keys
    key = cell(size(tumor_full_names,1),1);
    for i=1:size(key,1)
        ctype = cancer_types{i};
        fname = tumor_base_names{i};

        if strcmp(ctype,'ICC')
            key{i} = [ctype fname(1:end-10)];
        else
            key{i} = [ctype fname(1:3)];
        end
    end

    % create table of tumor files
    tumor_table = table(tumor_full_names, cancer_types, key);

    % inner join tables to map liver to tumor files
    mapped_images = innerjoin(liver_table,tumor_table);

    % Discard tumor images without liver reference images
    discarded = setdiff(tumor_full_names,mapped_images.tumor_full_names);
    if size(discarded,1) > 0
        fprintf("Discarding %d tumor files without liver references:\n", size(discarded,1));
        fprintf("%s\n", discarded{:});
        for i=1:size(discarded,1)
            delete(discarded{i});
        end
    end
    
    % Record final liver image names for masking and cropping
    final_liver_names = unique(mapped_images.liver_full_names);
    
    % to pad edges of liver slices so they don't touch borders
    pad = 5;

    % to count files processed of each type
    HCC_count = 1;
    ICC_count = 1;
    MCRC_count = 1;

    % ensure output folder exists
    if ~exist(options.bin_loc,"dir")
        mkdir(options.bin_loc);
    end

    % Loop through tumor images, mask, crop and save
    for i = 1:size(final_liver_names,1)
        fprintf("Processing liver image %d/%d\n",i,size(final_liver_names,1));
        % get liver volume
        liver_fname = final_liver_names{i};
        info = mha_read_header(liver_fname);
        liver_vol = single(mha_read_volume(info));

        vol = liver_vol;

        % IMAGE MASKING

        % get associated tumor file names
        liver_rows = mapped_images(strcmp(mapped_images.liver_full_names,liver_fname),:);
        tumor_fnames = liver_rows.tumor_full_names;
        
        % initialize empty mask
        tumor_mask = false(size(liver_vol));

        % add each masked tumor vol
        for j=1:size(tumor_fnames)
            % get vol
            info = mha_read_header(tumor_fnames{j});
            tumor_vol = single(mha_read_volume(info));
            % get mask
            new_mask = generateMask(tumor_vol,false);
            % combine with cumulative mask
            tumor_mask = tumor_mask | new_mask;
        end
        
        % invert mask and make numerical
        tumor_mask = ~tumor_mask;
        % mask image
        liver_vol = (liver_vol+1000).*tumor_mask - 1000;

        
        % IMAGE CROPPING

        % Flatten slices into single image
        flat_image = sum(liver_vol+1000,3);
        % flatten along different axis
        flat_image2 = sum(liver_vol+1000,1);

        % get max and min indices of non-zero elements for each axis

        % rows
        r_start=min(find(sum(flat_image,2)));
        r_end=max(find(sum(flat_image,2)));

        % cols
        c_start=min(find(sum(sum(flat_image,3))));
        c_end=max(find(sum(sum(flat_image,3))));

        % pages
        p_start = min(find(sum(flat_image2)));
        p_end = max(find(sum(flat_image2)));

        % make image square
        height = r_end - r_start;
        width = c_end - c_start;
        if height > width
            c_start = c_start - round((height-width)/2);
            c_end = c_start + height;
        else
            r_start = r_start - round((width-height)/2);
            r_end = r_start + width;
        end

        % uncomment to verify masking and cropping worked
        %{
        desired_image = 556;
        if i == desired_image
            for j=1:size(liver_vol,3)
                if sum(~tumor_mask(:,:,j),'all') > 0
                    figure; 
                    subplot(2,2,1), imshow(liver_vol(r_start-pad:r_end+pad,c_start-pad:c_end+pad,j));
                    subplot(2,2,2), imshow(vol(r_start-pad:r_end+pad,c_start-pad:c_end+pad,j));
                    subplot(2,2,3), imshow(~tumor_mask(r_start-pad:r_end+pad,c_start-pad:c_end+pad,j));
                end
    
            end
        end
        %}
        liver_vol = liver_vol(r_start-pad:r_end+pad,c_start-pad:c_end+pad,p_start:p_end);

        % resize image for consistancy
        liver_vol = int16(imresize(liver_vol,options.fin_img_size));

        % SAVE IMAGE
        ctype = liver_rows.cancer_types{1};

        if strcmp(ctype,'HCC')
            cnum = num2str(HCC_count);
            HCC_count = HCC_count + 1;
        elseif strcmp(ctype, 'ICC')
            cnum = num2str(ICC_count);
            ICC_count = ICC_count + 1;
        else
            cnum = num2str(MCRC_count);
            MCRC_count = MCRC_count + 1;
        end

        out_ID = strcat(ctype, '_', cnum);

        for slice=1:size(liver_vol,3)
            out_fname = strcat(options.bin_loc, out_ID, '_', num2str(slice),'.bin');
            out_file = fopen(out_fname,'w');
            fwrite(out_file,liver_vol(:,:,slice),'int16');
            fclose(out_file);
        end
    end
    
    %{
    % Counter for loop
    nData = size(mhd_tumor_fpaths, 1);
    
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
        filename = strcat(options.img_loc, mhd_tumor_fpaths(currFile).name);
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
            
            figure(1)
            image(imageCr)
            figure(2)
            image(imageCrR)
            
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
    %}
end