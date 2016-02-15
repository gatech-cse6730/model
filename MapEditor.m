classdef MapEditor < handle
    
    properties(Constant)
        CLICK_MODE_NONE = 0;
        CLICK_MODE_PAN = 1;
        CLICK_MODE_ADD_SIDEWALK_VERTEX = 2;
        CLICK_MODE_ADD_ROAD_VERTEX = 3;
        CLICK_MODE_ADD_ENTRANCE_VERTEX = 4;
        CLICK_MODE_ADD_EXIT_VERTEX = 5;
        CLICK_MODE_REM_VERTEX = 6;
        CLICK_MODE_SPECIAL_EDGE_V1 = 7;
        CLICK_MODE_SPECIAL_EDGE_V2 = 8;
        
        ZOOM_IN_FACTOR = 1.25;
        ZOOM_OUT_FACTOR = 0.75;
        
        NODE_TYPE_SIDEWALK = 1;
        NODE_TYPE_ROAD     = 2;
        NODE_TYPE_ENTRANCE = 3;
        NODE_TYPE_EXIT     = 4;
        
    end
    
    properties(Access = private)
        m_Handles;
        
        % file stuff
        m_ImagePath;
        m_ImageFileName;
        m_VertexPath;
        m_VertexFileName;
        m_SpecialEdgePath;
        m_SpecialEdgeFileName;
        
        % internal variables
        m_Image;
        m_ImageHandle;
        
        m_CellFlags;
        m_CellImage;
        m_CellImageHandle;
        m_CellImageAlpha;
        m_CellColorSwatches;
        
        m_MetersPerPixel;
        m_PixelsPerVertex;
        m_MouseMode;
        m_MouseModePrev;
        
        m_VertexList;
        m_NumVertices;
        m_EdgeList;
        m_NumEdges;
        m_SpecialEdgeList;
        m_SpecialEdgeListForExport;
        m_NumSpecialEdges;
        m_SpecialEdgeRecord;
        
        m_RectModeCoord;
    end
    
    methods(Access = public)

        function Obj = MapEditor()
            % MAPEDITOR MATLAB code for MapEditor.fig
            %      MAPEDITOR, by itself, creates a new MAPEDITOR or raises the existing
            %      singleton*.
            %
            %      H = MAPEDITOR returns the handle to a new MAPEDITOR or the handle to
            %      the existing singleton*.
            %
            %      MAPEDITOR('CALLBACK',hObject,eventData,handles,...) calls the local
            %      function named CALLBACK in MAPEDITOR.M with the given input arguments.
            %
            %      MAPEDITOR('Property','Value',...) creates a new MAPEDITOR or raises the
            %      existing singleton*.  Starting from the left, property value pairs are
            %      applied to the GUI before MapEditor_OpeningFcn gets called.  An
            %      unrecognized property name or invalid value makes property application
            %      stop.  All inputs are passed to MapEditor_OpeningFcn via varargin.
            %
            %      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
            %      instance to run (singleton)".
            %
            % See also: GUIDE, GUIDATA, GUIHANDLES

            % Edit the above text to modify the response to help MapEditor

            % Last Modified by GUIDE v2.5 12-Feb-2016 18:34:15

            % Begin initialization code - DO NOT EDIT
            gui_Singleton = 1;
            gui_State = struct('gui_Name',       mfilename, ...
                               'gui_Singleton',  gui_Singleton, ...
                               'gui_OpeningFcn', @MapEditor.MapEditor_OpeningFcn, ...
                               'gui_OutputFcn',  @MapEditor.MapEditor_OutputFcn, ...
                               'gui_LayoutFcn',  [] , ...
                               'gui_Callback',   []);

            hFormMain = gui_mainfcn(gui_State);
            
            MapEditor.GetSetInstance(Obj);
            Obj.m_Handles = guihandles(hFormMain);
            % End initialization code - DO NOT EDIT
            
            % default vals
            Obj.m_MetersPerPixel = 1;
            Obj.m_PixelsPerVertex = 3;
            Obj.m_ImagePath = [];
            Obj.m_ImageFileName = [];
            Obj.m_VertexPath = [];
            Obj.m_VertexFileName = [];
            Obj.m_SpecialEdgePath = [];
            Obj.m_SpecialEdgeFileName = [];
            Obj.m_VertexList = [];
            Obj.m_EdgeList = [];
            Obj.m_SpecialEdgeList.V1 = [];
            Obj.m_SpecialEdgeList.V2 = [];
            Obj.m_SpecialEdgeList.lengthMeters = [];
            Obj.m_CellImage = [];
            Obj.m_RectModeCoord = [];
            
            MapEditor.setupCellColorSwatches();
            
            % populate form stuff
            set(Obj.m_Handles.txtMetersPerPixel, 'String', Obj.m_MetersPerPixel);
            set(Obj.m_Handles.txtPixelsPerVertex, 'String', Obj.m_PixelsPerVertex);
            set(Obj.m_Handles.axisMain, 'ButtonDownFcn', @MapEditor.axisButtonDown);
            set(Obj.m_Handles.figureMain, 'WindowButtonUpFcn', {@MapEditor.dragFcnToggle, false});
            set(Obj.m_Handles.figureMain, 'KeyPressFcn', @MapEditor.handleKeyPress);
        end
    end
    
    methods(Access = public, Static)
        
        function Obj = GetSetInstance(Obj)
            persistent s_Instance;
            if(nargin == 1)
                s_Instance = Obj;
            else
                Obj = s_Instance;
            end
        end
        
        % --- Executes just before MapEditor is made visible.
        function MapEditor_OpeningFcn(hObject, eventdata, handles, varargin)
            % This function has no output args, see OutputFcn.
            % hObject    handle to figure
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            % varargin   command line arguments to MapEditor (see VARARGIN)

            % Choose default command line output for MapEditor
            handles.output = hObject;

            % Update handles structure
            guidata(hObject, handles);

            % UIWAIT makes MapEditor wait for user response (see UIRESUME)
            % uiwait(handles.figureMain);

        end

        % --- Outputs from this function are returned to the command line.
        function varargout = MapEditor_OutputFcn(hObject, eventdata, handles) 
            % varargout  cell array for returning output args (see VARARGOUT);
            % hObject    handle to figure
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)

            % Get default command line output from handles structure
            varargout{1} = handles.output;

        end
        
        function btnCreateVertexAndEdgeList_Callback()
            Obj = MapEditor.GetSetInstance();
            nCells = numel(Obj.m_CellFlags);
            nRows = size(Obj.m_CellFlags,1);
            nCols = size(Obj.m_CellFlags,2);
            
            % create vertex list
            Obj.m_VertexList.cellX = -1 * ones(nCells,1);
            Obj.m_VertexList.cellY = -1 * ones(nCells,1);
            Obj.m_VertexList.pixX = -1 * ones(nCells,1);
            Obj.m_VertexList.pixY = -1 * ones(nCells,1);
            Obj.m_VertexList.metersX = -1 * ones(nCells,1);
            Obj.m_VertexList.metersY = -1 * ones(nCells,1);
            Obj.m_VertexList.type    = -1 * ones(nCells,1);
            cellFlag1D = zeros(nCells, 1);
            
            % create edge list
            maxNumEdges = 4 * nRows * nCols - 3 * (nRows + nCols) + 2;
            Obj.m_EdgeList.V1 = -1 * ones(maxNumEdges, 1);
            Obj.m_EdgeList.V2 = -1 * ones(maxNumEdges, 1);
            Obj.m_EdgeList.lengthMeters = -1 * ones(maxNumEdges, 1);
            
            h = waitbar(0, 'Compiling vertices and edges...');
            
            mpp = Obj.m_MetersPerPixel;
            ppv = Obj.m_PixelsPerVertex;
            nEdges = 0;
            for r = 1:nRows
                
                waitbar(r / nRows, h);
                
                for c = 1:nCols
                    
                    if(Obj.m_CellFlags(r,c))
                        idx = (r-1) * nCols + c;
                        cellFlag1D(idx) = 1;
                        pixCoord = MapEditor.cellCoord2PlotCoord([r c]);
                        Obj.m_VertexList.cellX(idx) = c;
                        Obj.m_VertexList.cellY(idx) = r;
                        Obj.m_VertexList.pixX(idx) = pixCoord(2);
                        Obj.m_VertexList.pixY(idx) = pixCoord(1);
                        Obj.m_VertexList.metersX(idx) = mpp * pixCoord(2);
                        Obj.m_VertexList.metersY(idx) = mpp * pixCoord(1);
                        Obj.m_VertexList.type(idx) = Obj.m_CellFlags(r,c);
                        
                        % check subset of 8-connected neighborhood; the
                        % subset is elements in the neighborhood that were
                        % previously visited (top row, and left of current
                        % cell)
                        if(c > 1 && r > 1)
                            % up and left of current cell
                            if(Obj.m_CellFlags(r-1, c-1))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - nCols - 1;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp * sqrt(2);
                            end
                        end
                        if(r > 1)
                            % up of current cell
                            if(Obj.m_CellFlags(r-1, c))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - nCols;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp;
                            end
                        end
                        if(r > 1 && c < nCols)
                            % up and right of current cell
                            if(Obj.m_CellFlags(r-1, c+1))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - nCols + 1;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp * sqrt(2);
                            end
                        end
                        if(c > 1)
                            % left of current cell
                            if(Obj.m_CellFlags(r, c-1))
                                nEdges = nEdges + 1;
                                Obj.m_EdgeList.V1(nEdges) = idx;
                                Obj.m_EdgeList.V2(nEdges) = idx - 1;
                                Obj.m_EdgeList.lengthMeters(nEdges) = ppv * mpp;
                            end
                        end
                        
                    end %if current cell is a vertex
                    
                end %col loop
            end %row loop
            
            close(h);
            h = waitbar(0, 'Re-indexing vertices...');
            
            % need to re-index to make vertices contiguous
            mapVec = cumsum(cellFlag1D);
            cellFlags = cellFlag1D > 0;
            
            Obj.m_VertexList.cellX(mapVec(cellFlags))   = Obj.m_VertexList.cellX(cellFlags);
            Obj.m_VertexList.cellY(mapVec(cellFlags))   = Obj.m_VertexList.cellY(cellFlags);
            Obj.m_VertexList.pixX(mapVec(cellFlags))    = Obj.m_VertexList.pixX(cellFlags);
            Obj.m_VertexList.pixY(mapVec(cellFlags))    = Obj.m_VertexList.pixY(cellFlags);
            Obj.m_VertexList.metersX(mapVec(cellFlags)) = Obj.m_VertexList.metersX(cellFlags);
            Obj.m_VertexList.metersY(mapVec(cellFlags)) = Obj.m_VertexList.metersY(cellFlags);
            Obj.m_VertexList.type(mapVec(cellFlags))    = Obj.m_VertexList.type(cellFlags);
%             for i = 1:nCells
%                 
%                 waitbar(i / nCells, h);
%                 
%                 if(cellFlag1D(i))
%                     % move vertex data
%                     Obj.m_VertexList.cellX(mapVec(i))   = Obj.m_VertexList.cellX(i);
%                     Obj.m_VertexList.cellY(mapVec(i))   = Obj.m_VertexList.cellY(i);
%                     Obj.m_VertexList.pixX(mapVec(i))    = Obj.m_VertexList.pixX(i);
%                     Obj.m_VertexList.pixY(mapVec(i))    = Obj.m_VertexList.pixY(i);
%                     Obj.m_VertexList.metersX(mapVec(i)) = Obj.m_VertexList.metersX(i);
%                     Obj.m_VertexList.metersY(mapVec(i)) = Obj.m_VertexList.metersY(i);
%                     Obj.m_VertexList.type(mapVec(i))    = Obj.m_VertexList.type(i);
%                 end
%             end
            
            waitbar(1, h);
            close(h);
            h = waitbar(0, 'Re-indexing edges...');
            
            % update edges so indexes are correct
            Obj.m_EdgeList.V1 = mapVec(Obj.m_EdgeList.V1(Obj.m_EdgeList.V1>0));
            Obj.m_EdgeList.V2 = mapVec(Obj.m_EdgeList.V2(Obj.m_EdgeList.V2>0));
            
%             for i = 1:nEdges
%                 waitbar(i / nEdges, h);
%                 Obj.m_EdgeList.V1(i) = mapVec(Obj.m_EdgeList.V1(i));
%                 Obj.m_EdgeList.V2(i) = mapVec(Obj.m_EdgeList.V2(i));
%             end

            waitbar(1, h);
            close(h);
            h = waitbar(0, 'Completing...');
            
            % shorten vertex list
            Obj.m_NumVertices = sum(cellFlag1D);
            Obj.m_VertexList.cellX   = Obj.m_VertexList.cellX(1:Obj.m_NumVertices);
            Obj.m_VertexList.cellY   = Obj.m_VertexList.cellY(1:Obj.m_NumVertices);
            Obj.m_VertexList.pixX    = Obj.m_VertexList.pixX(1:Obj.m_NumVertices);
            Obj.m_VertexList.pixY    = Obj.m_VertexList.pixY(1:Obj.m_NumVertices);
            Obj.m_VertexList.metersX = Obj.m_VertexList.metersX(1:Obj.m_NumVertices);
            Obj.m_VertexList.metersY = Obj.m_VertexList.metersY(1:Obj.m_NumVertices);
            Obj.m_VertexList.type = Obj.m_VertexList.type(1:Obj.m_NumVertices);
            
            % shorten edge list
            Obj.m_NumEdges = nEdges;
            Obj.m_EdgeList.V1 = Obj.m_EdgeList.V1(1:Obj.m_NumEdges);
            Obj.m_EdgeList.V2 = Obj.m_EdgeList.V2(1:Obj.m_NumEdges);
            Obj.m_EdgeList.lengthMeters = Obj.m_EdgeList.lengthMeters(1:Obj.m_NumEdges);
            
            % process special edges (only need remap)
            nSpecialEdges = numel(Obj.m_SpecialEdgeList.V1);
            Obj.m_SpecialEdgeListForExport = Obj.m_SpecialEdgeList; % make copy
            for i = 1:nSpecialEdges
                v1 = mapVec(Obj.m_SpecialEdgeList.V1(i));
                v2 = mapVec(Obj.m_SpecialEdgeList.V2(i));
                Obj.m_SpecialEdgeListForExport.V1(i) = v1;
                Obj.m_SpecialEdgeListForExport.V2(i) = v2;
                
                % see if special edge interferes with any present edges
                v1Flags = Obj.m_EdgeList.V1 == v1 | Obj.m_EdgeList.V2 == v1;
                v2Flags = Obj.m_EdgeList.V1 == v2 | Obj.m_EdgeList.V2 == v2;
                totFlags = v1Flags & v2Flags;
                if(sum(totFlags) > 0)
                    % found conflict; remove original edge in lieu of
                    % special edge
                    Obj.m_EdgeList.V1 = Obj.m_EdgeList.V1(~totFlags);
                    Obj.m_EdgeList.V2 = Obj.m_EdgeList.V2(~totFlags);
                    Obj.m_NumEdges = Obj.m_NumEdges - sum(totFlags);
                end
            end
            
            waitbar(1, h);
            close(h);
            h = waitbar(0, 'Plotting...');
            
            % plot vertices if configured to
            if(Obj.m_Handles.chkShowVerticesWhenDone.Value)
                Obj.m_Handles.axisMain;
                sidewalkX = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_SIDEWALK);
                sidewalkY = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_SIDEWALK);
                roadX     = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_ROAD);
                roadY     = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_ROAD);
                entranceX = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_ENTRANCE);
                entranceY = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_ENTRANCE);
                exitX     = Obj.m_VertexList.pixX(Obj.m_VertexList.type == Obj.NODE_TYPE_EXIT);
                exitY     = Obj.m_VertexList.pixY(Obj.m_VertexList.type == Obj.NODE_TYPE_EXIT);
                
                plot(Obj.m_Handles.axisMain, sidewalkX, sidewalkY, '.b', 'markersize', 2);
                plot(Obj.m_Handles.axisMain, roadX, roadY, '.', 'markersize', 2, 'color', [0.5 0.5 0]); % dark yellow
                plot(Obj.m_Handles.axisMain, entranceX, entranceY, '.', 'markersize', 2, 'color', [0.5 0.5 0]);
                plot(Obj.m_Handles.axisMain, exitX, exitY, '.', 'markersize', 2, 'color', [0.5 0 0]);
            end
            
            waitbar(0.5, h);
            
            % plot edges if configured to
            if(Obj.m_Handles.chkShowEdgesWhenDone.Value)
                Obj.m_Handles.axisMain;
                for i = 1:Obj.m_NumEdges
                    waitbar(0.5 + 0.5 * (i / Obj.m_NumEdges), h);
                    v1Idx = Obj.m_EdgeList.V1(i);
                    v2Idx = Obj.m_EdgeList.V2(i);
                    plot(Obj.m_Handles.axisMain, ...
                        Obj.m_VertexList.pixX([v1Idx, v2Idx]), ...
                        Obj.m_VertexList.pixY([v1Idx, v2Idx]), ...
                        '.-b');
                end
                plot(Obj.m_Handles.axisMain, Obj.m_VertexList.pixX, Obj.m_VertexList.pixY, '.b', 'markersize', 2);
            end
            
            close(h);
            
            fprintf('Completed making vertices and edges.\n');
        end %function
        
        function btnExportGraph_Callback()
            Obj = MapEditor.GetSetInstance();
            
            h = waitbar(0, 'Exporting veritces...');
            
            % write vertices
            fid = fopen(fullfile(Obj.m_ImagePath, [Obj.m_ImageFileName, '.vertex']), 'w');
            fprintf(fid, '%f\n', Obj.m_MetersPerPixel);
            fprintf(fid, '%f\n', Obj.m_PixelsPerVertex);
            fprintf(fid, '%i\n', Obj.m_NumVertices);
            for i = 1:Obj.m_NumVertices
                fprintf(fid, '%i,%i,%f,%f,%f,%f,%i\n', ...
                    Obj.m_VertexList.cellX(i), ...
                    Obj.m_VertexList.cellY(i), ...
                    Obj.m_VertexList.pixX(i), ...
                    Obj.m_VertexList.pixY(i), ...
                    Obj.m_VertexList.metersX(i), ...
                    Obj.m_VertexList.metersY(i), ...
                    Obj.m_VertexList.type(i));
                
                if(rem(i, 100) == 0)
                    waitbar(i / Obj.m_NumVertices, h);
                end
            end
            fclose(fid);
            
            close(h);
            h = waitbar(0, 'Exporting edges...');
            
            % write edges
            fid = fopen(fullfile(Obj.m_ImagePath, [Obj.m_ImageFileName, '.edge']), 'w');
            fprintf(fid, '%i\n', Obj.m_NumEdges);
            for i = 1:Obj.m_NumEdges
                fprintf(fid, '%i,%i,%f\n', ...
                    Obj.m_EdgeList.V1(i)-1, ... %subtract 1 to make zero-based
                    Obj.m_EdgeList.V2(i)-1, ... %subtract 1 to make zero-based
                    Obj.m_EdgeList.lengthMeters(i));
                
                if(rem(i, 100) == 0)
                    waitbar(i / Obj.m_NumEdges, h);
                end
            end
            fclose(fid);
            
            close(h);
            h = waitbar(0, 'Exporting special edges...');
            
            % write special edges
            fid = fopen(fullfile(Obj.m_ImagePath, [Obj.m_ImageFileName, '.specialedge']), 'w');
            fprintf(fid, '%i\n', numel(Obj.m_SpecialEdgeList.V1));
            for i = 1:numel(Obj.m_SpecialEdgeList.V1)
                fprintf(fid, '%i,%i,%f\n', ...
                    Obj.m_SpecialEdgeListForExport.V1(i)-1, ... %subtract 1 to make zero-based
                    Obj.m_SpecialEdgeListForExport.V2(i)-1, ... %subtract 1 to make zero-based
                    Obj.m_SpecialEdgeListForExport.lengthMeters(i));
                waitbar(i / numel(Obj.m_SpecialEdgeList.V1), h);
            end
            fclose(fid);
            
            close(h);
            
            fprintf('Export complete.\n');
            
        end
        
        function btnAddSpecialEdge_Callback()
            Obj = MapEditor.GetSetInstance();
            
            % save current mouse mode for reinstating later
            Obj.m_MouseModePrev = Obj.m_MouseMode;
            
            % style stuff
            Obj.m_MouseMode = Obj.CLICK_MODE_SPECIAL_EDGE_V1;
            Obj.applyMouseMode();
            
            % tell user what to do and color boxes
            Obj.m_Handles.txtSpecialEdgePt2.BackgroundColor = [1.0 1.0 1.0];
            Obj.m_Handles.txtSpecialEdgeWeight.BackgroundColor = [1.0 1.0 1.0];
            Obj.m_Handles.txtSpecialEdgePt1.String = 'Click on Map!';
            Obj.m_Handles.txtSpecialEdgePt1.BackgroundColor = [1.0 0.5 0.5];
        end
        
        function btnSpecialEdgeSubmit_Callback()
            Obj = MapEditor.GetSetInstance();
            
            if(Obj.m_MouseMode == Obj.CLICK_MODE_SPECIAL_EDGE_V2)
                % add special edge
                Obj.m_SpecialEdgeList.V1(end+1) = Obj.m_SpecialEdgeRecord.V1;
                Obj.m_SpecialEdgeList.V2(end+1) = Obj.m_SpecialEdgeRecord.V2;
                
                myLength = str2double(Obj.m_Handles.txtSpecialEdgeWeight.String);
                Obj.m_SpecialEdgeList.lengthMeters(end+1) = myLength;
                
                % plot special edge
                nCellCols = size(Obj.m_CellFlags, 2);
                xy1 = [ ...
                    rem(Obj.m_SpecialEdgeRecord.V1, nCellCols), ...
                    floor(Obj.m_SpecialEdgeRecord.V1 / nCellCols)+1];
                xy2 = [ ...
                    rem(Obj.m_SpecialEdgeRecord.V2, nCellCols), ...
                    floor(Obj.m_SpecialEdgeRecord.V2 / nCellCols)+1];
                Obj.m_Handles.axisMain;
                pixCoord1 = MapEditor.cellCoord2PlotCoord(xy1);
                pixCoord2 = MapEditor.cellCoord2PlotCoord(xy2);
                plot(Obj.m_Handles.axisMain, ...
                    [pixCoord1(1) pixCoord2(1)], ...
                    [pixCoord1(2) pixCoord2(2)], ...
                    '.-r');
                
                % update form elements
                Obj.m_Handles.txtSpecialEdgePt1.BackgroundColor = [1.0 1.0 1.0];
                Obj.m_Handles.txtSpecialEdgePt1.String = '';
                Obj.m_Handles.txtSpecialEdgePt2.BackgroundColor = [1.0 1.0 1.0];
                Obj.m_Handles.txtSpecialEdgePt2.String = '';
                Obj.m_Handles.txtSpecialEdgeWeight.BackgroundColor = [1.0 1.0 1.0];
                Obj.m_Handles.txtSpecialEdgeWeight.String = '';
                Obj.m_MouseMode = Obj.m_MouseModePrev;
                MapEditor.applyMouseMode();
            end
        end
        
        function btnZoomIn_Callback()
            Obj = MapEditor.GetSetInstance();
            zoom(Obj.m_Handles.axisMain, Obj.ZOOM_IN_FACTOR);
        end
        
        function btnZoomOut_Callback()
            Obj = MapEditor.GetSetInstance();
            zoom(Obj.m_Handles.axisMain, Obj.ZOOM_OUT_FACTOR);
        end
        
        function chkUseRectangleSelect_Callback()
            Obj = MapEditor.GetSetInstance();
            
            if(Obj.m_Handles.chkUseRectangleSelect.Value == 0)
                % unchecked, reset stuff
                Obj.m_RectModeCoord = [];
            
                % modify text
                oldStr = Obj.m_Handles.chkUseRectangleSelect.String;
                oldStrLen = numel(oldStr);
                newStr = [oldStr(1:oldStrLen-2) '-)'];
                Obj.m_Handles.chkUseRectangleSelect.String = newStr;
            end
        end
        
        function chkShowGrid_Callback()
            MapEditor.toggleGrid();
        end
        
        function menuFile_OpenPicture_Callback()
            Obj = MapEditor.GetSetInstance();
            
            % ask for image file
            [Obj.m_ImageFileName, Obj.m_ImagePath] = uigetfile({'*.png';'*.jpg';'*.gif'}, 'Select Image');
            
            % make sure user selected something
            if(numel(Obj.m_ImageFileName) > 1 && numel(Obj.m_ImagePath) > 1)
                % read image
                Obj.m_Image = imread(fullfile(Obj.m_ImagePath, Obj.m_ImageFileName));

                % display image
                MapEditor.setupImage();

                % establish grid data
                MapEditor.setupGrid();
            end
        end
        
        function menuFile_OpenVertexList_Callback()
            Obj = MapEditor.GetSetInstance();
            
            % ask for image file
            [Obj.m_VertexFileName, Obj.m_VertexPath] = uigetfile({'*.vertex'}, 'Select Vertex File');
            
            % make sure user selected something and image exists
            if(numel(Obj.m_VertexFileName) > 1 && numel(Obj.m_VertexPath) > 1 && ...
               numel(Obj.m_ImageFileName) > 1 && numel(Obj.m_ImagePath) > 1)
                % read vertex file
                fid = fopen(fullfile(Obj.m_VertexPath, Obj.m_VertexFileName), 'r');
                
                % get meters per pixel and pixels per vertex
                mpp = textscan(fid, '%f', 1);
                ppv = textscan(fid, '%f', 1);
                
                Obj.m_MetersPerPixel = mpp{1};
                set(Obj.m_Handles.txtMetersPerPixel, 'String', num2str(mpp{1}));
                Obj.m_PixelsPerVertex = ppv{1};
                set(Obj.m_Handles.txtPixelsPerVertex, 'String', num2str(ppv{1}));
                
                MapEditor.setupCellColorSwatches();
                MapEditor.setupGrid();
                
                nVertices = textscan(fid, '%f', 1);
                Obj.m_VertexList.cellX = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.cellY = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.pixX = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.pixY = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.metersX = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.metersY = -1 * ones(nVertices{1},1);
                Obj.m_VertexList.type    = -1 * ones(nVertices{1},1);
                
                h = waitbar(0, 'Importing veritces...');
                
                V = textscan(fid, '%f %f %f %f %f %f %f', 'Delimiter', ',');
                for i = 1:nVertices{1}
                    
                    if(rem(i, 100) == 0)
                        waitbar(i / nVertices{1}, h);
                    end
                    
                    Obj.m_VertexList.cellX(i) = V{1}(i);
                    Obj.m_VertexList.cellY(i) = V{2}(i);
                    Obj.m_VertexList.pixX(i) = V{3}(i);
                    Obj.m_VertexList.pixY(i) = V{4}(i);
                    Obj.m_VertexList.metersX(i) = V{5}(i);
                    Obj.m_VertexList.metersY(i) = V{6}(i);
                    Obj.m_VertexList.type(i)    = V{7}(i);
                    
                    cc = [Obj.m_VertexList.cellX(i), Obj.m_VertexList.cellY(i)];
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.m_VertexList.type(i);
                    
                    % set cell image values but do not display
                    MapEditor.setCellImageValue(cc, Obj.m_CellFlags(cc(2),cc(1)), false)
                end
                
                % display cell image now
                set(Obj.m_CellImageHandle, 'AlphaData', Obj.m_CellImageAlpha);
                set(Obj.m_CellImageHandle, 'CData', Obj.m_CellImage);
                
                close(h);

                fclose(fid);
            end
        end
        
        function menuFile_OpenSpecialEdgeList_Callback()
            Obj = MapEditor.GetSetInstance();
            
            % ask for image file
            [Obj.m_SpecialEdgeFileName, Obj.m_SpecialEdgePath] = uigetfile({'*.specialedge'}, 'Select Special Edge File');
            
            % make sure user selected something and image exists
            if(numel(Obj.m_SpecialEdgeFileName) > 1 && numel(Obj.m_SpecialEdgePath) > 1 && ...
               numel(Obj.m_ImageFileName) > 1 && numel(Obj.m_ImagePath) > 1)
                % read special edge file
                fid = fopen(fullfile(Obj.m_SpecialEdgePath, Obj.m_SpecialEdgeFileName), 'r');
                
                nSpecialEdges = textscan(fid, '%f', 1);
                Obj.m_SpecialEdgeList.V1 = -1 * ones(nSpecialEdges{1},1);
                Obj.m_SpecialEdgeList.V2 = -1 * ones(nSpecialEdges{1},1);
                Obj.m_SpecialEdgeList.lengthMeters = -1 * ones(nSpecialEdges{1},1);
                
                V = textscan(fid, '%f %f %f', 'Delimiter', ',');
                for i = 1:nSpecialEdges{1}
                    v1 = V{1}(i) + 1;
                    v2 = V{2}(i) + 1;
                    Obj.m_SpecialEdgeList.lengthMeters(i) = V{3}(i);
                    
                    pixCoord1 = [Obj.m_VertexList.pixX(v1), Obj.m_VertexList.pixY(v1)];
                    pixCoord2 = [Obj.m_VertexList.pixX(v2), Obj.m_VertexList.pixY(v2)];
                    plot(Obj.m_Handles.axisMain, ...
                        [pixCoord1(1) pixCoord2(1)], ...
                        [pixCoord1(2) pixCoord2(2)], ...
                        '.-r');
                    
                    nCols = size(Obj.m_CellFlags, 2);
                    cellCoord1 = [Obj.m_VertexList.cellX(v1), Obj.m_VertexList.cellY(v1)];
                    idx1 = (cellCoord1(2)-1) * nCols + cellCoord1(1);
                    cellCoord2 = [Obj.m_VertexList.cellX(v2), Obj.m_VertexList.cellY(v2)];
                    idx2 = (cellCoord2(2)-1) * nCols + cellCoord2(1);
                    Obj.m_SpecialEdgeList.V1(i) = idx1;
                    Obj.m_SpecialEdgeList.V2(i) = idx2;
                end

                fclose(fid);
            end
        end
        
        function radMouseNone_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_NONE;
            MapEditor.applyMouseMode();
        end
        
        function radMousePan_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_PAN;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddSidewalkVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddRoadVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_ROAD_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddEntranceVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseAddExitVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_ADD_EXIT_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function radMouseRemVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MouseMode = Obj.CLICK_MODE_REM_VERTEX;
            MapEditor.applyMouseMode();
        end
        
        function txtMetersPerPixel_Callback()
            Obj = MapEditor.GetSetInstance();
            Obj.m_MetersPerPixel = str2double(get(Obj.m_Handles.txtMetersPerPixel, 'String'));
        end
        
        function txtPixelsPerVertex_Callback()
            Obj = MapEditor.GetSetInstance();
            newVal = str2double(get(Obj.m_Handles.txtPixelsPerVertex, 'String'));
            if(Obj.m_PixelsPerVertex ~= newVal)
                Obj.m_PixelsPerVertex = newVal;
                MapEditor.setupImage();
                MapEditor.setupCellColorSwatches();
                MapEditor.setupGrid();
                MapEditor.toggleGrid();
            end
        end
        
        
        
        
        
        function setupImage()
            Obj = MapEditor.GetSetInstance();
            Obj.m_Handles.axisMain;
            cla;
            Obj.m_ImageHandle = imshow(Obj.m_Image);
            hold on;
            set(Obj.m_ImageHandle, 'ButtonDownFcn', @MapEditor.axisButtonDown);
            set(Obj.m_ImageHandle, 'AlphaData', 0.40);
            
            % formatting
            axis image;
            axis equal;
            axis on;
        end
        
        % Sets up panning by clicking and dragging via the hand cursor.
        function [flag] = myPanCallbackFunction(obj, eventdata)
            % If the tag of the object is 'DoNotIgnore', then return true.
            % Indicate what the target is
%             disp(['In myPanCallbackFunction, you clicked on a ' get(obj,'Type') 'object']);
            objTag = get(obj, 'Tag');
            if strcmpi(objTag, 'DoNotIgnore')
                flag = true;
            else
                flag = false;
            end
        end
        
        function setupGrid()
            Obj = MapEditor.GetSetInstance();
            
            % set up grid lines for display on image
            Obj.m_Handles.axisMain.XTick = 0.5:Obj.m_PixelsPerVertex:size(Obj.m_Image,2);
            Obj.m_Handles.axisMain.YTick = 0.5:Obj.m_PixelsPerVertex:size(Obj.m_Image,1);
            set(Obj.m_Handles.axisMain, 'GridColor', 'magenta');
            set(Obj.m_Handles.axisMain, 'GridAlpha', 0.4);
            
            % set up cell flags
            sz = [size(Obj.m_Image, 1) size(Obj.m_Image,2)];
            szCell = floor(sz / Obj.m_PixelsPerVertex);
            Obj.m_CellFlags = zeros(szCell);
            
            % set up cell image for display (cyan)
            Obj.m_CellImageAlpha = zeros(size(Obj.m_Image,1), size(Obj.m_Image,2));
            Obj.m_CellImage = zeros([size(Obj.m_Image, 1), size(Obj.m_Image, 2), 3]);
            
            MapEditor.plotGrid();
            
            Obj.m_RectModeCoord = [];
        end
        
        function plotGrid()
            Obj = MapEditor.GetSetInstance();
            if(~isempty(Obj.m_CellImage))
                Obj.m_Handles.axisMain;
                Obj.m_CellImageHandle = imshow(Obj.m_CellImage);
                set(Obj.m_CellImageHandle, 'AlphaData', Obj.m_CellImageAlpha);
                set(Obj.m_CellImageHandle, 'ButtonDownFcn', @MapEditor.axisButtonDown);
                axis image;
                axis equal;
                axis on;
            end
        end
        
        function toggleGrid()
            Obj = MapEditor.GetSetInstance();
            if(Obj.m_Handles.chkShowGrid.Value ~= 0)
                grid(Obj.m_Handles.axisMain, 'on');
%                 set(Obj.m_Handles.axisMain, 'xticklabel', {[]});
%                 set(Obj.m_Handles.axisMain, 'yticklabel', {[]});
            else
                grid(Obj.m_Handles.axisMain, 'off');
            end
        end
        
        function applyMouseMode()
            Obj = MapEditor.GetSetInstance();
            
            % turn off panning if it's not set for it
            h = pan(Obj.m_Handles.figureMain);
            if(Obj.m_MouseMode == Obj.CLICK_MODE_PAN);
                set(h, 'Enable', 'on');
                addlistener(Obj.m_Handles.figureMain, 'WindowKeyPress', @MapEditor.handleKeyPress); %need to listen for keystrokes
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ROAD_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_EXIT_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_REM_VERTEX)
                set(h, 'Enable', 'off');
                set(Obj.m_Handles.figureMain, 'Pointer', 'crosshair');
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_SPECIAL_EDGE_V1 || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_SPECIAL_EDGE_V2)
                set(h, 'Enable', 'off');
                set(Obj.m_Handles.figureMain, 'Pointer', 'crosshair');
            else
                set(Obj.m_Handles.figureMain, 'Pointer', 'arrow');
            end
        end
        
        function axisButtonDown(~, eventData)
            Obj = MapEditor.GetSetInstance();
            MapEditor.dragFcnToggle(0, 0, true);
%             fprintf('Button down! (%f, %f)\n', eventData.IntersectionPoint(1), eventData.IntersectionPoint(2));
%             fprintf('%s: ', eventData.EventName);
            pc = [0 0];
            cc = [0 0];

            if(strcmpi(eventData.EventName, 'WindowMouseMotion'))
                [pc, cc] = MapEditor.calcCellCoord(get(Obj.m_Handles.axisMain, 'CurrentPoint'));
            else
                [pc, cc] = MapEditor.calcCellCoord(eventData.IntersectionPoint);
            end
            
            % do add or removal, depending on click mode
            if(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_SIDEWALK)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_SIDEWALK;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_SIDEWALK, true);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ROAD_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_ROAD)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_ROAD;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_ROAD, true);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_ENTRANCE)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_ENTRANCE;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_ENTRANCE, true);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_EXIT_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)) ~= Obj.NODE_TYPE_EXIT)
                    Obj.m_CellFlags(cc(2), cc(1)) = Obj.NODE_TYPE_EXIT;
                    MapEditor.setCellImageValue(cc, Obj.NODE_TYPE_EXIT, true);
%                     fprintf('Toggled cell to true\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_REM_VERTEX)
                if(Obj.m_CellFlags(cc(2), cc(1)))
                    Obj.m_CellFlags(cc(2), cc(1)) = false;
                    MapEditor.setCellImageValue(cc, 0, true);
%                     fprintf('Toggled cell to false\n');
                end
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_SPECIAL_EDGE_V1)
                nCols = size(Obj.m_CellFlags, 2);
                idx = (cc(2)-1) * nCols + cc(1);
                Obj.m_SpecialEdgeRecord.V1 = idx;
                Obj.m_Handles.txtSpecialEdgePt1.String = 'Got it!';
                Obj.m_Handles.txtSpecialEdgePt1.BackgroundColor = [1.0 1.0 1.0];
                Obj.m_Handles.txtSpecialEdgePt2.String = 'Click on Map!';
                Obj.m_Handles.txtSpecialEdgePt2.BackgroundColor = [1.0 0.5 0.5];
                Obj.m_MouseMode = Obj.CLICK_MODE_SPECIAL_EDGE_V2;
            elseif(Obj.m_MouseMode == Obj.CLICK_MODE_SPECIAL_EDGE_V2)
                nCols = size(Obj.m_CellFlags, 2);
                idx = (cc(2)-1) * nCols + cc(1);
                Obj.m_SpecialEdgeRecord.V2 = idx;
                Obj.m_Handles.txtSpecialEdgePt2.String = 'Got it!';
                Obj.m_Handles.txtSpecialEdgePt2.BackgroundColor = [1.0 1.0 1.0];
                Obj.m_Handles.txtSpecialEdgeWeight.String = 0;
                Obj.m_Handles.txtSpecialEdgeWeight.BackgroundColor = [1.0 0.5 0.5];
            end
            
            % rectangle mode checks
            if(Obj.m_Handles.chkUseRectangleSelect.Value > 0 && ...
               ~isempty(Obj.m_MouseMode))
                if(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ROAD_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_ADD_EXIT_VERTEX || ...
                   Obj.m_MouseMode == Obj.CLICK_MODE_REM_VERTEX)
                    
                    % see if user already clicked once
                    if(isempty(Obj.m_RectModeCoord))
                        % didn't click yet, store for later
                        Obj.m_RectModeCoord = cc;
                        
                        % modify text to indicate we got it
                        oldStr = Obj.m_Handles.chkUseRectangleSelect.String;
                        oldStrLen = numel(oldStr);
                        newStr = [oldStr(1:oldStrLen-2) '1)'];
                        Obj.m_Handles.chkUseRectangleSelect.String = newStr;
                    else
                        % get node type to do fill with
                        nodeType = 0;
                        if(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_SIDEWALK_VERTEX)
                            nodeType = Obj.NODE_TYPE_SIDEWALK;
                        elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ROAD_VERTEX)
                            nodeType = Obj.NODE_TYPE_ROAD;    
                        elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_ENTRANCE_VERTEX)
                            nodeType = Obj.NODE_TYPE_ENTRANCE;
                        elseif(Obj.m_MouseMode == Obj.CLICK_MODE_ADD_EXIT_VERTEX)
                            nodeType = Obj.NODE_TYPE_EXIT;
                        elseif(Obj.m_MouseMode == Obj.CLICK_MODE_REM_VERTEX)
                            nodeType = 0;
                        end
                        
                        % ready to do rectangular fill
                        MapEditor.setCellImageValue([cc; Obj.m_RectModeCoord], nodeType, true);
                        xCellMin = min(cc(1), Obj.m_RectModeCoord(1));
                        xCellMax = max(cc(1), Obj.m_RectModeCoord(1));
                        yCellMin = min(cc(2), Obj.m_RectModeCoord(2));
                        yCellMax = max(cc(2), Obj.m_RectModeCoord(2));
                        Obj.m_CellFlags(yCellMin:yCellMax, xCellMin:xCellMax) = nodeType;
%                         for r = yCellMin:yCellMax
%                             for c = xCellMin:xCellMax
%                                 Obj.m_CellFlags(r, c) = nodeType;
%                             end
%                         end
                        
                        % clear stored point
                        Obj.m_RectModeCoord = [];
                        
                        % modify text
                        oldStr = Obj.m_Handles.chkUseRectangleSelect.String;
                        oldStrLen = numel(oldStr);
                        newStr = [oldStr(1:oldStrLen-2) '-)'];
                        Obj.m_Handles.chkUseRectangleSelect.String = newStr;
                    end
                end
            end
            
        end
        
        function setCellImageValue(cellCoord, vertexType, setImages)
            Obj = MapEditor.GetSetInstance();
            
            % vertex type indicates color and alpha
            alphaVal = 0.5;
            if(vertexType == 0)
                alphaVal = 0.0;
            end
            
            ppv = Obj.m_PixelsPerVertex;
            if(size(cellCoord,1) > 1)
                % case where two cells are passed (this forms a rectangle
                % of cells to be filled)
                cellXmin = min(cellCoord(:,1));
                cellXmax = max(cellCoord(:,1));
                cellYmin = min(cellCoord(:,2));
                cellYmax = max(cellCoord(:,2));
                cellRgnWidth = cellXmax - cellXmin + 1;
                cellRgnHeight = cellYmax - cellYmin + 1;
                
                startRow = (cellYmin - 1) * ppv + 1;
                stopRow = startRow + cellRgnHeight * ppv - 1;
                startCol = (cellXmin - 1) * ppv + 1;
                stopCol = startCol + cellRgnWidth * ppv - 1;
                
                rgbChunk = ones(stopRow - startRow + 1, ...
                            stopCol - startCol + 1, ...
                            3);
                rgbChunk(:,:,1) = Obj.m_CellColorSwatches{vertexType + 1}(1,1,1);
                rgbChunk(:,:,2) = Obj.m_CellColorSwatches{vertexType + 1}(1,1,2);
                rgbChunk(:,:,3) = Obj.m_CellColorSwatches{vertexType + 1}(1,1,3);
            
                Obj.m_CellImage(startRow:stopRow, startCol:stopCol, :) = rgbChunk;
            else
                % case where single cell is passed
                startRow = (cellCoord(2) - 1) * ppv + 1;
                stopRow = startRow + ppv - 1;
                startCol = (cellCoord(1) - 1) * ppv + 1;
                stopCol = startCol + ppv - 1;
                
                Obj.m_CellImage(startRow:stopRow, startCol:stopCol, :) = ...
                    Obj.m_CellColorSwatches{vertexType + 1};
            end
            
            Obj.m_CellImageAlpha(startRow:stopRow, startCol:stopCol) = alphaVal;
            
            if(setImages)
                set(Obj.m_CellImageHandle, 'AlphaData', Obj.m_CellImageAlpha);
                set(Obj.m_CellImageHandle, 'CData', Obj.m_CellImage);
            end
        end
        
        function [plotCoord, cellCoord] = calcCellCoord(coordIn)
            Obj = MapEditor.GetSetInstance();
            ppv = Obj.m_PixelsPerVertex;
            myCoord = coordIn(1,1:2); % strip z component and any other points passed in
            
%             fprintf('(%f, %f)\n', myCoord(1), myCoord(2));
            
            % compute cell coordinate
            szCellFlags = size(Obj.m_CellFlags);
            cellCoord = ceil((myCoord - 0.5) / ppv);
            
            % constrain to be valid cell
            cellCoord(cellCoord < 1) = 1;
            if(cellCoord(2) > szCellFlags(1))
                cellCoord(2) = szCellFlags(1);
            end
            if(cellCoord(1) > szCellFlags(2))
                cellCoord(1) = szCellFlags(2);
            end
            
            % compute plotting coordinate
            plotCoord = MapEditor.cellCoord2PlotCoord(cellCoord);
        end
        
        function plotCoord = cellCoord2PlotCoord(cellCoord)
            Obj = MapEditor.GetSetInstance();
            ppv = Obj.m_PixelsPerVertex;
            plotCoord = (cellCoord - 1) * ppv + (ppv / 2) + 0.5;
        end
        
        function dragFcnToggle(srcObj, eventData, startIt)
            Obj = MapEditor.GetSetInstance();
            if(startIt)
                % turn on callback for windowbuttonmotionfcn
                set(Obj.m_Handles.figureMain, 'WindowButtonMotionFcn', @MapEditor.axisButtonDown);
            else
                % turn off
                set(Obj.m_Handles.figureMain, 'WindowButtonMotionFcn', '');
            end
        end
        
        function handleKeyPress(srcObj, eventData)
            Obj = MapEditor.GetSetInstance();
            if(strcmpi(eventData.Character, 'n'))
                MapEditor.radMouseNone_Callback();
                Obj.m_Handles.radMouseNone.Value = 1;
            elseif(strcmpi(eventData.Character, 'v'))
                MapEditor.radMousePan_Callback();
                Obj.m_Handles.radMousePan.Value = 1;
            elseif(strcmpi(eventData.Character, 's'))
                MapEditor.radMouseAddSidewalkVertex_Callback();
                Obj.m_Handles.radMouseAddVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'r'))
                MapEditor.radMouseAddRoadVertex_Callback();
                Obj.m_Handles.radMouseAddRoadVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'e'))
                MapEditor.radMouseAddEntranceVertex_Callback();
                Obj.m_Handles.radMouseAddEntranceVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'x'))
                MapEditor.radMouseAddExitVertex_Callback();
                Obj.m_Handles.radMouseAddExitVertex.Value = 1;
            elseif(strcmpi(eventData.Character, 'z'))
                MapEditor.radMouseRemVertex_Callback();
                Obj.m_Handles.radMouseRemVertex.Value = 1;
            end
        end
        
        function setupCellColorSwatches()
            Obj = MapEditor.GetSetInstance();
            ppv = Obj.m_PixelsPerVertex;
            
            % no type
            rgbChunk = zeros(ppv, ppv, 3);
            Obj.m_CellColorSwatches{1} = rgbChunk;
            
            % sidewalk
            rgbChunk = ones(ppv, ppv, 3);
            rgbChunk(:,:,1) = 0;
            rgbChunk(:,:,2) = 1;
            rgbChunk(:,:,3) = 1;
            Obj.m_CellColorSwatches{Obj.NODE_TYPE_SIDEWALK + 1} = rgbChunk;
            
            % road
            rgbChunk = ones(ppv, ppv, 3);
            rgbChunk(:,:,1) = 1;
            rgbChunk(:,:,2) = 1;
            rgbChunk(:,:,3) = 0.5;
            Obj.m_CellColorSwatches{Obj.NODE_TYPE_ROAD + 1} = rgbChunk;
            
            % entrance
            rgbChunk = ones(ppv, ppv, 3);
            rgbChunk(:,:,1) = 0.5;
            rgbChunk(:,:,2) = 1;
            rgbChunk(:,:,3) = 0.5;
            Obj.m_CellColorSwatches{Obj.NODE_TYPE_ENTRANCE + 1} = rgbChunk;
            
            % exit
            rgbChunk = ones(ppv, ppv, 3);
            rgbChunk(:,:,1) = 1;
            rgbChunk(:,:,2) = 0.5;
            rgbChunk(:,:,3) = 0.5;
            Obj.m_CellColorSwatches{Obj.NODE_TYPE_EXIT + 1} = rgbChunk;
        end

        
        
    end
    
end
