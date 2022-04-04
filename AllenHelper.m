% Load the URL
% ImageID = [102162422, 102162418, 102162414, 102162410, 102162407, ...
%            102162402, 102162398, 102162394, 102162390, 102162386, ...
%            102162382, 102162378, 102162374, 102162370, 102162366, ...
%            102162362, 102162359, 102162354, 102162350, 102162346, ...
%            102162342, 102162338, 102162334, 102162330, 102162327, ...
%            102162322, 102162318, 102162314, 102162310, 102162306, ...
%            ];
       
ImageID = [102162578, 102162575, 102162571, 102162566, 102162562, ...
           102162558, 102162555, 102162551, 102162546, 102162544]; 

% [2.95 , 2.725, 2.525, 2.35, 2.15, 
%  1.95, 1.725, 1.525, 1.35, 1.1
for i = 1:numel(ImageID)
%     3.045 = 102162422       
%     2.945 = 102162418    
%     2.845 = 102162414
%     2.745 = 102162410
%     2.620 = 102162407
%     2.545 = 102162402
%     2.445 = 102162398
%     2.345 = 102162394
%     2.245 = 102162390
%     2.145 = 102162386
%     2.045 = 102162382
%     1.945 = 102162378
%     1.845 = 102162374
%     1.745 = 102162370
%     1.645 = 102162366
%     1.545 = 102162362
%     1.42  = 102162359
%     1.345 = 102162354
%     1.245 = 102162350
%     1.145 = 102162346
%     1.045 = 102162342
%     0.945 = 102162338
%     0.845 = 102162334
%     0.745 = 102162330
%     0.620 = 102162327
%     0.545 = 102162322
%     0.445 = 102162318
%     0.345 = 102162314
%     0.245 = 102162310
%     0.145 = 102162306

%     0.020 = 102162303
% -2.255 = 102162210
% -2.355 = 102162206
% -2.048 = 102162203

% MyURL = ['https://mouse.brain-map.org/experiment/siv?id=100142143&imageId=',...
%         num2str(ImageID(i)),...
%         '&imageType=atlas&initImage=atlas&showSubImage=y&contrast=0.5,0.5,0,255,4'];
MyURL = ['https://mouse.brain-map.org/experiment/siv?id=100142144&imageId=',...   
        num2str(ImageID(i)),...
        '&imageType=atlas&initImage=atlas&showSubImage=y&contrast=0.5,0.5,0,255,4'];
web(MyURL,'-noaddressbox','-notoolbar')
pause(10);

% Take screen capture
robot = java.awt.Robot();
pos = [434 182 553 400]; % [left top width height] 1036, 605
rect = java.awt.Rectangle(pos(1),pos(2),pos(3),pos(4));
cap = robot.createScreenCapture(rect);

% Convert to an RGB image
rgb = typecast(cap.getRGB(0,0,cap.getWidth,cap.getHeight,[],0,cap.getWidth),'uint8');
imgData = zeros(cap.getHeight,cap.getWidth,3,'uint8');
imgData(:,:,1) = reshape(rgb(3:4:end),cap.getWidth,[])';
imgData(:,:,2) = reshape(rgb(2:4:end),cap.getWidth,[])';
imgData(:,:,3) = reshape(rgb(1:4:end),cap.getWidth,[])';
%imshow(imgData)

Sections(i,:,:,:) = imgData;

% Show or save to file

%imwrite(imgData,'out.png')

end

%zero = 280;
% going left use 47, going right use 48

% zero = 226
% going right 38, going left
% imshow(squeeze(Sections(10,:,:,:))); hold on; line(280*[1 1],[67 350],'color','k')
