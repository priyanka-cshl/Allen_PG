function ProcessLesionImage(img_path)
if nargin < 1
    img_path = 'Image_000001.tif';
end

% --- Load and preprocess ---
img = imread(img_path);
if size(img, 3) > 1
    gray = rgb2gray(img);
else
    gray = img;
end
gray_norm = mat2gray(double(gray));

% --- Auto-detect mask and bounds ---
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

props = regionprops(mask_clean, 'BoundingBox', 'Centroid');
bbox = props.BoundingBox;
left   = bbox(1);
top    = bbox(2);
right  = bbox(1) + bbox(3);
bottom = bbox(2) + bbox(4);

[rows, cols] = find(mask_clean);
row_ids = unique(rows);
mid_per_row = zeros(length(row_ids), 1);
for i = 1:length(row_ids)
    r = row_ids(i);
    rc = cols(rows == r);
    mid_per_row(i) = (min(rc) + max(rc)) / 2;
end
midline_x = median(mid_per_row);

% --- State ---
state.original  = struct('left',left,'right',right,'top',top,...
                         'bottom',bottom,'midline',midline_x);
state.holes              = {};
state.electrode_tracks   = {};
state.has_hole           = false;
state.has_electrode      = false;

% --- Figure ---
hFig = figure('Name','Brain Slice Editor','NumberTitle','off',...
    'Position',[50 50 1100 880]);
hAx = axes(hFig,'Position',[0.05 0.18 0.9 0.78]);
imshow(gray_norm,[],'Parent',hAx);
hold(hAx,'on');

% Bounding box and midline - no labels
mylinewidth = 0.5;
hTop    = drawline(hAx,'Position',[left top; right top],            'Color','g', 'LineWidth',mylinewidth);
hBottom = drawline(hAx,'Position',[left bottom; right bottom],      'Color','g', 'LineWidth',mylinewidth);
hLeft   = drawline(hAx,'Position',[left top; left bottom],          'Color','g', 'LineWidth',mylinewidth);
hRight  = drawline(hAx,'Position',[right top; right bottom],        'Color','g', 'LineWidth',mylinewidth);
hMid    = drawline(hAx,'Position',[midline_x top; midline_x bottom],'Color','c', 'LineWidth',mylinewidth);

setappdata(hFig,'handles',struct('top',hTop,'bottom',hBottom,...
    'left',hLeft,'right',hRight,'mid',hMid,'ax',hAx));
setappdata(hFig,'state',state);

% --- Panel ---
uipanel(hFig,'Units','normalized','Position',[0 0 1 0.155],...
    'BackgroundColor',[0.15 0.15 0.15]);

% General buttons
uicontrol(hFig,'Style','pushbutton','String','Save Results',...
    'Units','normalized','Position',[0.01 0.08 0.13 0.07],...
    'Callback',@(~,~) save_results(hFig));
uicontrol(hFig,'Style','pushbutton','String','Reset Lines',...
    'Units','normalized','Position',[0.01 0.02 0.13 0.05],...
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

% Status bar
uicontrol(hFig,'Style','text','String','Ready.',...
    'Units','normalized','Position',[0.01 0.0 0.98 0.02],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.5 1 0.5],...
    'FontSize',8,'HorizontalAlignment','left','Tag','statusText');
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
set_status(hFig, state.has_hole, 'Hole mode ON — click Add Hole to mark','Hole mode OFF');
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

% First click
[x1,y1] = ginput(1);

% Second click
set_status(hFig,true,'Click point 2 of electrode track...');
[x2,y2] = ginput(1);
hLine = plot(h.ax,[x1 x2],[y1 y2],'-','Color',[1 0.5 0],'LineWidth',0.75);

dx = x2-x1; dy = y2-y1;
angle_deg  = atan2d(dy,dx);
length_px  = sqrt(dx^2+dy^2);

track = struct('hLine',hLine,...
    'start',[x1 y1],'end',[x2 y2],...
    'angle_deg',angle_deg,'length_px',length_px);
state.electrode_tracks{end+1} = track;
setappdata(hFig,'state',state);
set_status(hFig,true,sprintf('Track %d drawn. Angle: %.1f°  Length: %.1f px',...
    n, angle_deg, length_px));
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
%  SAVE / RESET
% =========================================================================
function save_results(hFig)
h = getappdata(hFig,'handles');
state = getappdata(hFig,'state');

% Extract current line positions directly from handles
results.left    = mean(h.left.Position(:,1));
results.right   = mean(h.right.Position(:,1));
results.top     = mean(h.top.Position(:,2));
results.bottom  = mean(h.bottom.Position(:,2));
results.midline = mean(h.mid.Position(:,1));

results.has_hole = state.has_hole;
results.holes    = {};
for i = 1:length(state.holes)
    results.holes{i} = state.holes{i}.pos;
end

results.has_electrode    = state.has_electrode;
results.electrode_tracks = {};
for i = 1:length(state.electrode_tracks)
    t = state.electrode_tracks{i};
    results.electrode_tracks{i} = struct(...
        'start',    t.start,...
        'end',      t.end,...
        'angle_deg',t.angle_deg,...
        'length_px',t.length_px);
end

assignin('base','brain_slice_results',results);
save('brain_slice_results.mat','-struct','results');
fprintf('Saved to workspace and brain_slice_results.mat\n');
set_status(hFig,true,'Saved to workspace and .mat file.');
end

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
%  HELPERS
% =========================================================================
function set_status(hFig,condition,msg_true,msg_false)
if nargin < 4, msg_false = ''; end
msg = ''; 
if condition, msg = msg_true; else, msg = msg_false; end
h = findobj(hFig,'Tag','statusText');
if ~isempty(h), set(h,'String',msg); end
end

function s = onoff(val)
if val, s = 'on'; else, s = 'off'; end
end