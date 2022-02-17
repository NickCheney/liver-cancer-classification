%{
Script to run all preprocessing steps to generate model input data
Author: Nick Cheney
Date: 2022-02-08
%}

% Generate config struct
config = all_tumors();

% Run image preprocessing
new_preprocessMHA(config);

% Generate CSV labelling file
% createCSV_HDFS(config);

% split into training and testing data
% train_test_split_HDFS;