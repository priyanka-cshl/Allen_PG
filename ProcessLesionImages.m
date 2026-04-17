function ProcessLesionImages(img_path)
if nargin < 1
    img_path = 'Image_000001.tif';
end

% --- Get image list from folder ---
if exist(img_path) == 7 % folder
    folder = img_path;
else
    [folder, ~, ext] = fileparts(img_path);
end
if isempty(folder), folder = pwd; end
extensions = {'*.tif'};
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

setappdata(hFig,'handles',struct('ax',hAx));
set_status(hFig,true,'Loading images...');

state.all_results = struct();
% Auto-load session if it exists
session_file = fullfile(folder, 'brain_slice_all_results.mat');
if isfile(session_file)
    loaded = load(session_file);
    if isfield(loaded,'all_results')
        state.all_results = loaded.all_results;
        fprintf('Session auto-loaded from %s\n', session_file);
    end
end

% Preload all images and run auto-detect
gray_stack  = cell(length(img_list),1);
auto_bounds = cell(length(img_list),1);
for i = 1:length(img_list)
    img = imread(img_list{i});
    if size(img,3) > 1, g = rgb2gray(img); else, g = img; end
    gray_stack{i} = single(mat2gray(double(g)));
    key = sprintf('img%d',i);
    if isfield(state.all_results, key)
        r = state.all_results.(key);
        auto_bounds{i} = struct('left',r.left,'right',r.right,...
            'top',r.top,'bottom',r.bottom,'midline',r.midline);
    else
        [l,rt,t,b,m]   = auto_detect(gray_stack{i});
        auto_bounds{i} = struct('left',l,'right',rt,'top',t,'bottom',b,'midline',m);
    end
    fprintf('  Loaded %d/%d\n', i, length(img_list));
end
setappdata(hFig,'gray_stack',gray_stack);
setappdata(hFig,'auto_bounds',auto_bounds);

% --- State ---
state.img_list         = img_list;
state.img_idx          = img_idx;
state.holes            = {};
state.electrode_tracks = {};
state.has_hole         = false;
state.has_electrode    = false;
state.slice_thickness  = 75; % um
state.ap_direction     = 1;  % 1 = first slice is anterior, -1 = first slice is posterior
% Scale: pixels to um
state.scale.is_set      = false;
state.scale.um_per_px   = 1;
state.scale.p1          = [];
state.scale.p2          = [];
state.scale.distance_px = 0;
state.scale.distance_um = 0;
state.scale.img_idx     = [];

% Restore scale from session if saved
if isfield(loaded,'scale')
    state.scale = loaded.scale;
end

setappdata(hFig,'state',state);

% --- Panel ---
uipanel(hFig,'Units','normalized','Position',[0 0 1 0.16],...
    'BackgroundColor',[0.15 0.15 0.15]);

% Nav buttons
uicontrol(hFig,'Style','pushbutton','String','< Prev',...
    'Units','normalized','Position',[0.01 0.06 0.07 0.05],...
    'Callback',@(~,~) nav_image(hFig,-1));
uicontrol(hFig,'Style','pushbutton','String','Next >',...
    'Units','normalized','Position',[0.09 0.06 0.07 0.05],...
    'Callback',@(~,~) nav_image(hFig,+1));

% Filenames dropdown Menu
uicontrol(hFig,'Style','popupmenu',...
    'Units','normalized','Position',[0.01 0.01 0.15 0.04],...
    'Tag','imgDropdown',...
    'String',cellfun(@(x) fileparts_name(x), img_list, 'UniformOutput', false),...
    'Value',img_idx,...
    'Callback',@(src,~) dropdown_nav(hFig,src));

% Status bar
uicontrol(hFig,'Style','text','String','Ready.',...
    'Units','normalized','Position',[0.01 0.12 0.98 0.02],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.5 1 0.5],...
    'FontSize',10,'HorizontalAlignment','left','Tag','statusText');

% Slice Annotations label
uicontrol(hFig,'Style','text','String','SLICE ANNOTATIONS',...
    'Units','normalized','Position',[0.16 0.112 0.18 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','y',...
    'FontWeight','bold','FontSize',8);

% Contrast slider
uicontrol(hFig,'Style','text','String','Contrast',...
    'Units','normalized','Position',[0.66 0.11 0.06 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w','FontSize',8);
uicontrol(hFig,'Style','slider','Min',0.1,'Max',3.0,'Value',1.0,...
    'Units','normalized','Position',[0.52 0.09 0.19 0.025],...
    'Tag','contrastSlider',...
    'Callback',@(src,~) update_contrast(src,hFig));

% Select as reference checkbox
uicontrol(hFig,'Style','checkbox','String','Reference',...
    'Units','normalized','Position',[0.2 0.09 0.09 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[1 0.8 0],...
    'Tag','chkReference');

% Scale image checkbox
uicontrol(hFig,'Style','checkbox','String','Scale Image',...
    'Units','normalized','Position',[0.2 0.05 0.09 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.5 0.8 1],...
    'Tag','chkScale');
uicontrol(hFig,'Style','pushbutton','String','Set Scale',...
    'Units','normalized','Position',[0.2 0.01 0.09 0.03],...
    'Callback',@(~,~) set_scale(hFig));
uicontrol(hFig,'Style','pushbutton','String','Clear Scale',...
    'Units','normalized','Position',[0.3 0.01 0.09 0.03],...
    'Callback',@(~,~) clear_scale(hFig));
uicontrol(hFig,'Style','text','String','No scale set',...
    'Units','normalized','Position',[0.3 0.04 0.10 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor',[0.5 0.8 1],...
    'FontSize',8,'HorizontalAlignment','left','Tag','scaleText');

% Lesion controls
uicontrol(hFig,'Style','checkbox','String','Has Lesion',...
    'Units','normalized','Position',[0.42 0.05 0.09 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w',...
    'Tag','chkHole','Callback',@(src,~) toggle_hole(src,hFig));
uicontrol(hFig,'Style','pushbutton','String','Add Hole',...
    'Units','normalized','Position',[0.52 0.05 0.09 0.03],...
    'Tag','btnAddHole','Enable','off',...
    'Callback',@(~,~) add_hole(hFig));
uicontrol(hFig,'Style','pushbutton','String','Clear Holes',...
    'Units','normalized','Position',[0.62 0.05 0.09 0.03],...
    'Tag','btnClearHoles','Enable','off',...
    'Callback',@(~,~) clear_holes(hFig));

% Electrode controls
uicontrol(hFig,'Style','checkbox','String','Has Tracks',...
    'Units','normalized','Position',[0.42 0.01 0.09 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w',...
    'Tag','chkElectrode','Callback',@(src,~) toggle_electrode(src,hFig));
uicontrol(hFig,'Style','pushbutton','String','Add Track',...
    'Units','normalized','Position',[0.52 0.01 0.09 0.03],...
    'Tag','btnAddTrack','Enable','off',...
    'Callback',@(~,~) add_electrode(hFig));
uicontrol(hFig,'Style','pushbutton','String','Clear Tracks',...
    'Units','normalized','Position',[0.62 0.01 0.09 0.03],...
    'Tag','btnClearTracks','Enable','off',...
    'Callback',@(~,~) clear_electrodes(hFig));

% Hide/show annotations toggle
uicontrol(hFig,'Style','togglebutton','String','Hide Annotations',...
    'Units','normalized','Position',[0.72 0.01 0.15 0.04],...
    'Tag','btnHide',...
    'Callback',@(src,~) toggle_visibility(src,hFig));

% Slice thickness input
uicontrol(hFig,'Style','text','String','Slice (um)',...
    'Units','normalized','Position',[0.3 0.08 0.03 0.03],...
    'BackgroundColor',[0.15 0.15 0.15],'ForegroundColor','w','FontSize',8);
uicontrol(hFig,'Style','edit','String','75',...
    'Units','normalized','Position',[0.34 0.08 0.05 0.03],...
    'Tag','sliceThickness',...
    'Callback',@(src,~) update_slice_thickness(src,hFig));

% AP direction toggle
uicontrol(hFig,'Style','togglebutton','String','Ant-Pos',...
    'Units','normalized','Position',[0.42 0.09 0.08 0.04],...
    'Tag','btnAPDir',...
    'Value',0,... % 0 = anterior first
    'Callback',@(src,~) toggle_ap_direction(src,hFig));

% 3D view button
uicontrol(hFig,'Style','pushbutton','String','3D View',...
    'Units','normalized','Position',[0.72 0.07 0.15 0.04],...
    'Callback',@(~,~) open_3d_view(hFig));

% General buttons
uicontrol(hFig,'Style','pushbutton','String','Save All',...
    'Units','normalized','Position',[0.92 0.01 0.07 0.04],...
    'Callback',@(~,~) save_all(hFig));
uicontrol(hFig,'Style','pushbutton','String','Reset',...
    'Units','normalized','Position',[0.92 0.06 0.07 0.04],...
    'Callback',@(~,~) reset_lines(hFig));

% Update scale display if scale was loaded from session
if state.scale.is_set
    set(findobj(hFig,'Tag','scaleText'),...
        'String',sprintf('%.4f um/px', state.scale.um_per_px));
end

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

% Get preloaded image
gray_stack = getappdata(hFig,'gray_stack');
gray_norm  = double(gray_stack{idx});
setappdata(hFig,'gray_norm',gray_norm);

% Clear axes and redraw image
cla(h.ax);
imshow(gray_norm,[],'Parent',h.ax);
hold(h.ax,'on');

% Clear state
state.holes            = {};
state.electrode_tracks = {};
state.has_hole         = false;
state.has_electrode    = false;

% Reset all controls
set(findobj(hFig,'Tag','chkHole'),        'Value',0);
set(findobj(hFig,'Tag','chkElectrode'),   'Value',0);
set(findobj(hFig,'Tag','btnAddHole'),     'Enable','off');
set(findobj(hFig,'Tag','btnClearHoles'),  'Enable','off');
set(findobj(hFig,'Tag','btnAddTrack'),    'Enable','off');
set(findobj(hFig,'Tag','btnClearTracks'), 'Enable','off');
set(findobj(hFig,'Tag','chkReference'),   'Value',0);
set(findobj(hFig,'Tag','chkScale'),       'Value',0);
set(findobj(hFig,'Tag','contrastSlider'), 'Value',1.0);
set(findobj(hFig,'Tag','btnHide'),        'Value',0,'String','Hide Annotations');

% Get bounds — from saved results or auto-detected
key = sprintf('img%d',idx);
if isfield(state.all_results, key)
    r         = state.all_results.(key);
    left      = r.left;
    right     = r.right;
    top       = r.top;
    bottom    = r.bottom;
    midline_x = r.midline;

    set(findobj(hFig,'Tag','contrastSlider'),'Value',r.contrast);
    update_contrast(findobj(hFig,'Tag','contrastSlider'),hFig);
    set(findobj(hFig,'Tag','chkReference'),'Value',r.is_reference);
    if isfield(r,'is_scale')
        set(findobj(hFig,'Tag','chkScale'),'Value',r.is_scale);
    end

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
else
    % Use precomputed auto-detect bounds
    auto_bounds = getappdata(hFig,'auto_bounds');
    ab        = auto_bounds{idx};
    left      = ab.left;
    right     = ab.right;
    top       = ab.top;
    bottom    = ab.bottom;
    midline_x = ab.midline;
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

% Refresh 3D view if open
update_3d_view(hFig);
end

% =========================================================================
%  3D VIEW
% =========================================================================
function update_3d_view(hFig)
save_current(hFig);
state = getappdata(hFig,'state');

% Only draw if figure is already open (don't auto-create)
h3d = getappdata(hFig,'h3dFig');
if isempty(h3d) || ~isvalid(h3d)
    % Create only when explicitly opened via button
    % (auto-refresh only if already open)
    %if ~strcmp(get(hFig,'CurrentObject'),'') || isempty(h3d)
        return;
    %end
end

figure(h3d);
clf(h3d);
ax3 = axes(h3d,'Color','k','XColor','w','YColor','w','ZColor','w',...
    'GridColor','w','GridAlpha',0.15,'Position',[0.1 0.12 0.85 0.83]);
hold(ax3,'on');
grid(ax3,'on');
box(ax3,'on');

thickness   = state.slice_thickness;
um_per_px   = state.scale.um_per_px;
fields      = fieldnames(state.all_results);
n_slices    = length(state.img_list);
slice_colors = lines(length(fields));

for fi = 1:length(fields)
    r   = state.all_results.(fields{fi});
    idx = str2double(fields{fi}(4:end));

    % AP axis: direction toggle
    if state.ap_direction == 1
        % First slice = most anterior → Z increases posteriorly
        z = (idx-1) * thickness;
    else
        % First slice = most posterior → Z decreases anteriorly
        z = (n_slices - idx) * thickness;
    end

    % Alignment offsets
    mid_x   = r.midline;
    bbox_top = r.top;  % Y=0 at top of bounding box

    % --- Holes (yellow dots) ---
    if r.has_hole && ~isempty(r.holes)
        for hi = 1:length(r.holes)
            % ML: col - midline (negative=left, positive=right)
            ml = (r.holes{hi}.center(1) - mid_x) * um_per_px;
            % DV: row - top of bbox (0=dorsal, positive=ventral)
            dv = (r.holes{hi}.center(2) - bbox_top) * um_per_px;
            plot3(ax3, ml, z, dv, 'o',...
                'MarkerSize',8,'MarkerFaceColor','y','MarkerEdgeColor','y');
        end
    end

    % --- Tracks ---
    if r.has_electrode && ~isempty(r.electrode_tracks)
        for ti = 1:length(r.electrode_tracks)
            t  = r.electrode_tracks{ti};
            % Base color for this slice, lightened for each track
            base = slice_colors(fi,:);
            lighten = (ti-1) * 0.15; % each track gets progressively lighter
            tc = min(base + lighten, 1);

            ml1 = (t.start(1) - mid_x)   * um_per_px;
            dv1 = (t.start(2) - bbox_top) * um_per_px;
            ml2 = (t.end(1)   - mid_x)   * um_per_px;
            dv2 = (t.end(2)   - bbox_top) * um_per_px;

            % X=ML, Y=AP(Z), Z=DV
            plot3(ax3,[ml1 ml2],[z z],[dv1 dv2],'-',...
                'Color',tc,'LineWidth',2);
        end
    end
end

% Axis labels with units
xlabel(ax3,'ML (um, 0=midline)','Color','w');
ylabel(ax3,'AP (um)','Color','w');
zlabel(ax3,'DV (um, 0=dorsal)','Color','w');

ap_dir_str = 'Anterior→Posterior';
if state.ap_direction == -1, ap_dir_str = 'Posterior→Anterior'; end
scale_str = sprintf('Scale: %.4f um/px', um_per_px);
title(ax3,sprintf('3D Reconstruction  |  %s  |  %s', ap_dir_str, scale_str),'Color','w');

% Flip Z axis so dorsal is up
set(ax3,'ZDir','reverse');

view(ax3,35,25);
rotate3d(ax3,'on');

% View buttons
uicontrol(h3d,'Style','pushbutton','String','3D View',...
    'Units','normalized','Position',[0.01 0.01 0.12 0.05],...
    'Callback',@(~,~) view(ax3,35,25));
uicontrol(h3d,'Style','pushbutton','String','Top (ML-AP)',...
    'Units','normalized','Position',[0.14 0.01 0.14 0.05],...
    'Callback',@(~,~) view(ax3,0,90));
uicontrol(h3d,'Style','pushbutton','String','Side (DV-AP)',...
    'Units','normalized','Position',[0.29 0.01 0.14 0.05],...
    'Callback',@(~,~) view(ax3,90,0));
uicontrol(h3d,'Style','pushbutton','String','Front (ML-DV)',...
    'Units','normalized','Position',[0.44 0.01 0.14 0.05],...
    'Callback',@(~,~) view(ax3,0,0));

figure(hFig);
end

% =========================================================================
%  OPEN 3D VIEW (called by button)
% =========================================================================
function open_3d_view(hFig)
state = getappdata(hFig,'state');
h3d = getappdata(hFig,'h3dFig');
if isempty(h3d) || ~isvalid(h3d)
    h3d = figure('Name','3D Reconstruction','NumberTitle','off',...
        'Position',[1160 50 650 700],'Color','k');
    setappdata(hFig,'h3dFig',h3d);
end
update_3d_view(hFig);
end

% =========================================================================
%  AP DIRECTION TOGGLE
% =========================================================================
function toggle_ap_direction(src,hFig)
state = getappdata(hFig,'state');
if src.Value
    state.ap_direction = -1;
    src.String = 'Pos-Ant';
else
    state.ap_direction = 1;
    src.String = 'Ant-Pos';
end
setappdata(hFig,'state',state);
end

% =========================================================================
%  SCALE CALIBRATION
% =========================================================================
function set_scale(hFig)
h     = getappdata(hFig,'handles');
state = getappdata(hFig,'state');

set_status(hFig,true,'Click point 1 on scale image...');
[x1,y1] = ginput(1);
% Draw first point marker
hp1 = plot(h.ax, x1, y1, '+', 'Color','c','MarkerSize',12,'LineWidth',1.5);

set_status(hFig,true,'Click point 2 on scale image...');
[x2,y2] = ginput(1);
hp2 = plot(h.ax, x2, y2, '+', 'Color','c','MarkerSize',12,'LineWidth',1.5);
hln = plot(h.ax,[x1 x2],[y1 y2],'-','Color','c','LineWidth',1);

dist_px = sqrt((x2-x1)^2 + (y2-y1)^2);

% Ask for known distance
answer = inputdlg('Enter known distance between points (um):',...
    'Scale Calibration', 1, {'100'});
if isempty(answer)
    delete(hp1); delete(hp2); delete(hln);
    set_status(hFig,true,'Scale calibration cancelled.');
    return;
end

dist_um = str2double(answer{1});
if isnan(dist_um) || dist_um <= 0
    delete(hp1); delete(hp2); delete(hln);
    set_status(hFig,true,'Invalid distance entered.');
    return;
end

um_per_px = dist_um / dist_px;

state.scale.is_set      = true;
state.scale.um_per_px   = um_per_px;
state.scale.p1          = [x1 y1];
state.scale.p2          = [x2 y2];
state.scale.distance_px = dist_px;
state.scale.distance_um = dist_um;
state.scale.img_idx     = state.img_idx;

setappdata(hFig,'state',state);

% Mark current image as scale image
set(findobj(hFig,'Tag','chkScale'),'Value',1);
set(findobj(hFig,'Tag','scaleText'),...
    'String',sprintf('%.4f um/px', um_per_px));

set_status(hFig,true,sprintf('Scale set: %.4f um/px  (%.1f px = %.1f um)',...
    um_per_px, dist_px, dist_um));
end

function clear_scale(hFig)
state = getappdata(hFig,'state');
state.scale.is_set    = false;
state.scale.um_per_px = 1;
state.scale.p1        = [];
state.scale.p2        = [];
state.scale.distance_px = 0;
state.scale.distance_um = 0;
state.scale.img_idx   = [];
setappdata(hFig,'state',state);
set(findobj(hFig,'Tag','scaleText'),'String','No scale set');
set(findobj(hFig,'Tag','chkScale'),'Value',0);
set_status(hFig,true,'Scale cleared.');
end

% =========================================================================
%  SLICE THICKNESS
% =========================================================================
function update_slice_thickness(src,hFig)
val = str2double(src.String);
if isnan(val) || val <= 0
    set(src,'String','75');
    val = 75;
end
state = getappdata(hFig,'state');
state.slice_thickness = val;
setappdata(hFig,'state',state);
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
r.is_scale     = logical(get(findobj(hFig,'Tag','chkScale'),'Value'));

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
scale       = state.scale;
assignin('base','all_results',all_results);
assignin('base','scale',scale);
save(fullfile(fileparts(state.img_list{1}),'brain_slice_all_results.mat'),...
    'all_results','scale');
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

if ~isvalid(hRoi)
    set_status(hFig,true,'Hole drawing cancelled.');
    return;
end

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
%  DROPDOWN NAV
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
