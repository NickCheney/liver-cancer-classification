function createCSV_HDFS(conf_f)
% Name: createCSV
% Description: Function to generate CSV file to correspond patients with 
% images and slices from preprocessMHA along with labels for HDFS 
%
% INPUT: 
%   conf_f       -- configuration file for different datasets
%   background   -- either "zeros" or "nans"
%
% OUTPUT:
%   A CSV file containing slice file names, associated patient number,
%   slice number, and labels from conf_f Labels file
%
% Environment: MATLAB R2021a
% Author: Katy Scott
% Adapted from code written by Travis Williams
    
    % Getting variables from configuration file
    if ischar(conf_f)
        conf_f = str2func(conf_f);
        options = conf_f();
    else
        options = conf_f;
    end
    
   
    % use location of bin files with -1000 in background
    bin_dir = options.BinLoc;
    output_fname = options.CSVname;
    out_dir = fileparts(output_fname);
    if ~exist(out_dir, 'dir')
        mdkir(out_dir);
    end

    
    % Get list of all bin files
    bin_files = dir(fullfile(bin_dir, '*.bin'));
    % Have folder as structure, change to table for stuff later on
    imgfiles_allinfo = struct2table(bin_files);
    % Extract file names and sort names alphanumerically, now a cell array
    imgfilenames = natsort(imgfiles_allinfo{:,'name'});
    
    % Load in patient label data as a table
    img_labels = readtable(options.Labels);
   
    % Initialize table to patient data
    patient_all_data = cell2table(cell(0,5), 'VariableNames', options.CSV_header);
    
    for label_idx=1:size(img_labels,1)
        % Get patient ID from label data
        patient_ID = img_labels.ScoutID(label_idx);
        % Add an underscore to the end of the ScoutIDs so that a file name 
        % that ends in 5 is different from one that ends in 50 for substring use
        patient_ID = strcat(patient_ID, '_');
        
        % Find indices of slice files containing that patient ID
        labelled_patient_slice_idx = contains(imgfilenames, patient_ID);
        
        % Get the full image file names of labelled slices
        labelled_imgfilenames = imgfilenames(labelled_patient_slice_idx);
        
        % Count how many slices exist for this patient
        num_slices = size(labelled_imgfilenames,1);
        
        % Put these into a table
        % Copy the RFS and RFS Code for each row that has this patient ID
        
        % Get the RFS labels for the current patient
        patien_HDFS_Code = img_labels.HDFS_Code(label_idx);
        patient_HFS_Time = img_labels.HDFS_Time(label_idx);
        
        % Create cell arrays with the labels repeated for each slice
        slices_pat_num = num2cell(ones(num_slices,1) * label_idx);
        slices_slice_num = num2cell((1:num_slices)');
        slices_RFS_Code = num2cell(round(ones(num_slices,1) * patien_HDFS_Code, 1));
        slices_RFS = num2cell(round(ones(num_slices,1) * patient_HFS_Time, 1));
        
        % Concatenate the slice file names, corresponding labels, and add
        % it to the table to be output at the end
        patient_all_data = [patient_all_data; 
                            labelled_imgfilenames, slices_pat_num, slices_slice_num, slices_RFS_Code, slices_RFS];
    end
    
    writetable(patient_all_data, output_fname, 'writevariablenames', 1);
    
    
end