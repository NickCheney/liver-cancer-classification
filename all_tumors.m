function opt = all_tumors
%{
Description: Configuration file for new_preprocessMHA and createCSV for all
labelled tumor images (ICC, HCC, MCRC)
 
INPUT:
    None

 OUTPUT: 
    opt - struct containing variables defined here

Environment: MATLAB R2022a
Author: Nick Cheney
Edited: 2022-02-10
Adapted from code written by Katy Scott
%}
    % Dimensions for image resize step
    % (32 x 32 is for LeNet)
    % (299 x 299 is Inception requirement)
    % (1024 x 1024 is DeepConvSurv requirement)
    opt.fin_img_size = [256 256];
    
    % record image folder locations
    opt.img_loc = "../Images/";
    
    % Location of bin folder to output tumor image slice set at end of
    % new_preprocessMHA
    opt.bin_loc = "../Images/bin/";
    
    % Output CSV setup for createCSV
    opt.CSVname = "../Labels/labelled_tumors.csv";
    opt.CSV_header = {'File', 'Pat_ID', 'Slice_Num', 'Cancer_Type'};
    
    opt.Labels = "../scout_all.xlsx";
    
end