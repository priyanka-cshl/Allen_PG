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

% Last Modified by GUIDE v2.5 15-Mar-2021 22:49:06

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

handles.Coordinates.Data(1) = varargin{1};
handles.Coordinates.Data(2) = varargin{2};
handles.Coordinates.Data(3) = varargin{3};

UpdateSection_Callback(hObject, eventdata, handles);

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
