function intMask = generateMask(I)
% Function to generate a binary int8 mask for segmented tissue in an image
% Input: I = volume to generate mask for, height x width x slices, single type
% Output: intMask = mask of soft tissue (tumor, liver, etc.), 1s = tissue,
%                   0s = background, int8 type
    % Generate mask excluding values outside of this range (Hounsfield
    % units)
    % This range includes only soft tissue
    Imask = I<-100|I>300;
    % Flips black and white in the mask
    ImaskInv = ~(Imask);
    % Clear variables to save memory
    clear Imask I
    % Generate numeric mask so arithmetic can be used
    intMask = int8(ImaskInv);
end