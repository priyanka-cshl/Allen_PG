function AtlasRegionLabeler(atlas_folder)
% GUI for defining brain regions by color sampling on new high-res Allen Atlas JPGs
% Requires AllenBounds.mat in atlas_folder (run ProcessAllenAtlas first)
% Usage: AtlasRegionLabeler('/path/to/atlas/folder')

if nargin < 1
    atlas_folder = uigetdir(pwd,'Select Atlas Folder');
    if isequal(atlas_folder,0), return; end
end

mat_file = fullfile(atlas_folder,'AllenBounds.mat');
if ~isfile(mat_file)
    error('AllenBounds.mat not found. Run ProcessAllenAtlas first.');
end

fprintf('Loading AllenBounds.mat...\n');
data    = load(mat_file);
results = data.results;
n       = length(results);

% Load existing regions if saved
reg_file = fullfile(atlas_folder,'AllenRegions.mat');
if isfile(reg_file)
    rdata   = load(reg_file);
    regions = rdata.regions;
    fprintf('Loaded %d existing regions.\n', length(regions));
else
    regions = struct('name',{},'color',{},'best_ch',{},'tolerance',{},'boundaries',{});
end

% --- Figure ---
hFig = figure('Name','Atlas Region Labeler','NumberTitle','off',...
    'Position',[50 50 1200 800],'Color',[0.15 0.15 0.15]);
set(hFig,'Toolbar','none');


% Main image axes
hAx = axes(hFig,'Position',[0.02 0.12 0.62 0.82],'Color','k');

% Color swatch panel (narrow strip to left of listbox)
hSwatchPanel = uipanel(hFig,'Units','normalized','Position',[0.66 0.15 0.03 0.79],...
    'BackgroundColor',[0.1 0.1 0.1],'BorderType','none');

% Region listbox
hList = uicontrol(hFig,'Style','listbox',...
    'Units','normalized','Position',[0.69 0.15 0.29 0.79],...
    'Tag','regionList',...
    'BackgroundColor',[0.1 0.1 0.1],'ForegroundColor','w',...
    'FontSize',12,'String',{'+ New Region'},'Value',1);

% Linewidth label + slider above listbox
uicontrol(hFig,'Style','text','String','Line Width',...
    'Units','normalized','Position',[0.66 0.94 0.08 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w','FontSize',8);
uicontrol(hFig,'Style','slider','Min',0.5,'Max',6,'Value',2,...
    'Units','normalized','Position',[0.75 0.94 0.17 0.03],...
    'Tag','lineWidthSlider',...
    'Callback',@(src,~) update_linewidth(src,hFig));
uicontrol(hFig,'Style','text','String','2',...
    'Units','normalized','Position',[0.93 0.94 0.03 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w',...
    'FontSize',8,'Tag','lineWidthText');

% --- State ---
state.idx          = 1;
state.n            = n;
state.results      = results;
state.atlas_folder = atlas_folder;
state.reg_file     = reg_file;
state.regions      = regions;
state.last_click   = [];
state.boundary_colors = [
    1.0  0.0  0.0;   % red
    0.0  0.9  0.0;   % green
    0.2  0.5  1.0;   % blue
    1.0  0.6  0.0;   % orange
    0.9  0.0  0.9;   % magenta
    0.0  0.9  0.9;   % cyan
    1.0  1.0  0.0;   % yellow
    1.0  0.2  0.5;   % pink
    0.5  1.0  0.0;   % lime
    0.4  0.2  1.0;   % purple
];

setappdata(hFig,'state',state);
setappdata(hFig,'handles',struct('ax',hAx,'list',hList,'swatchPanel',hSwatchPanel));

% --- Panel ---
uipanel(hFig,'Units','normalized','Position',[0 0 1 0.11],...
    'BackgroundColor',[0.15 0.15 0.15]);

% Nav
uicontrol(hFig,'Style','pushbutton','String','< Prev',...
    'Units','normalized','Position',[0.01 0.04 0.06 0.06],...
    'Callback',@(~,~) nav_atlas(hFig,-1));
uicontrol(hFig,'Style','pushbutton','String','Next >',...
    'Units','normalized','Position',[0.08 0.04 0.06 0.06],...
    'Callback',@(~,~) nav_atlas(hFig,+1));

% Dropdown
uicontrol(hFig,'Style','popupmenu',...
    'Units','normalized','Position',[0.01 0.01 0.13 0.03],...
    'Tag','sliceDropdown',...
    'String',arrayfun(@(r) sprintf('AP=%.3f',r.ap_mm), results,'UniformOutput',false),...
    'Value',1,...
    'Callback',@(src,~) dropdown_nav(hFig,src));

% Region buttons
uicontrol(hFig,'Style','pushbutton','String','Add Region',...
    'Units','normalized','Position',[0.16 0.05 0.09 0.05],...
    'ForegroundColor','w','BackgroundColor',[0.2 0.5 0.2],...
    'Callback',@(~,~) add_region(hFig));

uicontrol(hFig,'Style','pushbutton','String','Redo Last',...
    'Units','normalized','Position',[0.26 0.05 0.08 0.05],...
    'ForegroundColor','w','BackgroundColor',[0.4 0.3 0.1],...
    'Callback',@(~,~) redo_last(hFig));

uicontrol(hFig,'Style','pushbutton','String','Auto Next',...
    'Units','normalized','Position',[0.35 0.05 0.08 0.05],...
    'ForegroundColor','w','BackgroundColor',[0.2 0.4 0.5],...
    'Callback',@(~,~) auto_detect_next(hFig));

% Show/hide boundaries toggle
uicontrol(hFig,'Style','togglebutton','String','Hide Boundaries',...
    'Units','normalized','Position',[0.44 0.05 0.09 0.05],...
    'ForegroundColor','w','BackgroundColor',[0.2 0.3 0.5],...
    'Tag','btnShowBounds','Value',0,...
    'Callback',@(src,~) toggle_boundaries(src,hFig));

uicontrol(hFig,'Style','pushbutton','String','Remove Region',...
    'Units','normalized','Position',[0.54 0.05 0.09 0.05],...
    'ForegroundColor','w','BackgroundColor',[0.5 0.2 0.2],...
    'Callback',@(~,~) remove_region(hFig));

% Tolerance
uicontrol(hFig,'Style','text','String','Tolerance',...
    'Units','normalized','Position',[0.63 0.07 0.07 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w','FontSize',8);
uicontrol(hFig,'Style','slider','Min',1,'Max',100,'Value',20,...
    'Units','normalized','Position',[0.63 0.04 0.13 0.03],...
    'Tag','tolSlider',...
    'Callback',@(src,~) update_tolerance(src,hFig));
uicontrol(hFig,'Style','text','String','20',...
    'Units','normalized','Position',[0.77 0.04 0.03 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w',...
    'FontSize',8,'Tag','tolText');

% Save
uicontrol(hFig,'Style','pushbutton','String','Save',...
    'Units','normalized','Position',[0.92 0.04 0.07 0.06],...
    'ForegroundColor','w','BackgroundColor',[0.2 0.3 0.6],...
    'Callback',@(~,~) save_regions(hFig));

% Status
uicontrol(hFig,'Style','text','String','Ready.',...
    'Units','normalized','Position',[0.66 0.12 0.32 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.5 1 0.5],...
    'FontSize',8,'HorizontalAlignment','left','Tag','statusText');

draw_slice(hFig);
end

% =========================================================================
%  DRAW SLICE
% =========================================================================
function draw_slice(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');
idx   = state.idx;
r     = state.results(idx);

img = imread(fullfile(state.atlas_folder, r.filename));

cla(h.ax);
image(h.ax, img);
axis(h.ax,'image','off');
hold(h.ax,'on');

rectangle('Parent',h.ax,...
    'Position',[r.left, r.top, r.right-r.left, r.bottom-r.top],...
    'EdgeColor','r','LineWidth',1.5);
line(h.ax,[r.midline r.midline],[r.top r.bottom],'Color','c','LineWidth',1.5);

title(h.ax,sprintf('AP = %.3f mm  |  %s', r.ap_mm, r.filename),...
    'Color','w','FontSize',9);

set(findobj(hFig,'Tag','sliceDropdown'),'Value',idx);

draw_boundaries(hFig);
draw_legend(hFig);
set_status(hFig,sprintf('Slice %d/%d  |  AP=%.3fmm  |  %d region(s) defined',...
    idx, state.n, r.ap_mm, length(state.regions)));
end

% =========================================================================
%  DRAW BOUNDARIES
% =========================================================================
function draw_boundaries(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');
idx   = state.idx;

% Check show/hide toggle
btn = findobj(hFig,'Tag','btnShowBounds');
if ~isempty(btn) && btn.Value, return; end

lw = get(findobj(hFig,'Tag','lineWidthSlider'),'Value');

axes(h.ax);
hold on;
for ri = 1:length(state.regions)
    rg = state.regions(ri);
    if ~isfield(rg,'boundaries') || isempty(rg.boundaries), continue; end
    if idx > length(rg.boundaries) || isempty(rg.boundaries{idx}), continue; end
    col = state.boundary_colors(mod(ri-1, size(state.boundary_colors,1))+1, :);
    for bi = 1:length(rg.boundaries{idx})
        bnd = rg.boundaries{idx}{bi};
        plot(bnd(:,2), bnd(:,1), '-', 'Color', col, 'LineWidth', lw);
    end
end
end

% =========================================================================
%  DRAW LEGEND (listbox + color swatches)
% =========================================================================
function draw_legend(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');

% Delete old swatches
delete(findobj(h.swatchPanel,'Type','axes'));

% Build listbox strings
hList    = findobj(hFig,'Tag','regionList');
names    = {};
for i = 1:length(state.regions)
    n_bounds = 0;
    if isfield(state.regions(i),'boundaries') && ~isempty(state.regions(i).boundaries)
        n_bounds = sum(~cellfun(@isempty, state.regions(i).boundaries));
    end
    names{i} = sprintf('%s  [%d slices]', state.regions(i).name, n_bounds);
end
names{end+1} = '+ New Region';

prev = get(hList,'Value');
set(hList,'String',names,'Value',min(prev,length(names)));

% Draw swatches sized to match listbox rows
n_regions = length(state.regions);
if n_regions == 0, return; end

% Compute row height from font size and listbox pixel height
font_size    = get(hList,'FontSize');       % points, from list properties
fig_pos      = get(hFig,'Position');        % [x y w h] pixels
list_pos_norm = get(hList,'Position');      % normalized
list_h_px    = list_pos_norm(4) * fig_pos(4);
row_h_px     = font_size * 1.4;            % empirical: ~1.6x font size per row
row_h_norm   = row_h_px / list_h_px;       % as fraction of listbox height

ax_sw = axes('Parent',h.swatchPanel,'Position',[0 0 1 1],...
    'Color',[0.1 0.1 0.1],'XTick',[],'YTick',[],...
    'XLim',[0 1],'YLim',[0 1]);

for i = 1:n_regions
    y_top = 1 - i * row_h_norm;
    col   = state.boundary_colors(mod(i-1, size(state.boundary_colors,1))+1, :);
    rectangle('Parent',ax_sw,...
        'Position',[0.1, y_top + row_h_norm*0.15, 0.8, row_h_norm*0.7],...
        'FaceColor',col,'EdgeColor','none');
end
y_top = 1 - (n_regions + 1) * row_h_norm;
rectangle('Parent',ax_sw,...
    'Position',[0.1, y_top + row_h_norm*0.15, 0.8, row_h_norm*0.7],...
    'FaceColor',[0.3 0.3 0.3],'EdgeColor','none');
end

% =========================================================================
%  TOGGLE BOUNDARIES
% =========================================================================
function toggle_boundaries(src,hFig)
if src.Value
    src.String = 'Show Boundaries';
else
    src.String = 'Hide Boundaries';
end
draw_slice(hFig);
end

% =========================================================================
%  ADD REGION
% =========================================================================
function add_region(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');
idx   = state.idx;
r     = state.results(idx);

set_status(hFig,'Click on the region in the atlas image...');
axes(h.ax);
[x,y] = ginput(1);
x = round(x); y = round(y);

img     = imread(fullfile(state.atlas_folder, r.filename));
color   = squeeze(double(img(y,x,:)))';
best_ch = find_best_channel(color);
tol     = round(get(findobj(hFig,'Tag','tolSlider'),'Value'));

[boundary, ~] = find_region_boundary(img, x, y, color, best_ch, tol, r);

if isempty(boundary)
    set_status(hFig,'No region found. Try adjusting tolerance.');
    return;
end

% Update color to median of found region
bmask = poly2mask(boundary{1}(:,2), boundary{1}(:,1), size(img,1), size(img,2));
img_d = double(img);
for c = 1:3
    ch_data = img_d(:,:,c);
    color(c) = median(ch_data(bmask));
end
best_ch = find_best_channel(color);

% Get region from list selection
hList = findobj(hFig,'Tag','regionList');
sel   = get(hList,'Value');
names = get(hList,'String');

if sel == length(names) % '+ New Region'
    answer = inputdlg('New region name:','New Region',1,{''});
    if isempty(answer) || isempty(strtrim(answer{1}))
        set_status(hFig,'Cancelled.'); return;
    end
    name         = strtrim(answer{1});
    existing_idx = [];
else
    name         = state.regions(sel).name;
    existing_idx = sel;
end

% Append or create
if ~isempty(existing_idx)
    existing = state.regions(existing_idx).boundaries{idx};
    if isempty(existing)
        state.regions(existing_idx).boundaries{idx} = boundary;
    else
        state.regions(existing_idx).boundaries{idx} = [existing; boundary];
    end
    ri = existing_idx;
    set_status(hFig,sprintf('Updated boundary for "%s" on slice %d.',name,idx));
else
    new_region.name       = name;
    new_region.color      = color;
    new_region.best_ch    = best_ch;
    new_region.tolerance  = tol;
    new_region.boundaries = cell(state.n,1);
    new_region.boundaries{idx} = boundary;
    state.regions(end+1)  = new_region;
    ri = length(state.regions);
    ch_names = {'R','G','B'};
    set_status(hFig,sprintf('Added "%s"  RGB=[%d %d %d]  ch=%s  tol=%d',...
        name, round(color), ch_names{best_ch}, tol));
end

state.last_click.x          = x;
state.last_click.y          = y;
state.last_click.color      = color;
state.last_click.best_ch    = best_ch;
state.last_click.name       = name;
state.last_click.region_idx = ri;

setappdata(hFig,'state',state);

% Draw boundary
lw  = get(findobj(hFig,'Tag','lineWidthSlider'),'Value');
col = state.boundary_colors(mod(ri-1, size(state.boundary_colors,1))+1, :);
axes(h.ax); hold on;
for bi = 1:length(boundary)
    bnd = boundary{bi};
    plot(bnd(:,2), bnd(:,1), '-', 'Color', col, 'LineWidth', lw);
end

draw_legend(hFig);
end

% =========================================================================
%  REDO LAST
% =========================================================================
function redo_last(hFig)
state = getappdata(hFig,'state');
if isempty(state.last_click)
    set_status(hFig,'No previous region to redo.'); return;
end

idx = state.idx;
lc  = state.last_click;
r   = state.results(idx);
img = imread(fullfile(state.atlas_folder, r.filename));
tol = round(get(findobj(hFig,'Tag','tolSlider'),'Value'));

[boundary, ~] = find_region_boundary(img, lc.x, lc.y, lc.color, lc.best_ch, tol, r);
if isempty(boundary)
    set_status(hFig,'No region found with current tolerance.'); return;
end

ri = lc.region_idx;
state.regions(ri).boundaries{idx} = boundary;
state.regions(ri).tolerance       = tol;
setappdata(hFig,'state',state);

draw_slice(hFig);
set_status(hFig,sprintf('Redrawn "%s" with tol=%d', lc.name, tol));
end

% =========================================================================
%  AUTO DETECT NEXT SLICE
% =========================================================================
function auto_detect_next(hFig)
state = getappdata(hFig,'state');
if isempty(state.regions)
    set_status(hFig,'No regions defined yet.'); return;
end

new_idx = state.idx + 1;
if new_idx > state.n
    set_status(hFig,'Already on last slice.'); return;
end
state.idx = new_idx;
setappdata(hFig,'state',state);

idx       = state.idx;
r         = state.results(idx);
img       = imread(fullfile(state.atlas_folder, r.filename));
img_d     = double(img);
any_found = false;

for ri = 1:length(state.regions)
    rg = state.regions(ri);

    % Find best matching pixel as seed (restricted to bounding box)
    ch   = rg.best_ch;
    dist = abs(img_d(:,:,ch) - rg.color(ch));
    dist_masked = inf(size(dist));
    dist_masked(r.top:r.bottom, r.midline:r.right) = ...
        dist(r.top:r.bottom, r.midline:r.right);

    [rows,cols] = find(dist_masked < rg.tolerance);
    if isempty(rows)
        fprintf('  No matching pixels for "%s" on slice %d\n', rg.name, idx);
        continue;
    end

    [~,best] = min(dist_masked(sub2ind(size(dist_masked),rows,cols)));
    seed_y   = rows(best);
    seed_x   = cols(best);

    [boundary,~] = find_region_boundary(img, seed_x, seed_y, ...
        rg.color, rg.best_ch, rg.tolerance, r);

    if ~isempty(boundary)
        state.regions(ri).boundaries{idx} = boundary;
        % Update color for next slice tracking
        bmask = poly2mask(boundary{1}(:,2), boundary{1}(:,1), size(img,1), size(img,2));
        for c = 1:3
            ch_data = img_d(:,:,c);
            state.regions(ri).color(c) = median(ch_data(bmask));
        end
        state.regions(ri).best_ch = find_best_channel(state.regions(ri).color);
        any_found = true;
        fprintf('  Auto-detected "%s" on slice %d\n', rg.name, idx);
    else
        fprintf('  Could not find "%s" on slice %d\n', rg.name, idx);
    end
end

setappdata(hFig,'state',state);
draw_slice(hFig);

if any_found
    set_status(hFig,sprintf('Auto-detected on slice %d. Adjust tolerance if needed.',idx));
else
    set_status(hFig,sprintf('Could not auto-detect on slice %d. Try Add Region manually.',idx));
end
end

% =========================================================================
%  FIND REGION BOUNDARY
% =========================================================================
function [boundary, mask] = find_region_boundary(img, x, y, color, best_ch, tol, r)
img_d = double(img);
dist  = abs(img_d(:,:,best_ch) - color(best_ch));

% Restrict to right hemisphere bounding box
roi_mask = false(size(dist));
roi_mask(r.top:r.bottom, r.midline:r.right) = true;
dist(~roi_mask) = inf;

mask_full = dist < tol;

labeled = bwlabel(mask_full, 8);
if y < 1 || y > size(img,1) || x < 1 || x > size(img,2) || labeled(y,x) == 0
    boundary = {};
    mask = false(size(mask_full));
    return;
end

mask     = labeled == labeled(y,x);
mask     = imfill(mask,'holes');
boundary = bwboundaries(mask,'noholes');
end

% =========================================================================
%  FIND BEST CHANNEL
% =========================================================================
function best_ch = find_best_channel(color)
white = [255 255 255];
diffs = abs(color - white);
[~, best_ch] = max(diffs);
end

% =========================================================================
%  REMOVE REGION
% =========================================================================
function remove_region(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');
idx   = state.idx;

if isempty(state.regions)
    set_status(hFig,'No regions defined.'); return;
end

set_status(hFig,'Click inside a region boundary to remove it...');
axes(h.ax);
[x,y] = ginput(1);
x = round(x); y = round(y);

found_ri = []; found_bi = [];
for ri = 1:length(state.regions)
    rg = state.regions(ri);
    if ~isfield(rg,'boundaries') || isempty(rg.boundaries), continue; end
    if idx > length(rg.boundaries) || isempty(rg.boundaries{idx}), continue; end
    for bi = 1:length(rg.boundaries{idx})
        bnd = rg.boundaries{idx}{bi};
        if inpolygon(x, y, bnd(:,2), bnd(:,1))
            found_ri = ri; found_bi = bi; break;
        end
    end
    if ~isempty(found_ri), break; end
end

if isempty(found_ri)
    set_status(hFig,'No region found at that point.'); return;
end

name   = state.regions(found_ri).name;
choice = questdlg(sprintf('Remove "%s":', name),'Remove Region',...
    'This boundary only','Entire region','Cancel','This boundary only');

switch choice
    case 'This boundary only'
        state.regions(found_ri).boundaries{idx}(found_bi) = [];
        set_status(hFig,sprintf('Removed boundary of "%s" on slice %d.',name,idx));
    case 'Entire region'
        state.regions(found_ri) = [];
        set_status(hFig,sprintf('Removed region "%s" entirely.',name));
    case 'Cancel'
        set_status(hFig,'Cancelled.'); return;
end

setappdata(hFig,'state',state);
draw_slice(hFig);
end

% =========================================================================
%  SAVE
% =========================================================================
function save_regions(hFig)
state   = getappdata(hFig,'state');
regions = state.regions;
save(state.reg_file,'regions');
fprintf('Saved %d regions to %s\n',length(regions),state.reg_file);
set_status(hFig,sprintf('Saved %d regions.',length(regions)));
end

% =========================================================================
%  NAVIGATION
% =========================================================================
function nav_atlas(hFig,direction)
state = getappdata(hFig,'state');
new_idx = state.idx + direction;
if new_idx < 1 || new_idx > state.n
    set_status(hFig,'No more slices.'); return;
end
state.idx = new_idx;
setappdata(hFig,'state',state);
draw_slice(hFig);
end

function dropdown_nav(hFig,src)
state = getappdata(hFig,'state');
state.idx = src.Value;
setappdata(hFig,'state',state);
draw_slice(hFig);
end

% =========================================================================
%  TOLERANCE / LINEWIDTH
% =========================================================================
function update_tolerance(src,hFig)
val = round(src.Value);
set(findobj(hFig,'Tag','tolText'),'String',num2str(val));
redo_last(hFig);
end

function update_linewidth(src,hFig)
val = round(src.Value*2)/2;
set(findobj(hFig,'Tag','lineWidthText'),'String',num2str(val));
draw_slice(hFig);
end

% =========================================================================
%  HELPERS
% =========================================================================
function set_status(hFig,msg)
h = findobj(hFig,'Tag','statusText');
if ~isempty(h), set(h,'String',msg); end
end
