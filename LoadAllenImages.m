%% Loading the Allen Reference
SectionsPath = '/Users/Priyanka/Desktop/github_local/Allen_PG/AllenSections_AON_APC.mat';
AllenImages = load(SectionsPath);

% loads 30 sections, 368 x 553

figure;
t = tiledlayout(6,5);
t.TileSpacing = 'none';
t.Padding = 'none';

for i = 1:size(AllenImages.Sections,1)
    nexttile;
    image(squeeze(AllenImages.Sections(i,:,:,:)));
    set(gca,'XTick',[],'YTick',[]);
end

%% Loading the Lesion Images
folder = '/Users/Priyanka/Desktop/LABWORK_II/Data/Images/Q9';
% Get image list
files = dir(fullfile(folder,'Image *.tif'));
num_images = min(length(files),30);   % grid fits 25
contrast_limits = [0.0 0.9];        % [] = auto, or [low high] like [100 2000]

figure;
% Tight layout
q = tiledlayout(6,5);
q.TileSpacing = 'none';
q.Padding = 'none';

for i = 1:num_images

    img = imread(fullfile(folder,files(i).name)); % Read image
    img = im2double(img); % Convert to double for scaling if needed
    nexttile;
    if isempty(contrast_limits)
        imshow(img,[])
    else
        imshow(img,contrast_limits)
    end

end

%%
%function [] = findSymmetry()
% Load image
%img = imread('Image_000001.tif');
img = imread(fullfile(folder,files(10).name)); % Read image
if size(img, 3) > 1
    gray = rgb2gray(img);
else
    gray = img;
end
gray_norm = mat2gray(double(gray));

% --- MASK ---
thresh = graythresh(gray_norm) * 0.5;
mask = gray_norm > thresh;
mask = imfill(mask, 'holes');
mask = bwareaopen(mask, 5000);
mask = imclose(mask, strel('disk', 20));

cc = bwconncomp(mask);
numPixels = cellfun(@numel, cc.PixelIdxList);
[~, idx] = max(numPixels);
mask_clean = false(size(mask));
mask_clean(cc.PixelIdxList{idx}) = true;

% --- BOUNDS ---
props = regionprops(mask_clean, 'BoundingBox', 'Centroid');
bbox = props.BoundingBox;
left   = bbox(1);
top    = bbox(2);
right  = bbox(1) + bbox(3);
bottom = bbox(2) + bbox(4);

% --- MIDLINE 1: Centroid-based ---
midline_centroid = props.Centroid(1);

% --- MIDLINE 2: Symmetry-based ---
% For each row, find leftmost and rightmost brain pixel
% Midline = average of those two columns per row, then median across rows
[rows, cols] = find(mask_clean);
row_ids = unique(rows);
mid_per_row = zeros(length(row_ids), 1);
for i = 1:length(row_ids)
    r = row_ids(i);
    row_cols = cols(rows == r);
    mid_per_row(i) = (min(row_cols) + max(row_cols)) / 2;
end
midline_symmetry = median(mid_per_row);

fprintf('Bounds:\n  Left:   %.1f px\n  Right:  %.1f px\n  Top:    %.1f px\n  Bottom: %.1f px\n', ...
    left, right, top, bottom);
fprintf('Midline (centroid):  %.1f px\n', midline_centroid);
fprintf('Midline (symmetry):  %.1f px\n', midline_symmetry);
fprintf('Difference: %.1f px\n', abs(midline_centroid - midline_symmetry));

% --- VISUALIZE ---
figure;
imshow(gray_norm, []);
hold on;
rectangle('Position', bbox, 'EdgeColor', 'g', 'LineWidth', 2);
line([midline_centroid midline_centroid], [top bottom], ...
    'Color', 'r', 'LineWidth', 2, 'LineStyle', '-');
line([midline_symmetry midline_symmetry], [top bottom], ...
    'Color', 'c', 'LineWidth', 2, 'LineStyle', '--');
legend('', 'Bounds', 'Centroid midline', 'Symmetry midline', ...
    'Location', 'southoutside');
title('Midline: centroid (red solid) | symmetry (cyan dashed)');
%end