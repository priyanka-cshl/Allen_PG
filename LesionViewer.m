function LesionViewer(results_path, atlas_folder)
% Paired brain slice and atlas viewer
% Usage: LesionViewer('brain_slice_all_results.mat', '/path/to/atlas/folder')

if nargin < 1
    [f,p] = uigetfile('*.mat','Select brain_slice_all_results.mat');
    if isequal(f,0), return; end
    results_path = fullfile(p,f);
end
if nargin < 2
    atlas_folder = uigetdir(pwd,'Select Atlas Folder (containing JPGs and AllenBounds.mat)');
    if isequal(atlas_folder,0), return; end
end

if exist(results_path,'dir')
    results_path = fullfile(results_path,'brain_slice_all_results.mat');
end

% --- Load data ---
fprintf('Loading results...\n');
res = load(results_path);

if isfield(res,'session')
    session = res.session;
else
    session = struct('slice_thickness',75,'ap_direction',1,...
        'scale',struct('is_set',false,'um_per_px',1));
end

fprintf('Loading atlas bounds...\n');
atlas_data = load(fullfile(atlas_folder,'AllenBounds.mat'));
allen      = atlas_data.results;

regions = [];
reg_file = fullfile(atlas_folder,'AllenRegions.mat');
if isfile(reg_file)
    rdata   = load(reg_file);
    regions = rdata.regions;
    fprintf('Loaded %d regions.\n', length(regions));
end

% --- Compute or load pairs ---
pairs_path = fullfile(fileparts(results_path),'brain_slice_atlas_pairs.mat');
if isfile(pairs_path)
    fprintf('Loading precomputed pairs...\n');
    pd       = load(pairs_path);
    pairs    = pd.pairs;
    comments = pd.comments;
else
    fprintf('Computing slice-atlas pairs...\n');
    [pairs, comments] = compute_pairs(res.all_results, allen, results_path, session);
    save(pairs_path,'pairs','comments');
    fprintf('Saved pairs to %s\n', pairs_path);
end

% --- Load or init LesionAnnotations ---
annot_path = fullfile(fileparts(results_path),'LesionAnnotations.mat');
if isfile(annot_path)
    fprintf('Loading LesionAnnotations...\n');
    ad = load(annot_path);
    annotations = ad.annotations;
else
    annotations = struct('lesions',[],'notes',struct());
end

% --- Load brain images ---
fields     = fieldnames(res.all_results);
img_folder = fileparts(res.all_results.(fields{1}).img_path);
d          = dir(fullfile(img_folder,'*.tif'));
img_list   = sort(cellfun(@(x) fullfile(img_folder,x),{d.name},'UniformOutput',false));
n_slices   = length(img_list);

fprintf('Preloading %d brain images...\n', n_slices);
gray_stack = cell(n_slices,1);
for i = 1:n_slices
    img = imread(img_list{i});
    if size(img,3) > 1, g = rgb2gray(img); else, g = img; end
    gray_stack{i} = single(mat2gray(double(g)));
end

% --- Figure ---
hFig = figure('Name','Lesion Viewer','NumberTitle','off',...
    'Position',[50 50 1400 820],'Color',[0.1 0.1 0.1]);
set(hFig,'Toolbar','none');

hAxBrain = axes(hFig,'Position',[0.02 0.22 0.46 0.74],'Color','k');
hAxAtlas = axes(hFig,'Position',[0.52 0.22 0.46 0.74],'Color','k');

% --- State ---
state.idx          = 1;
state.n            = n_slices;
state.img_list     = img_list;
state.gray_stack   = gray_stack;
state.pairs        = pairs;
state.comments     = comments;
state.all_results  = res.all_results;
state.allen        = allen;
state.atlas_folder = atlas_folder;
state.regions      = regions;
state.pairs_path   = pairs_path;
state.annot_path   = annot_path;
state.annotations  = annotations;
state.flip         = false;
state.hide_tracks  = false;

setappdata(hFig,'state',state);
setappdata(hFig,'handles',struct('brain',hAxBrain,'atlas',hAxAtlas));

% --- Panel ---
uipanel(hFig,'Units','normalized','Position',[0 0 1 0.21],...
    'BackgroundColor',[0.1 0.1 0.1]);

% Nav
uicontrol(hFig,'Style','pushbutton','String','< Prev',...
    'Units','normalized','Position',[0.01 0.14 0.07 0.05],...
    'Callback',@(~,~) nav(hFig,-1));
uicontrol(hFig,'Style','pushbutton','String','Next >',...
    'Units','normalized','Position',[0.09 0.14 0.07 0.05],...
    'Callback',@(~,~) nav(hFig,+1));

% Dropdown
uicontrol(hFig,'Style','popupmenu',...
    'Units','normalized','Position',[0.01 0.10 0.15 0.03],...
    'Tag','sliceDropdown',...
    'String',cellfun(@(x) fileparts_name(x), img_list,'UniformOutput',false),...
    'Value',1,...
    'Callback',@(src,~) dropdown_nav(hFig,src));

% Contrast slider
uicontrol(hFig,'Style','text','String','Contrast',...
    'Units','normalized','Position',[0.20 0.17 0.06 0.02],...
    'BackgroundColor',[0.1 0.1 0.1],'ForegroundColor','w','FontSize',8);
uicontrol(hFig,'Style','slider','Min',0.1,'Max',3.0,'Value',1.0,...
    'Units','normalized','Position',[0.20 0.14 0.15 0.03],...
    'Tag','contrastSlider',...
    'Callback',@(~,~) draw_slice(hFig));

% Row 1 toggles: Flip, AP, Hide Tracks
uicontrol(hFig,'Style','togglebutton','String','Flip Brain',...
    'Units','normalized','Position',[0.20 0.08 0.09 0.05],...
    'Tag','btnFlip','ForegroundColor','k','BackgroundColor',[0.6 0.6 0.6],...
    'Callback',@(src,~) toggle_flip(src,hFig));

uicontrol(hFig,'Style','togglebutton','String','AP: Post→Ant',...
    'Units','normalized','Position',[0.30 0.08 0.10 0.05],...
    'Tag','btnAPDir','ForegroundColor','k','BackgroundColor',[0.6 0.6 0.6],'Value',0,...
    'Callback',@(src,~) toggle_ap(src,hFig));

uicontrol(hFig,'Style','togglebutton','String','Hide Tracks',...
    'Units','normalized','Position',[0.41 0.08 0.09 0.05],...
    'Tag','btnHideTracks','ForegroundColor','k','BackgroundColor',[0.6 0.6 0.6],'Value',0,...
    'Callback',@(src,~) toggle_tracks(src,hFig));

% Row 2: 3D view buttons
uicontrol(hFig,'Style','pushbutton','String','3D View',...
    'Units','normalized','Position',[0.20 0.02 0.09 0.05],...
    'ForegroundColor','k','BackgroundColor',[0.5 0.7 0.5],...
    'Callback',@(~,~) open_3d_view(hFig));

uicontrol(hFig,'Style','pushbutton','String','Top (ML-AP)',...
    'Units','normalized','Position',[0.30 0.02 0.10 0.05],...
    'ForegroundColor','k','BackgroundColor',[0.5 0.6 0.7],...
    'Callback',@(~,~) set_3d_view(hFig,0,90));

uicontrol(hFig,'Style','pushbutton','String','Side (DV-AP)',...
    'Units','normalized','Position',[0.41 0.02 0.09 0.05],...
    'ForegroundColor','k','BackgroundColor',[0.5 0.6 0.7],...
    'Callback',@(~,~) set_3d_view(hFig,90,0));

% Save
uicontrol(hFig,'Style','pushbutton','String','Save',...
    'Units','normalized','Position',[0.92 0.14 0.07 0.05],...
    'ForegroundColor','w','BackgroundColor',[0.2 0.3 0.6],...
    'Callback',@(~,~) save_all(hFig));

% Comment box
uicontrol(hFig,'Style','text','String','Notes:',...
    'Units','normalized','Position',[0.55 0.18 0.05 0.02],...
    'BackgroundColor',[0.1 0.1 0.1],'ForegroundColor','w',...
    'FontSize',9,'HorizontalAlignment','left');
uicontrol(hFig,'Style','edit','String','',...
    'Units','normalized','Position',[0.55 0.02 0.32 0.15],...
    'Tag','commentBox','HorizontalAlignment','left','Max',5,...
    'BackgroundColor',[0.2 0.2 0.2],'ForegroundColor','w','FontSize',10);

% Status
uicontrol(hFig,'Style','text','String','Ready.',...
    'Units','normalized','Position',[0.01 0.0 0.98 0.02],...
    'BackgroundColor',[0.1 0.1 0.1],'ForegroundColor',[0.5 1 0.5],...
    'FontSize',8,'HorizontalAlignment','left','Tag','statusText');

draw_slice(hFig);
end

% =========================================================================
%  COMPUTE PAIRS
% =========================================================================
function [pairs, comments] = compute_pairs(all_results, allen, results_path, session)
fields    = fieldnames(all_results);
n_slices  = length(fields);
allen_aps = [allen.ap_mm];

ref_brain_idx = [];
ref_r         = [];
for fi = 1:n_slices
    r = all_results.(fields{fi});
    if isfield(r,'is_reference') && r.is_reference
        ref_brain_idx = str2double(fields{fi}(4:end));
        ref_r         = r;
        break;
    end
end
if isempty(ref_brain_idx)
    error('No reference slice found. Mark one slice as Reference in ProcessLesionImages.');
end

ref_ap      = 1.145;
slice_thick = session.slice_thickness / 1000;
um_per_px   = session.scale.um_per_px;

pairs    = struct();
comments = struct();

for fi = 1:n_slices
    key       = fields{fi};
    brain_idx = str2double(key(4:end));
    r         = all_results.(key);

    ap = ref_ap - session.ap_direction * (brain_idx - ref_brain_idx) * slice_thick;

    [~, allen_idx] = min(abs(allen_aps - ap));
    a              = allen(allen_idx);
    allen_um_per_px = 1000 / a.px_per_mm;

    pairs.(key).brain_idx       = brain_idx;
    pairs.(key).ap              = ap;
    pairs.(key).allen_idx       = allen_idx;
    pairs.(key).allen_ap        = a.ap_mm;
    pairs.(key).allen_filename  = a.filename;
    pairs.(key).brain_midline   = r.midline;
    pairs.(key).brain_top       = r.top;
    pairs.(key).brain_bottom    = r.bottom;
    pairs.(key).um_per_px       = um_per_px;
    pairs.(key).allen_midline   = a.midline;
    pairs.(key).allen_top       = a.top;
    pairs.(key).allen_um_per_px = allen_um_per_px;
    pairs.(key).contrast        = r.contrast;
    pairs.(key).brain_left      = r.left;
    pairs.(key).brain_right     = r.right;
    pairs.(key).allen_left      = a.left;
    pairs.(key).allen_right     = a.right;
    pairs.(key).allen_bottom    = a.bottom;
    pairs.(key).brain_bottom    = r.bottom;

    comments.(key) = '';

    fprintf('  Slice %d: AP=%.3fmm → Allen "%s" (AP=%.3fmm)\n',...
        brain_idx, ap, a.filename, a.ap_mm);
end
end

% =========================================================================
%  TRANSFORM BRAIN → ATLAS COORDS
% =========================================================================
function [ax, ay] = brain_to_atlas(bx, by, p, flipped)
if flipped
    bx = 2*p.brain_midline - bx;
end
scale_x = (p.allen_right - p.allen_midline) / (p.brain_right - p.brain_midline);
scale_y = (p.allen_bottom - p.allen_top)    / (p.brain_bottom - p.brain_top);
ax = p.allen_midline + (bx - p.brain_midline) * scale_x;
ay = p.allen_top     + (by - p.brain_top)     * scale_y;
end

% =========================================================================
%  IDENTIFY REGION FOR A POINT
% =========================================================================
function [region_name, edge_dist] = identify_region(ax, ay, regions, allen_idx)
region_name = 'Unknown';
edge_dist   = Inf;
if isempty(regions), return; end

for ri = 1:length(regions)
    rg = regions(ri);
    if ~isfield(rg,'boundaries') || isempty(rg.boundaries), continue; end
    if allen_idx > length(rg.boundaries) || isempty(rg.boundaries{allen_idx}), continue; end
    for bi = 1:length(rg.boundaries{allen_idx})
        bnd = rg.boundaries{allen_idx}{bi};
        if inpolygon(ax, ay, bnd(:,2), bnd(:,1))
            region_name = rg.name;
            dists     = sqrt((bnd(:,2)-ax).^2 + (bnd(:,1)-ay).^2);
            edge_dist = min(dists);
            return;
        end
    end
end
end

% =========================================================================
%  GENERATE AUTO-NOTES AND LESION LIST
% =========================================================================
function [notes, lesion_list] = generate_notes(key, r, p, regions)
n_holes  = 0;
n_tracks = 0;
if r.has_hole,      n_holes  = length(r.holes); end
if r.has_electrode, n_tracks = length(r.electrode_tracks); end

note_lines = {};
note_lines{end+1} = sprintf('%d lesion(s), %d track(s).', n_holes, n_tracks);

lesion_list = [];
for i = 1:n_holes
    [ax, ay] = brain_to_atlas(r.holes{i}.center(1), r.holes{i}.center(2), p, false);
    [region_name, edge_dist] = identify_region(ax, ay, regions, p.allen_idx);

    if isfinite(edge_dist)
        note_lines{end+1} = sprintf('Lesion %d: %s (edge dist=%.0fpx)', i, region_name, edge_dist);
    else
        note_lines{end+1} = sprintf('Lesion %d: %s', i, region_name);
    end

    le.img_key   = key;
    le.slice_idx = p.brain_idx;
    le.ap        = p.ap;
    le.allen_ap  = p.allen_ap;
    le.allen_x   = ax;
    le.allen_y   = ay;
    le.region    = region_name;
    le.edge_dist = edge_dist;
    if isempty(lesion_list)
        lesion_list = le;
    else
        lesion_list(end+1) = le;
    end
end

% Track endpoint regions
for i = 1:n_tracks
    t = r.electrode_tracks{i};
    if t.start(2) > t.end(2)
        tmp = t.start; t.start = t.end; t.end = tmp;
    end
    [ax1,ay1] = brain_to_atlas(t.start(1),t.start(2),p,false);
    [ax2,ay2] = brain_to_atlas(t.end(1),  t.end(2),  p,false);
    [r1,~]    = identify_region(ax1,ay1,regions,p.allen_idx);
    [r2,~]    = identify_region(ax2,ay2,regions,p.allen_idx);
    if strcmp(r1,r2)
        note_lines{end+1} = sprintf('Track %d: %s', i, r1);
    else
        note_lines{end+1} = sprintf('Track %d: %s → %s', i, r1, r2);
    end
end

notes = strjoin(note_lines, newline);
end

% =========================================================================
%  3D VIEW
% =========================================================================
function open_3d_view(hFig)
h3d = getappdata(hFig,'h3dFig');
if isempty(h3d) || ~isvalid(h3d)
    h3d = figure('Name','3D Reconstruction (Allen Space)','NumberTitle','off',...
        'Position',[1160 50 650 700],'Color','k');
    setappdata(hFig,'h3dFig',h3d);
end
update_3d_view(hFig);
end

function set_3d_view(hFig, az, el)
h3d = getappdata(hFig,'h3dFig');
if isempty(h3d) || ~isvalid(h3d)
    open_3d_view(hFig);
    h3d = getappdata(hFig,'h3dFig');
end
ax3 = getappdata(hFig,'h3dAx');
if ~isempty(ax3) && isvalid(ax3)
    view(ax3, az, el);
end
figure(hFig);
end

function update_3d_view(hFig)
state = getappdata(hFig,'state');
h3d   = getappdata(hFig,'h3dFig');
if isempty(h3d) || ~isvalid(h3d), return; end

figure(h3d); clf(h3d);
ax3 = axes(h3d,'Color','k','XColor','w','YColor','w','ZColor','w',...
    'GridColor','w','GridAlpha',0.15,'Position',[0.1 0.12 0.85 0.83]);
hold(ax3,'on'); grid(ax3,'on'); box(ax3,'on');
setappdata(hFig,'h3dAx',ax3);

% Compute mean vertical center for DV centering
fields     = fieldnames(state.pairs);
dv_centers = zeros(length(fields),1);
for fi = 1:length(fields)
    p = state.pairs.(fields{fi});
    dv_centers(fi) = (p.allen_top + p.allen_bottom) / 2 * p.allen_um_per_px;
end
dv_mean = mean(dv_centers);

n_fields     = length(fields);
slice_colors = lines(n_fields);

for fi = 1:length(fields)
    key = fields{fi};
    p   = state.pairs.(key);
    z   = p.ap * 1000; % mm → um

    if ~isfield(state.all_results,key), continue; end
    r = state.all_results.(key);

    % Lesions
    if r.has_hole && ~isempty(r.holes)
        for i = 1:length(r.holes)
            [ax,ay] = brain_to_atlas(r.holes{i}.center(1),r.holes{i}.center(2),p,false);
            ml = (ax - p.allen_midline) * p.allen_um_per_px;
            dv = ay * p.allen_um_per_px - dv_mean;
            base_col = slice_colors(fi,:);
            plot3(ax3,ml,z,dv,'o',...
                'MarkerSize',8,'MarkerFaceColor',base_col,'MarkerEdgeColor',base_col);
        end
    end

    % Tracks
    if r.has_electrode && ~isempty(r.electrode_tracks)
        for ti = 1:length(r.electrode_tracks)
            t  = r.electrode_tracks{ti};
            % Top to bottom
            if t.start(2) > t.end(2)
                tmp = t.start; t.start = t.end; t.end = tmp;
            end
            base_col = slice_colors(fi,:);
            lighten  = (ti-1) * 0.15;
            tc       = min(base_col + lighten, 1);

            [ax1,ay1] = brain_to_atlas(t.start(1),t.start(2),p,false);
            [ax2,ay2] = brain_to_atlas(t.end(1),  t.end(2),  p,false);
            ml1 = (ax1 - p.allen_midline) * p.allen_um_per_px;
            ml2 = (ax2 - p.allen_midline) * p.allen_um_per_px;
            dv1 = ay1 * p.allen_um_per_px - dv_mean;
            dv2 = ay2 * p.allen_um_per_px - dv_mean;

            plot3(ax3,[ml1 ml2],[z z],[dv1 dv2],'-','Color',tc,'LineWidth',2);
        end
    end
end

xlabel(ax3,'ML (um, 0=midline)','Color','w');
ylabel(ax3,'AP (um)','Color','w');
zlabel(ax3,'DV (um, centered)','Color','w');
title(ax3,'3D Reconstruction — Allen Space','Color','w');
set(ax3,'ZDir','reverse');
view(ax3,35,25);
rotate3d(ax3,'on');

% View buttons in 3D figure
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
%  DRAW SLICE
% =========================================================================
function draw_slice(hFig)
state = getappdata(hFig,'state');
h     = getappdata(hFig,'handles');
idx   = state.idx;
key   = sprintf('img%d',idx);

set(findobj(hFig,'Tag','sliceDropdown'),'Value',idx);

% Contrast
saved_contrast = 1.0;
if isfield(state.all_results,key) && isfield(state.all_results.(key),'contrast')
    saved_contrast = state.all_results.(key).contrast;
end
gamma = get(findobj(hFig,'Tag','contrastSlider'),'Value');
if gamma == 1.0
    gamma = saved_contrast;
    set(findobj(hFig,'Tag','contrastSlider'),'Value',gamma);
end
gray     = double(state.gray_stack{idx});
gray_adj = gray .^ (1/gamma);
if state.flip
    gray_adj = fliplr(gray_adj);
end

% --- Left: brain slice ---
cla(h.brain);
imshow(gray_adj,[],'Parent',h.brain);
hold(h.brain,'on');

ap_str = 'no annotations';
if isfield(state.all_results,key)
    r = state.all_results.(key);

    % Tracks and lesions (hidden together if toggled)
    if ~state.hide_tracks
        % Lesions
        if r.has_hole && ~isempty(r.holes)
            for i = 1:length(r.holes)
                cx = r.holes{i}.center(1);
                cy = r.holes{i}.center(2);
                if state.flip, cx = 2*r.midline - cx; end
                plot(h.brain,cx,cy,'o',...
                    'MarkerSize',10,'MarkerFaceColor','y','MarkerEdgeColor','y');
            end
        end
        % Tracks
        if r.has_electrode && ~isempty(r.electrode_tracks)
            for i = 1:length(r.electrode_tracks)
                t  = r.electrode_tracks{i};
                x1 = t.start(1); x2 = t.end(1);
                y1 = t.start(2); y2 = t.end(2);
                if y1 > y2, [x1,y1,x2,y2] = deal(x2,y2,x1,y1); end
                if state.flip
                    x1 = 2*r.midline - x1;
                    x2 = 2*r.midline - x2;
                end
                plot(h.brain,[x1 x2],[y1 y2],'-','Color',[1 0.5 0],'LineWidth',1.5);
            end
        end
    end

    if isfield(state.pairs,key)
        ap_str = sprintf('AP=%.3f mm', state.pairs.(key).ap);
    end
end

title(h.brain,sprintf('Brain Slice %d  |  %s',idx,ap_str),...
    'Color','w','FontSize',10);

% --- Right: Allen atlas ---
if isfield(state.pairs,key)
    p        = state.pairs.(key);
    img_path = fullfile(state.atlas_folder, p.allen_filename);

    cla(h.atlas);
    if isfile(img_path)
        allen_img = imread(img_path);
        image(h.atlas, allen_img);
    else
        image(h.atlas, zeros(100,100,3,'uint8'));
        text(0.5,0.5,'Image not found','Parent',h.atlas,...
            'Color','w','HorizontalAlignment','center');
    end
    axis(h.atlas,'image','off');
    hold(h.atlas,'on');

    % Region boundaries
    if ~isempty(state.regions)
        bcols = lines(length(state.regions));
        for ri = 1:length(state.regions)
            rg = state.regions(ri);
            if ~isfield(rg,'boundaries') || isempty(rg.boundaries), continue; end
            if p.allen_idx > length(rg.boundaries), continue; end
            if isempty(rg.boundaries{p.allen_idx}), continue; end
            col = bcols(ri,:);
            for bi = 1:length(rg.boundaries{p.allen_idx})
                bnd = rg.boundaries{p.allen_idx}{bi};
                plot(h.atlas,bnd(:,2),bnd(:,1),'-','Color',col,'LineWidth',1.5);
            end
        end
    end

    % Transformed lesions and tracks
    if isfield(state.all_results,key)
        r = state.all_results.(key);

        % Lesions
        if r.has_hole && ~isempty(r.holes)
            for i = 1:length(r.holes)
                [ax,ay] = brain_to_atlas(...
                    r.holes{i}.center(1),r.holes{i}.center(2),p,state.flip);
                plot(h.atlas,ax,ay,'o',...
                    'MarkerSize',10,'MarkerFaceColor','y','MarkerEdgeColor','y');
            end
        end

        % Tracks — always shown on Allen
        if r.has_electrode && ~isempty(r.electrode_tracks)
            for i = 1:length(r.electrode_tracks)
                t = r.electrode_tracks{i};
                [ax1,ay1] = brain_to_atlas(t.start(1),t.start(2),p,state.flip);
                [ax2,ay2] = brain_to_atlas(t.end(1),  t.end(2),  p,state.flip);
                if ay1 > ay2, [ax1,ay1,ax2,ay2] = deal(ax2,ay2,ax1,ay1); end
                plot(h.atlas,[ax1 ax2],[ay1 ay2],'-',...
                    'Color',[1 0.5 0],'LineWidth',1.5);
            end
        end

        % Transformed bounding box
        [ax_tl,ay_tl] = brain_to_atlas(r.left,  r.top,    p, state.flip);
        [ax_tr,ay_tr] = brain_to_atlas(r.right, r.top,    p, state.flip);
        [ax_bl,ay_bl] = brain_to_atlas(r.left,  r.bottom, p, state.flip);
        [ax_br,ay_br] = brain_to_atlas(r.right, r.bottom, p, state.flip);
        xbox = [ax_tl ax_tr ax_br ax_bl ax_tl];
        ybox = [ay_tl ay_tr ay_br ay_bl ay_tl];
        plot(h.atlas,xbox,ybox,'--','Color',[0.5 0.5 0.5],'LineWidth',1);

        % Auto-generate notes if not done yet for this slice
        if ~isempty(state.regions) && (r.has_hole || r.has_electrode)
            if ~isfield(state.annotations.notes,key) || ...
                    isempty(state.annotations.notes.(key))
                [auto_notes, lesion_list] = generate_notes(key, r, p, state.regions);
                state.annotations.notes.(key) = auto_notes;
                for li = 1:length(lesion_list)
                    if isempty(state.annotations.lesions)
                        state.annotations.lesions = lesion_list(li);
                    else
                        already = any(strcmp({state.annotations.lesions.img_key}, key) & ...
                            [state.annotations.lesions.allen_x] == lesion_list(li).allen_x);
                        if ~already
                            state.annotations.lesions(end+1) = lesion_list(li);
                        end
                    end
                end
                setappdata(hFig,'state',state);
            end
        end
    end

    title(h.atlas,sprintf('Allen  |  AP=%.3fmm  (brain AP=%.3fmm)',...
        p.allen_ap,p.ap),'Color','w','FontSize',10);
else
    cla(h.atlas);
    title(h.atlas,'No atlas match','Color','w','FontSize',10);
end

% Load notes into comment box
if isfield(state.annotations.notes,key)
    set(findobj(hFig,'Tag','commentBox'),'String',state.annotations.notes.(key));
elseif isfield(state.comments,key)
    set(findobj(hFig,'Tag','commentBox'),'String',state.comments.(key));
else
    set(findobj(hFig,'Tag','commentBox'),'String','');
end

set_status(hFig,sprintf('Slice %d of %d',idx,state.n));
end

% =========================================================================
%  NAVIGATION
% =========================================================================
function nav(hFig,direction)
save_note_current(hFig);
state = getappdata(hFig,'state');
new_idx = state.idx + direction;
if new_idx < 1 || new_idx > state.n
    set_status(hFig,'No more slices.');
    return;
end
state.idx = new_idx;
setappdata(hFig,'state',state);
draw_slice(hFig);
end

function dropdown_nav(hFig,src)
save_note_current(hFig);
state = getappdata(hFig,'state');
state.idx = src.Value;
setappdata(hFig,'state',state);
draw_slice(hFig);
end

% =========================================================================
%  TOGGLES
% =========================================================================
function toggle_flip(src,hFig)
state = getappdata(hFig,'state');
state.flip = logical(src.Value);
setappdata(hFig,'state',state);
draw_slice(hFig);
end

function toggle_tracks(src,hFig)
state = getappdata(hFig,'state');
state.hide_tracks = logical(src.Value);
setappdata(hFig,'state',state);
draw_slice(hFig);
end

function toggle_ap(src,hFig)
state = getappdata(hFig,'state');
fields = fieldnames(state.pairs);
ref_ap = 1.145;
for fi = 1:length(fields)
    key = fields{fi};
    if src.Value
        src.String = 'AP: Ant→Post';
        state.pairs.(key).ap = ref_ap - ...
            (state.pairs.(key).brain_idx - state.pairs.(fields{1}).brain_idx) * 0.075;
    else
        src.String = 'AP: Post→Ant';
        state.pairs.(key).ap = ref_ap + ...
            (state.pairs.(key).brain_idx - state.pairs.(fields{1}).brain_idx) * 0.075;
    end
    allen_aps = [state.allen.ap_mm];
    [~,allen_idx] = min(abs(allen_aps - state.pairs.(key).ap));
    state.pairs.(key).allen_idx       = allen_idx;
    state.pairs.(key).allen_ap        = state.allen(allen_idx).ap_mm;
    state.pairs.(key).allen_filename  = state.allen(allen_idx).filename;
    state.pairs.(key).allen_midline   = state.allen(allen_idx).midline;
    state.pairs.(key).allen_top       = state.allen(allen_idx).top;
    state.pairs.(key).allen_left      = state.allen(allen_idx).left;
    state.pairs.(key).allen_right     = state.allen(allen_idx).right;
    state.pairs.(key).allen_bottom    = state.allen(allen_idx).bottom;
    state.pairs.(key).allen_um_per_px = 1000/state.allen(allen_idx).px_per_mm;
end
setappdata(hFig,'state',state);
draw_slice(hFig);
end

% =========================================================================
%  SAVE
% =========================================================================
function save_note_current(hFig)
state = getappdata(hFig,'state');
key   = sprintf('img%d',state.idx);
note  = get(findobj(hFig,'Tag','commentBox'),'String');
state.annotations.notes.(key) = note;
state.comments.(key)          = note;
setappdata(hFig,'state',state);
end

function save_all(hFig)
save_note_current(hFig);
state       = getappdata(hFig,'state');
pairs       = state.pairs;
comments    = state.comments;
annotations = state.annotations;

save(state.pairs_path,'pairs','comments');
save(state.annot_path,'annotations');
assignin('base','annotations',annotations);

fprintf('Saved pairs to %s\n',state.pairs_path);
fprintf('Saved LesionAnnotations to %s\n',state.annot_path);
if ~isempty(annotations.lesions)
    fprintf('annotations.lesions: %d entries\n', length(annotations.lesions));
end
set_status(hFig,'Saved.');
end

% =========================================================================
%  HELPERS
% =========================================================================
function set_status(hFig,msg)
h = findobj(hFig,'Tag','statusText');
if ~isempty(h), set(h,'String',msg); end
end

function name = fileparts_name(p)
[~,name] = fileparts(p);
end
