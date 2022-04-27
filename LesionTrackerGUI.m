function varargout = LesionTrackerGUI(varargin)
% LESIONTRACKERGUI MATLAB code for LesionTrackerGUI.fig
%      LESIONTRACKERGUI, by itself, creates a new LESIONTRACKERGUI or raises the existing
%      singleton*.
%
%      H = LESIONTRACKERGUI returns the handle to a new LESIONTRACKERGUI or the handle to
%      the existing singleton*.
%
%      LESIONTRACKERGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in LESIONTRACKERGUI.M with the given input arguments.
%
%      LESIONTRACKERGUI('Property','Value',...) creates a new LESIONTRACKERGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before LesionTrackerGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to LesionTrackerGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help LesionTrackerGUI

% Last Modified by GUIDE v2.5 29-Sep-2021 17:16:14

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @LesionTrackerGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @LesionTrackerGUI_OutputFcn, ...
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


% --- Executes just before LesionTrackerGUI is made visible.
function LesionTrackerGUI_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to LesionTrackerGUI (see VARARGIN)

% Choose default command line output for LesionTrackerGUI
handles.output = hObject;
handles.OverlayTransform.Enable = 'off';
axes(handles.MergeAxes);
handles.MergePosition.original = get(gca,'Position');
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes LesionTrackerGUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = LesionTrackerGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in LoadSlice.
function LoadSlice_Callback(hObject, eventdata, handles)
% hObject    handle to LoadSlice (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[handles.ImageNames,handles.ImagePath] = uigetfile('*.tif','Select Image to upload','MultiSelect','on');
handles.ImageId = 1;
if iscell(handles.ImageNames)
    handles.NumSlices = size(handles.ImageNames,2);
else
    handles.NumSlices = 1;
end
handles.TotalImages.String = ['/',num2str(handles.NumSlices)];
guidata(hObject, handles);
UpdateSlice_Callback(hObject, eventdata, handles);

function UpdateSlice_Callback(hObject, eventdata, handles)
if ~iscell(handles.ImageNames)
    MyFile = handles.ImageNames(handles.ImageId,:);
else
    MyFile = char(handles.ImageNames{1,handles.ImageId});
end
MySlice = imread(fullfile(handles.ImagePath,MyFile));

% display slice
axes(handles.BrainSlice);
handles.current_slice = imagesc(MySlice,'parent',handles.BrainSlice);
colormap gray;
set(handles.BrainSlice,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
set(handles.BrainSlice,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
handles.ImageName.String = MyFile;
handles.CurrentImage.String = num2str(handles.ImageId);

% --- Executes on button press in LoadRef.
function LoadRef_Callback(hObject, eventdata, handles)
% hObject    handle to LoadRef (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

function UpdateSection_Callback(hObject, eventdata, handles)
% hObject    handle to UpdateSection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%imshow(squeeze(Sections(24,:,:,:))); hold on; line(280*[1 1],[67 350],'color','k');
% display webcam image, if available

load(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String));

if ~handles.SectionType.Value
    % find the relevant section
    [~,imageID] = min(abs(AP - handles.Coordinates.Data(1)));
    axes(handles.MySection);
    if ~handles.FlipSlice.Value
        handles.current_section = image(squeeze(Sections(imageID,:,:,:)),'parent',handles.MySection);
    else
        handles.current_section = image(fliplr(squeeze(Sections(imageID,:,:,:))),'parent',handles.MySection);
    end
    set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
    set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
else
    % find the relevant section
    [~,imageID] = min(abs(AP - handles.Coordinates.Data(2)));
    axes(handles.MySection);
    handles.current_section = image(squeeze(Sections(imageID,:,:,:)),'parent',handles.MySection);
    set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
    set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
end

guidata(hObject, handles);


% --- Executes on button press in LoadScale.
function LoadScale_Callback(hObject, eventdata, handles)
% hObject    handle to LoadScale (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~exist(fullfile(handles.ImagePath,'ScaleBarValues.mat'))
    [ScaleBarImage] = uigetfile('*.tif',['Select scale bar for ',handles.ImageName.String]);
    MyScaleBar = imread(fullfile(handles.ImagePath,ScaleBarImage));
    set(handles.ScaleBarImage,'visible', 'on');
    
    axes(handles.ScaleBarImage);
    imagesc(MyScaleBar,'parent',handles.ScaleBarImage);
    colormap gray;
    set(handles.ScaleBarImage,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
    set(handles.ScaleBarImage,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
    
    [xi,yi] = getpts(handles.ScaleBarImage);
    
    prompt = {'Enter distance (um)','Valid Images'};
    title = 'Input';
    dims = [1 35];
    definput = {'500'};
    answer = inputdlg(prompt,title,dims,definput);
    set(handles.ScaleBarImage,'visible', 'off');
    
else
    load(fullfile(handles.ImagePath,'ScaleBarValues.mat'));
end
handles.ScalingFactor 
guidata(hObject, handles);
UpdateSlice_Callback(hObject, eventdata, handles);

% --- Executes on button press in NextSlice.
function NextSlice_Callback(hObject, eventdata, handles)
% hObject    handle to NextSlice (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ImageId = min(handles.ImageId + 1,handles.NumSlices);
guidata(hObject, handles);
UpdateSlice_Callback(hObject, eventdata, handles);

% --- Executes on button press in PreviousSlice.
function PreviousSlice_Callback(hObject, eventdata, handles)
% hObject    handle to PreviousSlice (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ImageId = max(1,handles.ImageId - 1);
guidata(hObject, handles);
UpdateSlice_Callback(hObject, eventdata, handles);


% --- Executes on button press in NextSection.
function NextSection_Callback(hObject, eventdata, handles)
% hObject    handle to NextSection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if ~handles.SectionType.Value % coronal - update AP
    handles.Coordinates.Data(1) = handles.Coordinates.Data(1) + handles.StepSize.Data(1)/1000;
else
    handles.Coordinates.Data(2) = handles.Coordinates.Data(2) + handles.StepSize.Data(1)/1000;
end
UpdateSection_Callback(hObject, eventdata, handles)

% --- Executes on button press in PreviousSection.
function PreviousSection_Callback(hObject, eventdata, handles)
% hObject    handle to PreviousSection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if ~handles.SectionType.Value % coronal - update AP
    handles.Coordinates.Data(1) = handles.Coordinates.Data(1) - handles.StepSize.Data(1)/1000;
else
    handles.Coordinates.Data(2) = handles.Coordinates.Data(2) - handles.StepSize.Data(1)/1000;
end
UpdateSection_Callback(hObject, eventdata, handles)


% --- Executes on button press in OverlayReference.
function OverlayReference_Callback(hObject, eventdata, handles)
% hObject    handle to OverlayReference (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
axes(handles.MergeAxes);
set(handles.MergeAxes,'visible','on');
MySlice = imread(fullfile(handles.ImagePath,handles.ImageName.String));
handles.current_overlay = imagesc(MySlice,'parent',handles.MergeAxes);
colormap gray;
set(gca,'color','none');
%ResetOverlay_Callback(hObject, eventdata, handles);
set(handles.MergeAxes,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
set(handles.MergeAxes,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
alpha(handles.OverlayTransparency.Data(1));
handles.OverlayTransform.Enable = 'on';
guidata(hObject, handles);

% Hint: get(hObject,'Value') returns toggle state of OverlayReference


% --- Executes when entered data in editable cell(s) in OverlayTransform.
function OverlayTransform_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to OverlayTransform (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
axes(handles.MergeAxes);
P = handles.MergePosition.original;
T = handles.OverlayTransform.Data(1:2,:);
P = [P(1)+T(2,1) P(2)+T(2,2) P(3)*T(1,1) P(4)*T(1,2)];
set(gca,'Position',P);
guidata(hObject, handles);


% --- Executes when entered data in editable cell(s) in OverlayAngle.
function OverlayAngle_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to OverlayAngle (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
axes(handles.MergeAxes);
MySlice = imread(fullfile(handles.ImagePath,handles.ImageName.String));
MyAngle = handles.OverlayAngle.Data(1);
foo = imrotate(MySlice,MyAngle,'crop');
handles.current_overlay = imagesc(foo,'parent',handles.MergeAxes);
set(gca,'color','none');
alpha(handles.OverlayTransparency.Data(1));

guidata(hObject, handles);
%imrotate(I,-1,'bilinear','crop');


% --- Executes when entered data in editable cell(s) in OverlayTransparency.
function OverlayTransparency_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to OverlayTransparency (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)
axes(handles.MergeAxes);
alpha(handles.OverlayTransparency.Data(1));
guidata(hObject, handles);


% --- Executes on button press in SaveOverlay.
function SaveOverlay_Callback(hObject, eventdata, handles)
% hObject    handle to SaveOverlay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
set(handles.MergeAxes,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
set(handles.MergeAxes,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
    
% Hint: get(hObject,'Value') returns toggle state of SaveOverlay
screencapture(gcf,'target',fullfile(handles.ImagePath,['Aligned ',handles.ImageName.String,'.png']));


% --- Executes on button press in ResetOverlay.
function ResetOverlay_Callback(hObject, eventdata, handles)
% hObject    handle to ResetOverlay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.OverlayTransform.Data = [1 1; 0 0];
handles.OverlayAngle.Data(1) = 0;
guidata(hObject, handles);
OverlayTransform_CellEditCallback(hObject, eventdata, handles);
OverlayAngle_CellEditCallback(hObject, eventdata, handles);
% Hint: get(hObject,'Value') returns toggle state of ResetOverlay


% --- Executes on button press in HideOverlay.
function HideOverlay_Callback(hObject, eventdata, handles)
% hObject    handle to HideOverlay (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of HideOverlay
axes(handles.MergeAxes);
alpha(~handles.HideOverlay.Value*handles.OverlayTransparency.Data(1));
