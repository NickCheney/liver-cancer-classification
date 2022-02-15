function change_mhd_target(mhd_name, new_target)
    %{
    Name: change_mhd_target
    Description: Function to change the value of ElementDataFile in any mhd
    file
    
    INPUT: 
        mhd_name - the full name (file path included) of the .mhd file to 
        modify

        new_target (optional) - the new value of ElementDataFile, assumed
        to be the same as the mhd file (with .raw extension) if not
        provided
    
    OUTPUT:
        None
    
    Environment: MATLAB R2022a
    Author: Nick Cheney
    %}

    if ~exist("new_target","var")
        name_comps = split(mhd_name, [".","/"]);
        new_target = [name_comps{end-1}, '.raw'];
    end

    mhd = fopen(mhd_name,'r');
    mhd_arr = splitlines(fscanf(mhd,"%c"));
    fclose(mhd);
    mhd_arr{end-1} = ['ElementDataFile = ', new_target];
    mhd = fopen(mhd_name,'w');
    out_txt = strjoin(mhd_arr,newline);
    fprintf(mhd,"%s",out_txt);
    fclose(mhd);
    
    clear new_target;
end