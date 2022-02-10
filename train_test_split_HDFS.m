function train_test_split_HDFS(conf_f)
    % Function to split HDFS bin files of all cancer types into a train and
    % test folder. The split will be 90-10 train-test.
    % First will split into the three cancer types
    % Then will split by censoring
    % Get 90-10 of each censoring type (0/1) 
    % Then combine back together
    % Splitting at the patient level, then using that to move the bin files
    % Also make label sheets for train and test?
    
    % Set random seed so train/test split is the same every time this code
    % is run
    rng('default');
    rng(1);
    
    % Getting variables from configuration file
    if ischar(conf_f)
        conf_f = str2func(conf_f);
        options = conf_f();
    else
        options = conf_f;
    end
    
    % Load in label data for all cancer types
    all_label_data = readtable(options.Labels);
    
    % How many cancer types to split in for loop
    num_canc_types = size(unique(all_label_data.Cancer_Type), 1);
    
%     hcc_labels = readtable("../../Data/HCC_survival_sorted.xlsx");
%     mcrc_labels = readtable("../../Data/TCIA_CRLM_Cases_Final_De-identified");
%     icc_labels = readtable("../../Data/RFS_Scout.xlsx");
    
    % initialize tables to store train and test samples
    trainSet = cell2table(cell(0,4), 'VariableNames', all_label_data.Properties.VariableNames);
    testSet = cell2table(cell(0,4), 'VariableNames', all_label_data.Properties.VariableNames);
    
    % Go through each cancer type to split data
    for idx = 1:num_canc_types
        % Get data for one cancer type
        data = all_label_data(all_label_data.Cancer_Type == idx-1, :);
        
        % Get censored and uncensored data
        data_cen = data(data.HDFS_Code == 0, :);
        data_uncen = data(data.HDFS_Code == 1, :);
        
        % Split censored data into train and test
        [trainInd_cen, testInd_cen] = crossvalind('HoldOut', size(data_cen,1), options.TestSize);
        % Split uncensored data into train and test
        [trainInd_uncen, testInd_uncen] = crossvalind('HoldOut', size(data_uncen,1), options.TestSize);
        
        % Add all training data to main table
        trainSet = [trainSet; data_cen(trainInd_cen, :); data_uncen(trainInd_uncen, :)];
        % Add all testing data to main table
        testSet = [testSet; data_cen(testInd_cen, :); data_uncen(testInd_uncen, :)];    
    end
    
    % Sort the main tables first by cancer type and then alphabetically by
    % ScoutID
    trainSet = sortrows(trainSet, {'Cancer_Type','ScoutID'});
    testSet = sortrows(testSet, {'Cancer_Type', 'ScoutID'});
    
    % Save out the train and test set as spreadsheets
    writetable(trainSet, options.TrainLabels, 'writevariablenames', 1);
    writetable(testSet, options.TestLabels, 'writevariablenames', 1);

    % Move bin files into train and test directories
    bin_file_dir = options.BinLoc;
    bin_files = dir(bin_file_dir);
    bin_files = struct2table(bin_files);
    bin_file_names = natsort(bin_files{:,'name'});
    
    % Make sure new bin file directories exist 
    if ~exist(options.TrainDestination, 'dir')
        mkdir(options.TrainDestination)
    end
    if ~exist(options.TestDestination, 'dir')
        mkdir(options.TestDestination)
    end
    
    for pat_idx=1:size(all_label_data)
        pat_ID = all_label_data.ScoutID{pat_idx};
        pat_ID_u = strcat(pat_ID, '_');
        
        pat_bin_files = contains(bin_file_names, pat_ID_u);
        files_to_move = bin_file_names(pat_bin_files);
        
        if any(contains(trainSet.ScoutID, pat_ID))
            for file_idx = 1:size(files_to_move, 1)
                source = strcat(bin_file_dir, files_to_move{file_idx});
                destination = options.TrainDestination;
                
                copyfile(source, destination)
            end
        elseif any(contains(testSet.ScoutID, pat_ID))
            for file_idx = 1:size(files_to_move, 1)
                source = strcat(bin_file_dir, files_to_move{file_idx});
                destination = options.TestDestination;
                
                copyfile(source, destination)
            end
        end
        
    end
    
end

