function opt = all_tumors(img_locs, out_loc)
%{
Description: Configuration file for new_preprocessMHA and createCSV for all
labelled tumor images (ICC, HCC, MCRC)
 
INPUT:
    img_locs - N x 2 array of file path pairs of image (liver) and mask 
    (tumor) directories for preprocessing
    out_loc - file path to output image folder

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
    opt.fin_img_size = [221 221];
    
    % Locations of image files for liver image sets
    opt.liver_img_locs = img_locs(:,1);
    % Locations of image files for tumor image sets
    opt.tumor_img_locs = img_locs(:,2);
    
    % Location of bin folder to output tumor image slice set at end of
    % new_preprocessMHA
    opt.bin_loc = out_loc;
    
    % Output CSV setup for createCSV
    opt.CSVname = "../Labels/labelled_tumors.csv";
    opt.CSV_header = {'File', 'Pat_ID', 'Slice_Num', 'Code', 'Time'};
    
    opt.Labels = "../scout_all.xlsx";
    
end