function varargout = TetrodeMapper(varargin)
% TETRODEMAPPER MATLAB code for TetrodeMapper.fig
%      TETRODEMAPPER, by itself, creates a new TETRODEMAPPER or raises the existing
%      singleton*.
%
%      H = TETRODEMAPPER returns the handle to a new TETRODEMAPPER or the handle to
%      the existing singleton*.
%
%      TETRODEMAPPER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in TETRODEMAPPER.M with the given input arguments.
%
%      TETRODEMAPPER('Property','Value',...) creates a new TETRODEMAPPER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before TetrodeMapper_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to TetrodeMapper_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help TetrodeMapper

% Last Modified by GUIDE v2.5 26-Apr-2022 23:22:21

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @TetrodeMapper_OpeningFcn, ...
                   'gui_OutputFcn',  @TetrodeMapper_OutputFcn, ...
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


% --- Executes just before TetrodeMapper is made visible.
function TetrodeMapper_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to TetrodeMapper (see VARARGIN)

% Choose default command line output for TetrodeMapper
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

% UIWAIT makes TetrodeMapper wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = TetrodeMapper_OutputFcn(hObject, eventdata, handles) 
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

load(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String));

if ~handles.SectionType.Value
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
        save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
        handles.Msg.String = '';
    else
        if ~isempty(find(Surface{imageID}(:,1)==handles.Coordinates.Data(2)))
            yi = Surface{imageID}(find(Surface{imageID}(:,1)==handles.Coordinates.Data(2)),2);
        else
            handles.Msg.String = 'Mark Surface';
            [~,yi] = getpts(handles.MySection);
            % ignore x, keep y
            Surface{imageID} = vertcat(Surface{imageID},[handles.Coordinates.Data(2), yi]);
            save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
            handles.Msg.String = '';
        end
    end

else
    % find the relevant section
    [~,imageID] = min(abs(AP - handles.Coordinates.Data(2)));
    axes(handles.MySection);
    handles.current_section = image(squeeze(Sections(imageID,:,:,:)),'parent',handles.MySection);
    set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
    set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
    
    % draw a vertical line along the AP coordinate
    ML_left = Scale.ML.zero + Scale.ML.left*handles.Coordinates.Data(1);
    ML_right = NaN;
    handles.ML_L = line(ML_left*[1 1], [1 368], 'color', 'r');
    handles.ML_R = line(ML_right*[1 1], [1 368], 'color', 'r');
    
    handles.pixelcoordinates.Data(1,:) = [ML_left ML_right];
    
    % mark the tetrode location based on depth
    % define surface
    if isempty(Surface{imageID})
        handles.Msg.String = 'Mark Surface';
        [~,yi] = getpts(handles.MySection);
        % ignore x, keep y
        Surface{imageID}(1,:) = [handles.Coordinates.Data(1), yi];
        save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
        handles.Msg.String = '';
    else
        if ~isempty(find(Surface{imageID}(:,1)==handles.Coordinates.Data(1)))
            yi = Surface{imageID}(find(Surface{imageID}(:,1)==handles.Coordinates.Data(1)),2);
        else
            handles.Msg.String = 'Mark Surface';
            [~,yi] = getpts(handles.MySection);
            % ignore x, keep y
            Surface{imageID} = vertcat(Surface{imageID},[handles.Coordinates.Data(1), yi]);
            save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
            handles.Msg.String = '';
        end
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
load(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String));
% find the relevant section
[~,imageID] = min(abs(AP - handles.Coordinates.Data(1)));

handles.Msg.String = 'Mark Surface';
[~,yi] = getpts(handles.MySection);
% ignore x, keep y
foo = find(Surface{imageID}(:,1)==handles.Coordinates.Data(2));
Surface{imageID}(foo,2) = yi;
save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
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
        x1 = handles.pixelcoordinates.Data(1,1)+[-5 5];
        x2 = handles.pixelcoordinates.Data(1,2)+[-5 5];
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


% --- Executes on button press in SectionType.
function SectionType_Callback(hObject, eventdata, handles)
% hObject    handle to SectionType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of SectionType
if get(hObject,'Value')
    handles.Section_Names.String = 'AllenSections_Sagittal.mat';
else
    handles.Section_Names.String = 'AllenSections_AON_APC.mat';
end
UpdateSection_Callback(hObject, eventdata, handles);
guidata(hObject, handles);


function Section_Names_Callback(hObject, eventdata, handles)
% hObject    handle to Section_Names (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Section_Names as text
%        str2double(get(hObject,'String')) returns contents of Section_Names as a double


% --- Executes during object creation, after setting all properties.
function Section_Names_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Section_Names (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes when entered data in editable cell(s) in DriveDepth.
function DriveDepth_CellEditCallback(hObject, eventdata, handles)
% hObject    handle to DriveDepth (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.TABLE)
%	Indices: row and column indices of the cell(s) edited
%	PreviousData: previous data for the cell(s) edited
%	EditData: string(s) entered by the user
%	NewData: EditData or its converted form set on the Data property. Empty if Data was not changed
%	Error: error string when failed to convert EditData to appropriate value for Data
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in UpdateDrive.
function UpdateDriveOld_Callback(hObject, eventdata, handles)
% hObject    handle to UpdateSection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%imshow(squeeze(Sections(24,:,:,:))); hold on; line(280*[1 1],[67 350],'color','k');
% display webcam image, if available

if ~any(diff(cell2mat(handles.DriveCoords.Data(:,1))))
    % coronal
    handles.Section_Names.String = 'AllenSections_AON_APC.mat';
    handles.SectionType.Value = 0;
    handles.Coordinates.Data(1) = mode((cell2mat(handles.DriveCoords.Data(:,1))));
else
    % sagittal
    handles.Section_Names.String = 'AllenSections_Sagittal.mat';
    handles.SectionType.Value = 1;
    handles.Coordinates.Data(2) = mode((cell2mat(handles.DriveCoords.Data(:,2))));
end

load(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String));

if ~handles.SectionType.Value
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
        save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
        handles.Msg.String = '';
    else
        if ~isempty(find(Surface{imageID}(:,1)==handles.Coordinates.Data(2)))
            yi = Surface{imageID}(find(Surface{imageID}(:,1)==handles.Coordinates.Data(2)),2);
        else
            handles.Msg.String = 'Mark Surface';
            [~,yi] = getpts(handles.MySection);
            % ignore x, keep y
            Surface{imageID} = vertcat(Surface{imageID},[handles.Coordinates.Data(2), yi]);
            save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
            handles.Msg.String = '';
        end
    end

else
    % find the relevant section
    [~,imageID] = min(abs(AP - handles.Coordinates.Data(2)));
    axes(handles.MySection);
    handles.current_section = image(squeeze(Sections(imageID,:,:,:)),'parent',handles.MySection);
    set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
    set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
    
    % draw a vertical line along the relevant AP coordinate
    foo = find(~isnan(cell2mat(handles.DriveCoords.Data(:,3))));
    ML_left = Scale.ML.zero + Scale.ML.left*handles.DriveCoords.Data{foo,1};
    ML_right = NaN*ML_left;
    handles.ML_L = line(ML_left*[1 1], [1 368], 'color', 'r');
    handles.ML_R = line(ML_right*[1 1], [1 368], 'color', 'r');
    
    % define surface
    handles.Msg.String = 'Mark Surface';
    [~,yi] = getpts(handles.MySection);
    % ignore x, keep y
    handles.surface = line([1 553], [yi yi], 'color', 'b');
    
    % get depths
    depth_start = handles.DriveCoords.Data{foo,3};
    for tt = 1:size(handles.DriveCoords.Data,1)
        drive_coords(tt,2) = yi + Scale.DV*(depth_start+0.15*handles.DriveCoords.Data{tt,4});
    end
    drive_coords(:,1) = yi;
    ML = Scale.ML.zero + Scale.ML.left*cell2mat(handles.DriveCoords.Data(:,1));
    ClearLinesFromAxes();
    handles.ML_L = line((ML*[1 1])', drive_coords', 'color', 'r');
    handles.ML_R = line(ML_right*[1 1], [1 368], 'color', 'r');
    
    handles.pixelcoordinates.Data(1,:) = [ML_left ML_right];
    
    % mark the tetrode location based on depth
    % define surface
    if isempty(Surface{imageID})
        handles.Msg.String = 'Mark Surface';
        [~,yi] = getpts(handles.MySection);
        % ignore x, keep y
        Surface{imageID}(1,:) = [handles.Coordinates.Data(1), yi];
        save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
        handles.Msg.String = '';
    else
        if ~isempty(find(Surface{imageID}(:,1)==handles.Coordinates.Data(1)))
            yi = Surface{imageID}(find(Surface{imageID}(:,1)==handles.Coordinates.Data(1)),2);
        else
            handles.Msg.String = 'Mark Surface';
            [~,yi] = getpts(handles.MySection);
            % ignore x, keep y
            Surface{imageID} = vertcat(Surface{imageID},[handles.Coordinates.Data(1), yi]);
            save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
            handles.Msg.String = '';
        end
    end
end

% surface
handles.surface = line([1 553], [yi yi], 'color', 'b');
handles.DV = line([1 553], yi + Scale.DV*handles.Coordinates.Data(3)*[1 1], 'color', 'r');
handles.pixelcoordinates.Data(2,:) = [yi Scale.DV];
guidata(hObject, handles);


function ClearLinesFromAxes()
  axesHandlesToChildObjects = findobj(gca, 'Type', 'line');
  if ~isempty(axesHandlesToChildObjects)
    delete(axesHandlesToChildObjects);
  end  
  return; % from ClearLinesFromAxes

% --- Executes on button press in MakeDrive.
function MakeDrive_Callback(hObject, eventdata, handles)
% hObject    handle to MakeDrive (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[path, handles.MouseName] = fileparts(uigetdir('Select an Drive Log Location'));
filename = [handles.MouseName,'_DriveLog.mat'];
filename_local = fullfile(path,filename);
filename_server = fullfile('\\grid-hs\albeanu_nlsas_norepl_data\pgupta\Behavior',filename);
handles.LocalFile = filename_local;
handles.ServerFile = filename_server;

handles.DepthLog.Data = cell(1,6); % clear log entries
Drive.coords  = handles.DriveCoords.Data;
Drive.TurnLog = handles.DepthLog.Data;
Drive.Orientation = any(diff(cell2mat(handles.DriveCoords.Data(1,:))));

if Drive.Orientation
    handles.Section_Names.String = 'AllenSections_Sagittal.mat';
    handles.SectionType.Value = 1;
    handles.Coordinates.Data(2) = mode((cell2mat(handles.DriveCoords.Data(2,:))));
else
    handles.Section_Names.String = 'AllenSections_AON_APC.mat';
    handles.SectionType.Value = 0;
    handles.Coordinates.Data(1) = mode((cell2mat(handles.DriveCoords.Data(1,:))));
end

save(filename_local,'Drive');
if handles.useserver
    save(filename_server,'Drive');
end
guidata(hObject, handles);
UpdateDrive_Callback(hObject, eventdata, handles);

% --- Executes on button press in UpdateDrive.
function UpdateDrive_Callback(hObject, eventdata, handles)
% hObject    handle to UpdateSection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

load(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String));

if ~handles.SectionType.Value
    % find the relevant section
    [~,imageID] = min(abs(AP - handles.Coordinates.Data(1)));
    axes(handles.MySection);
    handles.current_section = image(squeeze(Sections(imageID,:,:,:)),'parent',handles.MySection);
    set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
    set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
    
    % define the relevant ML coordinate
    whichTT = find(~isnan(cell2mat(handles.DriveCoords.Data(3,:))));
    whichML(1) = Scale.ML.zero + Scale.ML.left*handles.DriveCoords.Data{2,whichTT};
    whichML(2) = Scale.ML.zero + Scale.ML.right*handles.DriveCoords.Data{2,whichTT};
    
    % find the surface
    yi = [];
    if isempty(Surface{imageID})
    elseif isempty(find(Surface{imageID}(:,1)==handles.Coordinates.Data(1)))
    else
        yi = Surface{imageID}(find(Surface{imageID}(:,1)==handles.Coordinates.Data(2)),2);
    end
    if isempty(yi) % ask user to mark surface
        % draw a vertical line along the ML coordinate on either side
        line(whichML(1)*[1 1], [1 368], 'color', 'r');
        line(whichML(2)*[1 1], [1 368], 'color', 'r');
        handles.Msg.String = 'Mark Surface';
        [~,yi] = getpts(handles.MySection);
        % ignore x, keep y
        Surface{imageID}(1,:) = [handles.Coordinates.Data(2), yi];
        save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
        handles.Msg.String = '';
    end
    
    % get TT depths
    depth_start = handles.DriveCoords.Data{3,whichTT};
    for tt = 1:size(handles.DriveCoords.Data,2)
        drive_coords(1,tt) = yi + Scale.DV*(depth_start+0.15*handles.DriveCoords.Data{4,tt});
    end
    drive_coords(2,:) = yi;
    ML = Scale.ML.zero + Scale.ML.left*cell2mat(handles.DriveCoords.Data(2,:));
    ClearLinesFromAxes();
    line((ML'*[1 1])', drive_coords, 'color', 'r'); 
    
else % Sagittal
    % find the relevant section
    [~,imageID] = min(abs(AP - handles.Coordinates.Data(2)));
    axes(handles.MySection);
    handles.current_section = image(squeeze(Sections(imageID,:,:,:)),'parent',handles.MySection);
    set(handles.MySection,'XTick',[],'XTickLabel',' ','XTickMode','manual','XTickLabelMode','manual');
    set(handles.MySection,'YTick',[],'YTickLabel',' ','YTickMode','manual','YTickLabelMode','manual');
    
    % define the relevant AP coordinate
    whichTT = find(~isnan(cell2mat(handles.DriveCoords.Data(3,:))));
    whichAP = Scale.ML.zero + Scale.ML.left*handles.DriveCoords.Data{1,whichTT};
    
    % find the surface
    yi = [];
    if isempty(Surface{imageID})
    elseif isempty(find(Surface{imageID}(:,1)==handles.Coordinates.Data(1)))
    else
        yi = Surface{imageID}(find(Surface{imageID}(:,1)==handles.Coordinates.Data(1)),2);
    end
    if isempty(yi) % ask user to mark surface
        % draw a vertical line along the relevant AP coordinate
        line(whichAP*[1 1], [1 368], 'color', 'r');
        handles.Msg.String = 'Mark Surface';
        [~,yi] = getpts(handles.MySection);
        % ignore x, keep y
        Surface{imageID}(1,:) = [handles.Coordinates.Data(1), yi];
        save(fullfile(fileparts(mfilename('fullpath')),handles.Section_Names.String),'AP','Scale','Sections','Surface');
        handles.Msg.String = '';
    end
    
    % get TT depths
    depth_start = handles.DriveCoords.Data{3,whichTT};
    for tt = 1:size(handles.DriveCoords.Data,2)
        drive_coords(1,tt) = yi + Scale.DV*(depth_start+0.15*handles.DriveCoords.Data{4,tt});
    end
    drive_coords(2,:) = yi;
    ML = Scale.ML.zero + Scale.ML.left*cell2mat(handles.DriveCoords.Data(1,:));
    ClearLinesFromAxes();
    line((ML'*[1 1])', drive_coords, 'color', 'r'); 
end

guidata(hObject, handles);
