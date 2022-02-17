function mask = generateMask(I,numeric)
% Function to generate a binary int8 mask for segmented tissue in an image
% Input: I = volume to generate mask for, height x width x slices, single type
%        numeric = flag to determine output type, numeric if true, logical
%        otherwise
% Output: intMask = mask of soft tissue (tumor, liver, etc.), 1s = tissue,
%                   0s = background, int8 type
    % Generate mask excluding values outside of this range (Hounsfield
    % units)
    % This range includes only soft tissue
    mask = ~(I<-100|I>300);

    if numeric
        % Generate numeric mask so arithmetic can be used
        mask = int8(mask);
    end
end