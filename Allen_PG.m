function varargout = Allen_PG(varargin)
% ALLEN_PG MATLAB code for Allen_PG.fig
%      ALLEN_PG, by itself, creates a new ALLEN_PG or raises the existing
%      singleton*.
%
%      H = ALLEN_PG returns the handle to a new ALLEN_PG or the handle to
%      the existing singleton*.
%
%      ALLEN_PG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in ALLEN_PG.M with the given input arguments.
%
%      ALLEN_PG('Property','Value',...) creates a new ALLEN_PG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Allen_PG_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Allen_PG_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Allen_PG

% Last Modified by GUIDE v2.5 16-Mar-2021 16:36:32

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Allen_PG_OpeningFcn, ...
                   'gui_OutputFcn',  @Allen_PG_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Allen_PG is made visible.
function Allen_PG_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Allen_PG (see VARARGIN)

% Choose default command line output for Allen_PG
handles.output = hObject;
handles.useserver = 0;
handles.figure1.Position = [0.4882 0.3511 0.4868 0.5889];

% Parse inputs

if ~isempty(varargin)
    if isnumeric(varargin{1}) % user entered coordinates
        handles.Coordinates.Data(1) = varargin{1}(1);
        handles.Coordinates.Data(2) = varargin{1}(2);
        handles.Coordinates.Data(3) = varargin{1}(3);
        
        handles.figure1.Position = [0.4882 0.3511 0.4868 0.5889];
        UpdateSection_Callback(hObject, eventdata, handles);
        
    else % user entered a mouse name
        handles.MouseName = varargin{1};
        
        handles.computername = getenv('COMPUTERNAME');
        
        if ~isempty(char(handles.computername))
            switch char(handles.computername)
                case {'JUSTINE','BALTHAZAR'}
                    handles.LocalFile = ['C:\Data\Behavior\',varargin{1},'_DepthLog.mat'];
                    handles.ServerFile = ['\\grid-hs\albeanu_nlsas_norepl_data\pgupta\Behavior\',varargin{1},'_DepthLog.mat'];
                    handles.useserver = 1;
            end
        else
            % hack for my mac laptop
             handles.LocalFile = ['/Users/Priyanka/Desktop/LABWORK_II/Data/Behavior/',varargin{1},'_DepthLog.mat'];
             handles.ServerFile = [];
             handles.useserver = 0;
        end
        handles.figure1.Position = [0.4882 0.3511 0.63 0.5889];
        LoadDrive_Callback(hObject, eventdata, handles);
    end
else
    handles.figure1.Position = [0.4882 0.3511 0.4868 0.5889];
    UpdateSection_Callback(hObject, eventdata, handles);
end
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Allen_PG wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = Allen_PG_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in UpdateSection.
function UpdateSection_Callback(hObject, eventdata, handles)
% hObject    handle to UpdateSection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%imshow(squeeze(Sections(24,:,:,:))); hold on; line(280*[1 1],[67 350],'color','k');
% display webcam image, if available

load(fullfile(fileparts(mfilename('fullpath')),'AllenSections_AON_APC.mat'));

% find the relevant section
[~,imageID] = min(abs(AP - handles.Coordinates.Data(1)));
axes(handles.MySection);
handles.current_section = image(squeeze(Sections(imageID,:,:,:)),'parent',handles.MySection);
set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');

% draw a vertical line along the ML coordinate on either side
ML_left = Scale.ML.zero + Scale.ML.left*handles.Coordinates.Data(2);
ML_right = Scale.ML.zero + Scale.ML.right*handles.Coordinates.Data(2);
handles.ML_L = line(ML_left*[1 1], [1 368], 'color', 'r');
handles.ML_R = line(ML_right*[1 1], [1 368], 'color', 'r');

handles.pixelcoordinates.Data(1,:) = [ML_left ML_right];

% mark the tetrode location based on depth
% define surface
if isempty(Surface{imageID})
    handles.Msg.String = 'Mark Surface';
    [~,yi] = getpts(handles.MySection);
    % ignore x, keep y
    Surface{imageID}(1,:) = [handles.Coordinates.Data(2), yi];
    save(fullfile(fileparts(mfilename('fullpath')),'AllenSections_AON_APC.mat'),'AP','Scale','Sections','Surface');
    handles.Msg.String = '';
else
    if ~isempty(find(Surface{imageID}(:,1)==handles.Coordinates.Data(2)))
        yi = Surface{imageID}(find(Surface{imageID}(:,1)==handles.Coordinates.Data(2)),2);
    else
        handles.Msg.String = 'Mark Surface';
        [~,yi] = getpts(handles.MySection);
        % ignore x, keep y
        Surface{imageID} = vertcat(Surface{imageID},[handles.Coordinates.Data(2), yi]);
        save(fullfile(fileparts(mfilename('fullpath')),'AllenSections_AON_APC.mat'),'AP','Scale','Sections','Surface');
        handles.Msg.String = '';
    end
end
% surface
handles.surface = line([1 553], [yi yi], 'color', 'b');
handles.DV = line([1 553], yi + Scale.DV*handles.Coordinates.Data(3)*[1 1], 'color', 'r');
handles.pixelcoordinates.Data(2,:) = [yi Scale.DV];
guidata(hObject, handles);


% --- Executes on button press in EditSurface.
function EditSurface_Callback(hObject, eventdata, handles)
% hObject    handle to EditSurface (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
load(fullfile(fileparts(mfilename('fullpath')),'AllenSections_AON_APC.mat'));
% find the relevant section
[~,imageID] = min(abs(AP - handles.Coordinates.Data(1)));

handles.Msg.String = 'Mark Surface';
[~,yi] = getpts(handles.MySection);
% ignore x, keep y
foo = find(Surface{imageID}(:,1)==handles.Coordinates.Data(2));
Surface{imageID}(foo,2) = yi;
save(fullfile(fileparts(mfilename('fullpath')),'AllenSections_AON_APC.mat'),'AP','Scale','Sections','Surface');
% update surface
handles.surface.YData = [yi yi];
handles.Msg.String = '';

guidata(hObject, handles);


% --- Executes on button press in ShowSurface.
function ShowSurface_Callback(hObject, eventdata, handles)
% hObject    handle to ShowSurface (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if get(hObject,'Value')
    handles.surface.LineStyle = '-';
else
    handles.surface.LineStyle = 'none';
end
% Hint: get(hObject,'Value') returns toggle state of ShowSurface
guidata(hObject, handles);


% --- Executes on button press in LoadDrive.
function LoadDrive_Callback(hObject, eventdata, handles)
% hObject    handle to LoadDrive (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.figure1.Position = [0.4882 0.3511 0.63 0.5889];

if ~isfield(handles,'MouseName') 
    [filename,path] = uigetfile('Select an Drive Depth Log');
    handles.MouseName = filename(1:strfind(filename,'_')-1);
    filename_local = fullfile(path,filename);
    filename_server = fullfile('\\grid-hs\albeanu_nlsas_norepl_data\pgupta\Behavior',filename);
else
    filename_local = handles.LocalFile;
    filename_server = handles.ServerFile;
end

clear depth;
if ~handles.useserver
    load(filename_local);
else
    load(filename_server);
end

if ~isfield(depth,'coord')
    depth.coord = input('Enter Drive coordinates (mm): [AP, ML, DV]\n');
    save(filename_local,'depth');
    if handles.useserver
        save(filename_server,'depth');
    end
end

% handles.axes16.Visible = 'on';
% handles.depthofinterest.YData = depth.params(2:3)/1000;
% handles.drivedepth.YData = mean(depth.log{end,3},'omitnan')/1000;
handles.Coordinates.Data = depth.coord;
handles.DriveDepth.Data = round(depth.log{end,3}');

UpdateSection_Callback(hObject, eventdata, handles);
%guidata(hObject, handles);

% calculate mean depth
mean_depth = mean(handles.DriveDepth.Data,'omitnan')/1000;
%handles.DV.YData = handles.surface.YData(1) + Scale.DV*mean_depth*[1 1];
% plot individual tetrodes/screws as well
%x = handles.ML_R.XData(1);
axes(handles.MySection); hold on
for i = 1:length(handles.DriveDepth.Data)
    if ~isnan(handles.DriveDepth.Data(i))
        x1 = handles.pixelcoordinates.Data(1,1)+[-2 2];
        x2 = handles.pixelcoordinates.Data(1,2)+[-2 2];
        y = (handles.pixelcoordinates.Data(2,1)+handles.pixelcoordinates.Data(2,2)*handles.DriveDepth.Data(i)/1000)*[1 1];
        line(x1,y,'color','k','LineWidth',1);
        line(x2,y,'color','k','LineWidth',1);
    end
end

guidata(hObject, handles);


% --- Executes on button press in SetDepth.
function SetDepth_Callback(hObject, eventdata, handles)
% hObject    handle to SetDepth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in UpdateDepth.
function UpdateDepth_Callback(hObject, eventdata, handles)
% hObject    handle to UpdateDepth (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
