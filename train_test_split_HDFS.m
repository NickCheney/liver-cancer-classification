function train_test_split_HDFS
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
    
    % Load in label data for all cancer types
    all_label_data = readtable("../HDFS_Scout_all.xlsx");
    
%     hcc_labels = readtable("../HCC_survival_sorted.xlsx");
%     mcrc_labels = readtable("../TCIA_CRLM_Cases_Final_De-identified");
%     icc_labels = readtable("../RFS_Scout.xlsx");
    
    % initialize tables to store train and test samples
    trainSet = cell2table(cell(0,4), 'VariableNames', all_label_data.Properties.VariableNames);
    testSet = cell2table(cell(0,4), 'VariableNames', all_label_data.Properties.VariableNames);
    
    % Go through each cancer type to split data
    for idx = 1:3
        % Get data for one cancer type
        data = all_label_data(all_label_data.Cancer_Type == idx-1, :);
        
        % Get censored and uncensored data
        data_cen = data(data.HDFS_Code == 0, :);
        data_uncen = data(data.HDFS_Code == 1, :);
        
        % Split censored data into train and test
        [trainInd_cen, testInd_cen] = crossvalind('HoldOut', size(data_cen,1), 0.1);
        % Split uncensored data into train and test
        [trainInd_uncen, testInd_uncen] = crossvalind('HoldOut', size(data_uncen,1), 0.1);
        
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
    writetable(trainSet, "../../Data/HDFS_train_labels.xlsx", 'writevariablenames', 1);
    writetable(testSet, "../../Data/HDFS_test_labels.xlsx", 'writevariablenames', 1);

    % Move bin files into train and test directories
    bin_file_dir = "../../Data/Images/Labelled_Tumors/220/Original/";
    bin_files = dir(bin_file_dir);
    bin_files = struct2table(bin_files);
    bin_file_names = natsort(bin_files{:,'name'});
    
    for pat_idx=1:size(all_label_data)
        pat_ID = all_label_data.ScoutID{pat_idx};
        pat_ID_u = strcat(pat_ID, '_');
        
        pat_bin_files = contains(bin_file_names, pat_ID_u);
        files_to_move = bin_file_names(pat_bin_files);
        
        if any(contains(trainSet.ScoutID, pat_ID))
            for file_idx = 1:size(files_to_move, 1)
                source = strcat(bin_file_dir, files_to_move{file_idx});
                destination = "../../Data/Images/Labelled_Tumors/220/train";
                
                copyfile(source, destination)
            end
        elseif any(contains(testSet.ScoutID, pat_ID))
            for file_idx = 1:size(files_to_move, 1)
                source = strcat(bin_file_dir, files_to_move{file_idx});
                destination = "../../Data/Images/Labelled_Tumors/220/test";
                
                copyfile(source, destination)
            end
        end
        
    end
    
end

