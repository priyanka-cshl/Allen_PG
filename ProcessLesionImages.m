function ProcessLesionImages(img_path)
if nargin < 1
    img_path = 'Image_000001.tif';
end

% --- Get image list from folder ---
[folder, ~, ext] = fileparts(img_path);
if isempty(folder), folder = pwd; end
extensions = {'*.tif'}; %,'*.tiff','*.png','*.jpg'};
img_list = {};
for e = 1:length(extensions)
    d = dir(fullfile(folder, extensions{e}));
    for k = 1:length(d)
        img_list{end+1} = fullfile(folder, d(k).name);
    end
end
img_list = sort(img_list);

% Find starting index
img_idx = find(strcmp(img_list, img_path), 1);
if isempty(img_idx), img_idx = 1; end

% --- Figure ---
hFig = figure('Name','Brain Slice Editor','NumberTitle','off',...
    'Position',[50 50 1100 880]);
hAx = axes(hFig,'Position',[0.05 0.18 0.9 0.78]);
set(hFig, 'Toolbar', 'none');

% --- State ---
state.img_list        = img_list;
state.img_idx         = img_idx;
state.all_results     = struct();
state.holes           = {};
state.electrode_tracks = {};
state.has_hole        = false;
state.has_electrode   = false;

setappdata(hFig,'state',state);
setappdata(hFig,'handles',struct('ax',hAx));

% --- Panel ---
uipanel(hFig,'Units','normalized','Position',[0 0 1 0.155],...
    'BackgroundColor',[0.15 0.15 0.15]);

% Nav buttons
uicontrol(hFig,'Style','pushbutton','String','< Prev',...
    'Units','normalized','Position',[0.01 0.08 0.07 0.07],...
    'Callback',@(~,~) nav_image(hFig,-1));
uicontrol(hFig,'Style','pushbutton','String','Next >',...
    'Units','normalized','Position',[0.09 0.08 0.07 0.07],...
    'Callback',@(~,~) nav_image(hFig,+1));

% Filenames dropdown Menu
uicontrol(hFig,'Style','popupmenu',...
    'Units','normalized','Position',[0.01 0.03 0.26 0.04],...
    'Tag','imgDropdown',...
    'String',cellfun(@(x) fileparts_name(x), img_list, 'UniformOutput', false),...
    'Value',img_idx,...
    'Callback',@(src,~) dropdown_nav(hFig,src));

% General buttons
uicontrol(hFig,'Style','pushbutton','String','Save All',...
    'Units','normalized','Position',[0.01 0.02 0.07 0.05],...
    'Callback',@(~,~) save_all(hFig));
uicontrol(hFig,'Style','pushbutton','String','Reset',...
    'Units','normalized','Position',[0.09 0.02 0.07 0.05],...
    'Callback',@(~,~) reset_lines(hFig));

% Hole controls
uicontrol(hFig,'Style','text','String','HOLE',...
    'Units','normalized','Position',[0.30 0.12 0.08 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','y',...
    'FontWeight','bold','FontSize',10);
uicontrol(hFig,'Style','checkbox','String','Has Hole',...
    'Units','normalized','Position',[0.30 0.08 0.10 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w',...
    'Tag','chkHole','Callback',@(src,~) toggle_hole(src,hFig));
uicontrol(hFig,'Style','pushbutton','String','Add Hole',...
    'Units','normalized','Position',[0.30 0.03 0.09 0.04],...
    'Tag','btnAddHole','Enable','off',...
    'Callback',@(~,~) add_hole(hFig));
uicontrol(hFig,'Style','pushbutton','String','Clear Holes',...
    'Units','normalized','Position',[0.40 0.03 0.09 0.04],...
    'Tag','btnClearHoles','Enable','off',...
    'Callback',@(~,~) clear_holes(hFig));

% Electrode controls
uicontrol(hFig,'Style','text','String','ELECTRODE TRACK',...
    'Units','normalized','Position',[0.57 0.12 0.15 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[1 0.5 0],...
    'FontWeight','bold','FontSize',10);
uicontrol(hFig,'Style','checkbox','String','Has Electrode Track',...
    'Units','normalized','Position',[0.57 0.08 0.16 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w',...
    'Tag','chkElectrode','Callback',@(src,~) toggle_electrode(src,hFig));
uicontrol(hFig,'Style','pushbutton','String','Add Track',...
    'Units','normalized','Position',[0.57 0.03 0.09 0.04],...
    'Tag','btnAddTrack','Enable','off',...
    'Callback',@(~,~) add_electrode(hFig));
uicontrol(hFig,'Style','pushbutton','String','Clear Tracks',...
    'Units','normalized','Position',[0.67 0.03 0.09 0.04],...
    'Tag','btnClearTracks','Enable','off',...
    'Callback',@(~,~) clear_electrodes(hFig));

% Contrast slider
uicontrol(hFig,'Style','text','String','Contrast',...
    'Units','normalized','Position',[0.79 0.12 0.06 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w','FontSize',8);
uicontrol(hFig,'Style','slider','Min',0.1,'Max',3.0,'Value',1.0,...
    'Units','normalized','Position',[0.79 0.08 0.18 0.03],...
    'Tag','contrastSlider',...
    'Callback',@(src,~) update_contrast(src,hFig));

% Hide/show annotations toggle
uicontrol(hFig,'Style','togglebutton','String','Hide Annotations',...
    'Units','normalized','Position',[0.79 0.03 0.18 0.04],...
    'Tag','btnHide',...
    'Callback',@(src,~) toggle_visibility(src,hFig));

% Select as reference checkbox
uicontrol(hFig,'Style','checkbox','String','Reference',...
    'Units','normalized','Position',[0.18 0.08 0.10 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[1 0.8 0],...
    'Tag','chkReference');

% Status bar
uicontrol(hFig,'Style','text','String','Ready.',...
    'Units','normalized','Position',[0.01 0.0 0.98 0.02],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.5 1 0.5],...
    'FontSize',8,'HorizontalAlignment','left','Tag','statusText');

% --- Load first image ---
load_image(hFig);
end

% =========================================================================
%  IMAGE LOADING
% =========================================================================
function load_image(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');
idx   = state.img_idx;
img_path = state.img_list{idx};

% Update title
[~,fname] = fileparts(img_path);
set(hFig,'Name',sprintf('Brain Slice Editor  —  %s  (%d / %d)',...
    fname, idx, length(state.img_list)));

% Update dropdown menu
set(findobj(hFig,'Tag','imgDropdown'),'Value',idx);

% Load image
img = imread(img_path);
if size(img,3) > 1, gray = rgb2gray(img); else, gray = img; end
gray_norm = mat2gray(double(gray));

% Store for contrast adjustment
setappdata(hFig,'gray_norm',gray_norm);

% Auto-detect
[left,right,top,bottom,midline_x] = auto_detect(gray_norm);

% Clear axes and redraw image
cla(h.ax);
imshow(gray_norm,[],'Parent',h.ax);
hold(h.ax,'on');

% Reset contrast slider and hide button
set(findobj(hFig,'Tag','contrastSlider'),'Value',1.0);
set(findobj(hFig,'Tag','btnHide'),'Value',0,'String','Hide Annotations');

% Clear old ROI holes/tracks from state
state.holes            = {};
state.electrode_tracks = {};
state.has_hole         = false;
state.has_electrode    = false;

% Reset checkboxes
set(findobj(hFig,'Tag','chkHole'),       'Value',0);
set(findobj(hFig,'Tag','chkElectrode'),  'Value',0);
set(findobj(hFig,'Tag','btnAddHole'),    'Enable','off');
set(findobj(hFig,'Tag','btnClearHoles'), 'Enable','off');
set(findobj(hFig,'Tag','btnAddTrack'),   'Enable','off');
set(findobj(hFig,'Tag','btnClearTracks'),'Enable','off');
set(findobj(hFig,'Tag','chkReference'),'Value',0);

% Check if we have saved results for this image
if isfield(state.all_results, sprintf('img%d',idx))
    r = state.all_results.(sprintf('img%d',idx));
    left      = r.left;
    right     = r.right;
    top       = r.top;
    bottom    = r.bottom;
    midline_x = r.midline;

    set(findobj(hFig,'Tag','contrastSlider'),'Value',r.contrast);
    update_contrast(findobj(hFig,'Tag','contrastSlider'),hFig);

    set(findobj(hFig,'Tag','chkReference'),'Value',r.is_reference);

    % Restore holes
    if r.has_hole && ~isempty(r.holes)
        state.has_hole = true;
        set(findobj(hFig,'Tag','chkHole'),       'Value',1);
        set(findobj(hFig,'Tag','btnAddHole'),    'Enable','on');
        set(findobj(hFig,'Tag','btnClearHoles'), 'Enable','on');
        for i = 1:length(r.holes)
            pos  = r.holes{i};
            hRoi = drawellipse(h.ax,'Center',pos.center,...
                'SemiAxes',pos.semiaxes,'RotationAngle',pos.angle,'Color','y');
            state.holes{end+1} = struct('roi',hRoi,'pos',pos);
            hole_num = i;
            addlistener(hRoi,'ROIMoved',@(src,~) update_hole(src,hFig,hole_num));
        end
    end

    % Restore electrode tracks
    if r.has_electrode && ~isempty(r.electrode_tracks)
        state.has_electrode = true;
        set(findobj(hFig,'Tag','chkElectrode'),  'Value',1);
        set(findobj(hFig,'Tag','btnAddTrack'),   'Enable','on');
        set(findobj(hFig,'Tag','btnClearTracks'),'Enable','on');
        for i = 1:length(r.electrode_tracks)
            t     = r.electrode_tracks{i};
            hLine = plot(h.ax,[t.start(1) t.end(1)],[t.start(2) t.end(2)],...
                '-','Color',[1 0.5 0],'LineWidth',0.75);
            state.electrode_tracks{end+1} = struct('hLine',hLine,...
                'start',t.start,'end',t.end,...
                'angle_deg',t.angle_deg,'length_px',t.length_px);
        end
    end
end

% Draw bounding box and midline
lw = 0.5;
hTop    = drawline(h.ax,'Position',[left top;    right top],          'Color','g','LineWidth',lw);
hBottom = drawline(h.ax,'Position',[left bottom; right bottom],       'Color','g','LineWidth',lw);
hLeft   = drawline(h.ax,'Position',[left top;    left bottom],        'Color','g','LineWidth',lw);
hRight  = drawline(h.ax,'Position',[right top;   right bottom],       'Color','g','LineWidth',lw);
hMid    = drawline(h.ax,'Position',[midline_x top; midline_x bottom], 'Color','c','LineWidth',lw);

% Store original for reset
state.original = struct('left',left,'right',right,'top',top,...
    'bottom',bottom,'midline',midline_x);

setappdata(hFig,'state',state);
setappdata(hFig,'handles',struct('ax',h.ax,...
    'top',hTop,'bottom',hBottom,'left',hLeft,'right',hRight,'mid',hMid));

set_status(hFig,true,sprintf('Image %d of %d — %s',idx,length(state.img_list),fname));
end

% =========================================================================
%  NAVIGATION
% =========================================================================
function nav_image(hFig, direction)
save_current(hFig);
state = getappdata(hFig,'state');
new_idx = state.img_idx + direction;
if new_idx < 1 || new_idx > length(state.img_list)
    set_status(hFig,true,'No more images in that direction.');
    return;
end
state.img_idx = new_idx;
setappdata(hFig,'state',state);
load_image(hFig);
end

% =========================================================================
%  SAVE CURRENT IMAGE RESULTS INTO STATE
% =========================================================================
function save_current(hFig)
h     = getappdata(hFig,'handles');
state = getappdata(hFig,'state');
idx   = state.img_idx;
key   = sprintf('img%d',idx);

r.left     = mean(h.left.Position(:,1));
r.right    = mean(h.right.Position(:,1));
r.top      = mean(h.top.Position(:,2));
r.bottom   = mean(h.bottom.Position(:,2));
r.midline  = mean(h.mid.Position(:,1));
r.img_path = state.img_list{idx};
r.contrast = get(findobj(hFig,'Tag','contrastSlider'),'Value');
r.is_reference = logical(get(findobj(hFig,'Tag','chkReference'),'Value'));

r.has_hole = state.has_hole;
r.holes    = {};
for i = 1:length(state.holes)
    r.holes{i} = state.holes{i}.pos;
end

r.has_electrode    = state.has_electrode;
r.electrode_tracks = {};
for i = 1:length(state.electrode_tracks)
    t = state.electrode_tracks{i};
    r.electrode_tracks{i} = struct('start',t.start,'end',t.end,...
        'angle_deg',t.angle_deg,'length_px',t.length_px);
end

state.all_results.(key) = r;
setappdata(hFig,'state',state);
end

% =========================================================================
%  SAVE ALL TO DISK
% =========================================================================
function save_all(hFig)
save_current(hFig);
state = getappdata(hFig,'state');
all_results = state.all_results;
assignin('base','all_results',all_results);
save('brain_slice_all_results.mat','all_results');
fprintf('Saved %d image results to brain_slice_all_results.mat\n',...
    length(fieldnames(all_results)));
set_status(hFig,true,'All results saved to brain_slice_all_results.mat');
end

% =========================================================================
%  AUTO DETECT
% =========================================================================
function [left,right,top,bottom,midline_x] = auto_detect(gray_norm)
thresh = graythresh(gray_norm) * 0.5;
mask = gray_norm > thresh;
mask = imfill(mask,'holes');
mask = bwareaopen(mask,5000);
mask = imclose(mask,strel('disk',20));
cc = bwconncomp(mask);
numPixels = cellfun(@numel,cc.PixelIdxList);
[~,idx] = max(numPixels);
mask_clean = false(size(mask));
mask_clean(cc.PixelIdxList{idx}) = true;

props = regionprops(mask_clean,'BoundingBox');
bbox  = props.BoundingBox;
left   = bbox(1);
top    = bbox(2);
right  = bbox(1)+bbox(3);
bottom = bbox(2)+bbox(4);

[rows,cols] = find(mask_clean);
row_ids = unique(rows);
mid_per_row = zeros(length(row_ids),1);
for i = 1:length(row_ids)
    rc = cols(rows == row_ids(i));
    mid_per_row(i) = (min(rc)+max(rc))/2;
end
midline_x = median(mid_per_row);
end

% =========================================================================
%  CONTRAST
% =========================================================================
function update_contrast(src,hFig)
h         = getappdata(hFig,'handles');
gray_norm = getappdata(hFig,'gray_norm');
gamma     = src.Value;
adjusted  = gray_norm .^ (1/gamma);
hImg      = findobj(h.ax,'Type','image');
if ~isempty(hImg)
    hImg.CData = adjusted;
end
end

% =========================================================================
%  HIDE / SHOW ANNOTATIONS
% =========================================================================
function toggle_visibility(src,hFig)
h     = getappdata(hFig,'handles');
state = getappdata(hFig,'state');
if src.Value
    vis = 'off';
    src.String = 'Show Annotations';
else
    vis = 'on';
    src.String = 'Hide Annotations';
end
for fn = {'top','bottom','left','right','mid'}
    try h.(fn{1}).Visible = vis; catch; end
end
for i = 1:length(state.holes)
    try state.holes{i}.roi.Visible = vis; catch; end
end
for i = 1:length(state.electrode_tracks)
    try set(state.electrode_tracks{i}.hLine,'Visible',vis); catch; end
end
end

% =========================================================================
%  HOLE FUNCTIONS
% =========================================================================
function toggle_hole(src,hFig)
state = getappdata(hFig,'state');
state.has_hole = logical(src.Value);
setappdata(hFig,'state',state);
set(findobj(hFig,'Tag','btnAddHole'),   'Enable',onoff(src.Value));
set(findobj(hFig,'Tag','btnClearHoles'),'Enable',onoff(src.Value));
set_status(hFig,state.has_hole,'Hole mode ON — click Add Hole to mark','Hole mode OFF');
end

function add_hole(hFig)
h = getappdata(hFig,'handles');
state = getappdata(hFig,'state');
n = length(state.holes)+1;
set_status(hFig,true,'Draw ellipse around hole, double-click to confirm...');
hRoi = drawellipse(h.ax,'Color','y');
wait(hRoi);
pos.center   = hRoi.Center;
pos.semiaxes = hRoi.SemiAxes;
pos.angle    = hRoi.RotationAngle;
state.holes{end+1} = struct('roi',hRoi,'pos',pos);
addlistener(hRoi,'ROIMoved',@(src,~) update_hole(src,hFig,n));
setappdata(hFig,'state',state);
set_status(hFig,true,sprintf('%d hole(s) marked.',length(state.holes)));
end

function update_hole(src,hFig,hole_idx)
state = getappdata(hFig,'state');
if hole_idx <= length(state.holes)
    state.holes{hole_idx}.pos.center   = src.Center;
    state.holes{hole_idx}.pos.semiaxes = src.SemiAxes;
    state.holes{hole_idx}.pos.angle    = src.RotationAngle;
    setappdata(hFig,'state',state);
end
end

function clear_holes(hFig)
state = getappdata(hFig,'state');
for i = 1:length(state.holes)
    try delete(state.holes{i}.roi); catch; end
end
state.holes = {};
setappdata(hFig,'state',state);
set_status(hFig,true,'All holes cleared.');
end

% =========================================================================
%  ELECTRODE TRACK FUNCTIONS
% =========================================================================
function toggle_electrode(src,hFig)
state = getappdata(hFig,'state');
state.has_electrode = logical(src.Value);
setappdata(hFig,'state',state);
set(findobj(hFig,'Tag','btnAddTrack'),   'Enable',onoff(src.Value));
set(findobj(hFig,'Tag','btnClearTracks'),'Enable',onoff(src.Value));
set_status(hFig,state.has_electrode,...
    'Electrode mode ON — click Add Track, then click two points on image','Electrode mode OFF');
end

function add_electrode(hFig)
h = getappdata(hFig,'handles');
state = getappdata(hFig,'state');
n = length(state.electrode_tracks)+1;
set_status(hFig,true,'Click point 1 of electrode track...');
[x1,y1] = ginput(1);
set_status(hFig,true,'Click point 2 of electrode track...');
[x2,y2] = ginput(1);
hLine = plot(h.ax,[x1 x2],[y1 y2],'-','Color',[1 0.5 0],'LineWidth',0.75);
dx = x2-x1; dy = y2-y1;
angle_deg = atan2d(dy,dx);
length_px = sqrt(dx^2+dy^2);
track = struct('hLine',hLine,'start',[x1 y1],'end',[x2 y2],...
    'angle_deg',angle_deg,'length_px',length_px);
state.electrode_tracks{end+1} = track;
setappdata(hFig,'state',state);
set_status(hFig,true,sprintf('Track %d: angle=%.1f°  len=%.1fpx',n,angle_deg,length_px));
end

function clear_electrodes(hFig)
state = getappdata(hFig,'state');
for i = 1:length(state.electrode_tracks)
    try delete(state.electrode_tracks{i}.hLine); catch; end
end
state.electrode_tracks = {};
setappdata(hFig,'state',state);
set_status(hFig,true,'All tracks cleared.');
end

% =========================================================================
%  RESET
% =========================================================================
function reset_lines(hFig)
h = getappdata(hFig,'handles');
state = getappdata(hFig,'state');
o = state.original;
h.top.Position    = [o.left o.top;    o.right o.top];
h.bottom.Position = [o.left o.bottom; o.right o.bottom];
h.left.Position   = [o.left o.top;    o.left  o.bottom];
h.right.Position  = [o.right o.top;   o.right o.bottom];
h.mid.Position    = [o.midline o.top; o.midline o.bottom];
set_status(hFig,true,'Reset to auto-detected values.');
end

% =========================================================================
%  Filenames Menu
% =========================================================================
function dropdown_nav(hFig,src)
save_current(hFig);
state = getappdata(hFig,'state');
state.img_idx = src.Value;
setappdata(hFig,'state',state);
load_image(hFig);
end

% =========================================================================
%  HELPERS
% =========================================================================
function set_status(hFig,condition,msg_true,msg_false)
if nargin < 4, msg_false = ''; end
if condition, msg = msg_true; else, msg = msg_false; end
h = findobj(hFig,'Tag','statusText');
if ~isempty(h), set(h,'String',msg); end
end

function s = onoff(val)
if val, s = 'on'; else, s = 'off'; end
end

function name = fileparts_name(p)
[~,name] = fileparts(p);
end