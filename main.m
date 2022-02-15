%{
Script to run all preprocessing steps to generate model input data
Author: Nick Cheney
Date: 2022-02-08
%}

%rename files with a standard convention

base_path = "../Images/";
% start with HCC liver images
path = base_path+"HCC/liver/";
for file = {dir(path+"*liver*").name}
    f_name = path+file{1};
    f_name_comps = split(file{1}, ["-",".","_"]);
    scout_ID = f_name_comps(1);
    ext = f_name_comps(end);
    f_name_new = path+scout_ID+"_HCC_liver."+ext;
    
    
    if f_name ~= f_name_new
        % need to change file name
        fprintf("Moving "+f_name+" to "+f_name_new+"\n");
        movefile(f_name, f_name_new);

        if ext == "mhd"
            % change the mhd target accordingly
            change_mhd_target(f_name_new);
        end

    end    
end


% Then HCC tumor images
path = base_path+"HCC/tumors/";
for file = {dir(path+"*umor*").name}
    f_name = path+file{1};
    f_name_comps = split(file{1}, ["-",".","_"]);
    scout_ID = f_name_comps(1);
    ext = f_name_comps(end);

    
    % check if tumor is numbered
    if ~isnan(str2double(f_name_comps{end-1}(end)))
        number = f_name_comps{end-1}(end);
    else
        number = '1';
    end
    
    f_name_new = path+scout_ID+"_HCC_tumor_"+number+"."+ext;

    if f_name ~= f_name_new
        % need to change file name
        fprintf("Moving "+f_name+" to "+f_name_new+"\n");
        movefile(f_name, f_name_new);
    end

    
    if ext == "mhd"
        % change the mhd target accordingly
        change_mhd_target(f_name_new);
    end
    
end


%{
% Generate config struct
config = all_tumors;

% Run image preprocessing
new_preprocessMHA(config);

% Generate CSV labelling file
createCSV_HDFS(config);

% split into training and testing data
train_test_split_HDFS;
%}