function ProcessAllenAtlas(atlas_folder)
% Processes high-res Allen Atlas JPG files to extract:
%   - AP coordinate (from filename e.g. 103_2-445.jpg -> 2.445mm)
%   - Midline (from cyan vertical line)
%   - Scale (pixels/mm, from ruler tick marks, computed once)
%   - Brain bounds (from white background detection, mirrored)
% Results saved to AllenBounds.mat in atlas_folder
% If AllenBounds.mat exists, loads and skips already-processed images
%
% Usage: ProcessAllenAtlas('/path/to/atlas/folder')

if nargin < 1
    atlas_folder = uigetdir(pwd, 'Select Atlas Folder');
    if isequal(atlas_folder,0), return; end
end

mat_file = fullfile(atlas_folder, 'AllenBounds.mat');

% Load existing results if available
if isfile(mat_file)
    fprintf('Loading existing AllenBounds.mat...\n');
    data = load(mat_file);
    results = data.results;
    fprintf('  Found %d existing entries.\n', length(results));
else
    results = struct('filename',{},'ap_mm',{},'midline',{},...
        'px_per_mm',{},'left',{},'right',{},'top',{},'bottom',{});
end

% Get all JPG files
d = dir(fullfile(atlas_folder,'*.jpg'));
if isempty(d)
    d = dir(fullfile(atlas_folder,'*.JPG'));
end
if isempty(d)
    error('No JPG files found in %s', atlas_folder);
end

% Sort by AP coordinate
filenames = {d.name};
ap_vals   = zeros(1,length(filenames));
for i = 1:length(filenames)
    ap_vals(i) = parse_ap(filenames{i});
end
[ap_vals, sort_idx] = sort(ap_vals);
filenames = filenames(sort_idx);

fprintf('Found %d JPG files.\n', length(filenames));

% Check which files already processed
existing_files = {};
if ~isempty(results)
    existing_files = {results.filename};
end

% --- Scale: compute from first unprocessed image (or reuse) ---
px_per_mm = [];
if ~isempty(results) && isfield(results(1),'px_per_mm')
    px_per_mm = results(1).px_per_mm;
    fprintf('Reusing scale: %.2f px/mm\n', px_per_mm);
end

% Find files that need processing
to_process = find(~ismember(filenames, existing_files));
if isempty(to_process)
    fprintf('All files already processed.\n');
    % Still open viewer
    view_results(atlas_folder, results, filenames, ap_vals);
    return;
end

fprintf('Processing %d new files...\n', length(to_process));

% Compute scale from first new file if not already known
if isempty(px_per_mm)
    fprintf('Computing scale from %s...\n', filenames{to_process(1)});
    img = imread(fullfile(atlas_folder, filenames{to_process(1)}));
    px_per_mm = detect_scale(img);
    fprintf('  Scale: %.2f px/mm\n', px_per_mm);
    
    % Verify on next 2 files if available
    for vi = 2:min(3,length(to_process))
        img2 = imread(fullfile(atlas_folder, filenames{to_process(vi)}));
        px2  = detect_scale(img2);
        fprintf('  Verify on %s: %.2f px/mm\n', filenames{to_process(vi)}, px2);
    end
end

% Process each new file
for fi = 1:length(to_process)
    idx  = to_process(fi);
    fname = filenames{idx};
    ap    = ap_vals(idx);
    fprintf('Processing %s (AP=%.3f mm)...\n', fname, ap);

    img = imread(fullfile(atlas_folder, fname));

    % Midline from cyan line
    midline = detect_midline(img);
    fprintf('  Midline: %d px\n', midline);

    % Brain bounds
    [left,right,top,bottom] = detect_bounds(img, midline);
    fprintf('  Bounds: L=%d R=%d T=%d B=%d\n', left,right,top,bottom);

    % Store result
    new_entry.filename  = fname;
    new_entry.ap_mm     = ap;
    new_entry.midline   = midline;
    new_entry.px_per_mm = px_per_mm;
    new_entry.left      = left;
    new_entry.right     = right;
    new_entry.top       = top;
    new_entry.bottom    = bottom;
    results(end+1)      = new_entry;
end

% Sort results by AP
ap_list = [results.ap_mm];
[~,si]  = sort(ap_list);
results = results(si);

% Save
save(mat_file, 'results');
fprintf('Saved %d entries to %s\n', length(results), mat_file);

% Open viewer
view_results(atlas_folder, results, filenames, ap_vals);
end

% =========================================================================
%  VIEWER
% =========================================================================
function view_results(atlas_folder, results, filenames, ap_vals)
if isempty(results)
    fprintf('No results to view.\n');
    return;
end

hFig = figure('Name','Allen Atlas Bounds Viewer','NumberTitle','off',...
    'Position',[50 50 1000 800],'Color',[0.15 0.15 0.15]);
set(hFig,'Toolbar','none');

hAx = axes(hFig,'Position',[0.02 0.12 0.96 0.82],'Color','k');

state.results      = results;
state.atlas_folder = atlas_folder;
state.idx          = 1;
state.n            = length(results);
setappdata(hFig,'state',state);
setappdata(hFig,'handles',struct('ax',hAx));

% Panel
uipanel(hFig,'Units','normalized','Position',[0 0 1 0.11],...
    'BackgroundColor',[0.15 0.15 0.15]);

uicontrol(hFig,'Style','pushbutton','String','< Prev',...
    'Units','normalized','Position',[0.01 0.03 0.08 0.07],...
    'Callback',@(~,~) viewer_nav(hFig,-1));
uicontrol(hFig,'Style','pushbutton','String','Next >',...
    'Units','normalized','Position',[0.10 0.03 0.08 0.07],...
    'Callback',@(~,~) viewer_nav(hFig,+1));

uicontrol(hFig,'Style','popupmenu',...
    'Units','normalized','Position',[0.20 0.04 0.20 0.05],...
    'Tag','viewDropdown',...
    'String',arrayfun(@(r) sprintf('AP=%.3f  %s',r.ap_mm,r.filename),...
        results,'UniformOutput',false),...
    'Value',1,...
    'Callback',@(src,~) viewer_dropdown(hFig,src));

uicontrol(hFig,'Style','text','String','Ready.',...
    'Units','normalized','Position',[0.01 0.0 0.98 0.02],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.5 1 0.5],...
    'FontSize',8,'HorizontalAlignment','left','Tag','statusText');

viewer_draw(hFig);
end

function viewer_draw(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');
r     = state.results(state.idx);

img = imread(fullfile(state.atlas_folder, r.filename));

cla(h.ax);
imshow(img,'Parent',h.ax);
hold(h.ax,'on');

% Bounds
rectangle('Parent',h.ax,...
    'Position',[r.left, r.top, r.right-r.left, r.bottom-r.top],...
    'EdgeColor','r','LineWidth',2);

% Midline
line(h.ax,[r.midline r.midline],[r.top r.bottom],...
    'Color',[1 0.5 0],'LineWidth',2);

title(h.ax,sprintf('%s  |  AP=%.3f mm  |  Scale=%.1f px/mm  |  Midline=%d px',...
    r.filename, r.ap_mm, r.px_per_mm, r.midline),...
    'Color','w','FontSize',9);

set(findobj(hFig,'Tag','viewDropdown'),'Value',state.idx);

h2 = findobj(hFig,'Tag','statusText');
if ~isempty(h2)
    set(h2,'String',sprintf('Slice %d/%d  |  AP=%.3fmm  |  L=%d R=%d T=%d B=%d',...
        state.idx, state.n, r.ap_mm, r.left, r.right, r.top, r.bottom));
end
end

function viewer_nav(hFig,dir)
state = getappdata(hFig,'state');
state.idx = max(1, min(state.n, state.idx+dir));
setappdata(hFig,'state',state);
viewer_draw(hFig);
end

function viewer_dropdown(hFig,src)
state = getappdata(hFig,'state');
state.idx = src.Value;
setappdata(hFig,'state',state);
viewer_draw(hFig);
end

% =========================================================================
%  DETECT MIDLINE (cyan vertical line)
% =========================================================================
function midline = detect_midline(img)
r = double(img(:,:,1));
g = double(img(:,:,2));
b = double(img(:,:,3));

% Cyan: high G and B, low R
cyan_mask = (g > 150) & (b > 150) & (r < 120);

% Find column with most cyan pixels
col_sums = sum(cyan_mask, 1);
midline  = find(col_sums == max(col_sums), 1);
end

% =========================================================================
%  DETECT SCALE (px/mm from ruler tick marks)
% =========================================================================
function px_per_mm = detect_scale(img)
% Look at top strip of image for ruler tick marks
top_strip = double(mean(img(1:80,:,:), 3));

% Find dark columns (tick marks)
dark_per_col = sum(top_strip < 80, 1);

% Threshold to get tick columns
tick_cols = find(dark_per_col > 15);
if isempty(tick_cols)
    warning('Could not detect ruler ticks. Defaulting to 460 px/mm.');
    px_per_mm = 460;
    return;
end

% Cluster tick columns into individual ticks
gaps      = diff(tick_cols);
breaks    = find(gaps > 20);
centers   = zeros(1, length(breaks)+1);
prev      = 1;
for i = 1:length(breaks)
    centers(i) = round(mean(tick_cols(prev:breaks(i))));
    prev = breaks(i)+1;
end
centers(end) = round(mean(tick_cols(prev:end)));

% Remove outliers in spacing
spacings = diff(centers);
med_sp   = median(spacings);
good     = spacings > med_sp*0.7 & spacings < med_sp*1.3;
px_per_mm = mean(spacings(good));
end

% =========================================================================
%  DETECT BOUNDS
% =========================================================================
function [left,right,top,bottom] = detect_bounds(img, midline)
r = double(img(:,:,1));
g = double(img(:,:,2));
b = double(img(:,:,3));

% Only look at right half (atlas side)
r(:, 1:midline) = 255;
g(:, 1:midline) = 255;
b(:, 1:midline) = 255;

% % Not-white mask
% %not_white = ~(r > 220 & g > 220 & b > 220);
% % Look for green atlas region only
% not_white = (g > 150) & (g > r * 1.2) & (g > b * 1.1);
% Green atlas region OR non-white non-gray colored region
green_mask = (g > 150) & (g > r * 1.2) & (g > b * 1.1);
colored_mask = ~(r > 220 & g > 220 & b > 220) & ...  % not white
               ~(abs(double(r)-double(g)) < 15 & abs(double(g)-double(b)) < 15); % not gray
not_white = green_mask | colored_mask;

% Morphological cleanup
mask = imopen(not_white,  strel('disk',8));
mask = imclose(mask,      strel('disk',25));
mask = imfill(mask,'holes');

% Keep largest region
cc = bwconncomp(mask);
if cc.NumObjects == 0
    [h,w,~] = size(img);
    left=1; right=w; top=1; bottom=h; return;
end
numPixels  = cellfun(@numel, cc.PixelIdxList);
[~,idx]    = max(numPixels);
mask_clean = false(size(mask));
mask_clean(cc.PixelIdxList{idx}) = true;

cols   = any(mask_clean,1);
rows   = any(mask_clean,2);
right  = find(cols,1,'last');
top    = find(rows,1,'first');
bottom = find(rows,1,'last');

% Mirror right side to get left
right_w = right - midline;
left    = max(1, round(midline - right_w));
end

% =========================================================================
%  PARSE AP FROM FILENAME
% =========================================================================
function ap = parse_ap(filename)
% e.g. '103_2-445.jpg' -> 2.445
try
    [~,name] = fileparts(filename);
    parts    = strsplit(name,'_');
    ap_str   = strrep(parts{end},'-','.');
    ap       = str2double(ap_str);
    if isnan(ap), ap = 0; end
catch
    ap = 0;
end
end
