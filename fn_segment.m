function [ characters ] = fn_segment(eq, showFigs, figNum)
%fn_segment Segment and return characters from binary image
%
%   eq - A binary image [0,1] with desired characters in black, bkgrd white.
%   showFigs - Boolean. If true will show figures with processed output.
%       This includes the inverted binarized image with centroids, convex
%       hull, and bounding box. And figure showing each extracted character
%   figNum - The figure(#) to start at for displayed figures.
%   Returns: A struct containing a matrix of each extracted character and
%   the x/y location of the centroid of that character in the original img.
%
%   Detailed Description: This function will extract individual
%   characters/obects from the passed binary image. It assumes each
%   character has a stroke width of atleast 2-3 pixels and there is a separation
%   between each character of at least 1 pixel. Interioir contours and
%   regions are ignored (e.g. the loops in a B are ignored so it is 1
%   region).
%   If there are multiple objects within a region when extracting mask it
%   will only extract the largest (to handle things like square root where
%   it overlaps multiple objects but it should be the largest.
%   This function simply creates an edge map of the characters (same size
%   as original) and then finds the centroid, convex hull, and bounding
%   boxes which are then used for extraction.
%
%   TODO: Need to measure solidity of all regions over our test set to
%   determine the threshold below which a region is not considered a
%   character.

if nargin == 1
    showFigs = false;
    figNum = 1;
elseif nargin == 2
    figNum = 1;
end

% Threshold for solidity of a region is a character or part of 1
%   Should do a run over our entire test set to determine threshold
th = .3;

% Invert image
eq_inv = ones(size(eq)) - eq;

% Create Edge Map
se = ones(3,3);
exp = imerode(eq_inv, se);
eq_edges = xor(exp, eq_inv);

% Find Centroid for x/y location of each character
s = regionprops(eq_edges, 'Centroid');
ch = regionprops(eq_edges, 'ConvexHull');
bb = regionprops(eq_edges, 'BoundingBox');
% Matrix of centroid locations
loc = cat(1, s.Centroid);
% Matrix of boundingbox corner and sizes
boundingboxes = cat(1, bb.BoundingBox);
% Round to whole pixel values and ensure still contains character for
%   character extraction purposes
boundingboxes = floor(boundingboxes);
boundingboxes(:,3:4) = boundingboxes(:,3:4) + 1;

% Check if entire ConvexHull is inside another Convex Hull
%  What to do with partially in? Ignore for now.
idx = [];
for i = 1:size(loc, 1)
    poly = cat(1, ch(i).ConvexHull);
    x = poly(:,1)';
    y = poly(:,2)';
    % Check if i is inside any other region
    for j = 1:size(ch,1)
        poly = cat(1, ch(j).ConvexHull);
        x_ch = poly(:,1)';
        y_ch = poly(:,2)';
        if((sum(~inpolygon(x,y,x_ch,y_ch)) == 0) && i ~= j)
            % If inside another convex hull check to see if it contains
            % mostly character pixels (0) or background (1). If character, 
            % keep, otherwise discard
            region = eq_inv(boundingboxes(i,2):boundingboxes(i,2)+boundingboxes(i,4),...
                boundingboxes(i,1):boundingboxes(i,1)+boundingboxes(i,3),:);
            sol = regionprops(region,'solidity');
            if(sol.Solidity < th)
                % Mark index to remove
                idx = [idx i];
            end
        end
    end
end
% Remove duplicates
idx = unique(idx);
% Remove found interior points
if(~isempty(idx))
    for i = size(idx,2):-1:1
        loc(idx(i),:)=[];
        ch(idx(i))=[];
        boundingboxes(idx(i),:)=[];
    end
end

% Init struct to contain extracted characters and their x/y locations
characters(size(loc,1)).centroid = [];

% Extract each character from binary image based on bounding boxes
%   If there are issues with overlapping characters into nearby bounding
%   boxes, can use the Convex Hulls to create masks around desired char
for i = 1 : size(loc,1)
    characters(i).centroid = loc(i,:);
    
    % Check if more than 1 object in region, if so only extract largest
    %   Assume largest is like the sqrt, etc and the others will be
    %   extracted with other centroids
    region = eq_inv(boundingboxes(i,2):boundingboxes(i,2)+boundingboxes(i,4),...
        boundingboxes(i,1):boundingboxes(i,1)+boundingboxes(i,3),:);
    objects = bwconncomp(region);
    if(size(objects.PixelIdxList,2) > 1)
        numPixels = cellfun(@numel,objects.PixelIdxList);
        [~,idx] = max(numPixels);
       % Select largest object and set other values to 1 and largest object
       % region to 0
       region(:) = 1;
       region(objects.PixelIdxList{idx}) = 0;
       characters(i).char = region;
    else
        characters(i).char = eq(boundingboxes(i,2):boundingboxes(i,2)+boundingboxes(i,4),...
        boundingboxes(i,1):boundingboxes(i,1)+boundingboxes(i,3),:);
    end
end

%% Only show figures if boolean passed to show them
if showFigs
    % Plot centroids, bounding boxes, convex hulls on image
    figure(figNum);
    imshow(eq_edges);
    for i = 1:size(loc, 1) % Assumes same # centroid and convex hull
        % Plot centroids
        x = loc(i,1);
        y = loc(i,2);
        text(x, y, '*' ,'Color', 'yellow', 'FontSize', 14);
        % Plot Convex Hull
        poly = cat(1, ch(i).ConvexHull);
        x = poly(:,1)';
        y = poly(:,2)';
        hold on;
        plot([x x(1)],[y y(1)],'r-');
        hold off;
        % Plot Bounding Box
        rectangle('position',boundingboxes(i,:),'Edgecolor','g')
    end

    % Show all extracted characters
    figure(figNum + 1);
    for i =1:size(characters,2)
       subplot(2,ceil(size(characters,2)/2),i);
       imshow(characters(i).char);
    end
end

end

