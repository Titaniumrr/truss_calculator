function truss_calculator
% Interactive 2D truss calculator in a single MATLAB file.
%
% Start:
%   truss_calculator
%
% Usage:
% - Edit nodes, members, materials, loads, and supports on the left.
% - "Compute" starts the FEM solver.
% - In "Normal" mode, nodes can be moved with the mouse.
% - In "Node by click" mode, click in the plot to add a node.
% - In "Member by click" mode, click two nodes in sequence.
% - Formulas are allowed in the node fields, e.g. x1+2 or:
%     px(2,1,4,30), py(2,1,4,30)
%   This creates a point from start node 2, relative to the direction
%   of member 2->1, with length 4 and angle +30 degrees.
% - Load points can be placed by click and completed in the load table.

state = struct();
state.mode = 'normal';
state.pendingElementStart = [];
state.dragNode = [];
state.dragMoved = false;
state.results = [];
state.resultView = 'members';
state.highlightElement = [];
state.units = struct('length', 'm', 'force', 'N', 'stress', 'Pa', 'young', 'Pa', 'area', 'm^2');
state.symbolicResults = [];
state.symbolicModel = [];
state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
state.symbolicAngleVariableNames = {};
state.symbolicFormat = 'trig';
state.symbolicDisplayCache = emptySymbolicDisplayCache();
state.cachedPlotSpan = [];
state.advancedOpen = false;
state.selection = struct('table', '', 'rows', []);
state.exampleName = 'Simple Roof Truss';
state.computeCancelRequested = false;
state.symbolicFastDisplay = false;

ui = struct();
buildUi();
loadExampleModel();
refreshAll();

    function buildUi()
        ui.fig = figure( ...
            'Name', 'Interactive Truss Calculator', ...
            'NumberTitle', 'off', ...
            'Color', [0.95 0.96 0.98], ...
            'MenuBar', 'none', ...
            'ToolBar', 'none', ...
            'Units', 'normalized', ...
            'Position', [0.03 0.05 0.94 0.88], ...
            'WindowButtonMotionFcn', @onWindowMouseMove, ...
            'WindowButtonUpFcn', @onWindowMouseUp);

        ui.leftPanel = uipanel( ...
            'Parent', ui.fig, ...
            'Title', 'Inputs', ...
            'Units', 'normalized', ...
            'Position', [0.01 0.01 0.42 0.98], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.rightPanel = uipanel( ...
            'Parent', ui.fig, ...
            'Title', 'Plot and Results', ...
            'Units', 'normalized', ...
            'Position', [0.44 0.01 0.55 0.98], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        buildControlPanel();
        buildNodePanel();
        buildElementPanel();
        buildMaterialPanel();
        buildAnglePanel();
        buildLoadPanel();
        buildSupportPanel();
        buildVariablePanel();
        buildAdvancedToggle();
        applyAdvancedLayout();
        buildPlotPanel();
        buildResultPanel();
    end

    function buildControlPanel()
        panel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Actions', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.86 0.96 0.12], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.exampleButton = uicontrol(panel, ...
            'Style', 'pushbutton', ...
            'String', 'Load Example', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.55 0.18 0.28], ...
            'Callback', @onLoadExample);

        ui.computeButton = uicontrol(panel, ...
            'Style', 'pushbutton', ...
            'String', 'Compute', ...
            'FontWeight', 'bold', ...
            'Units', 'normalized', ...
            'Position', [0.22 0.55 0.16 0.28], ...
            'Callback', @onCompute);

        ui.resetViewButton = uicontrol(panel, ...
            'Style', 'pushbutton', ...
            'String', 'Reset View', ...
            'Units', 'normalized', ...
            'Position', [0.40 0.55 0.16 0.28], ...
            'Callback', @onResetView);

        ui.clearResultsButton = uicontrol(panel, ...
            'Style', 'pushbutton', ...
            'String', 'Clear Results', ...
            'Units', 'normalized', ...
            'Position', [0.58 0.55 0.18 0.28], ...
            'Callback', @onClearResults);

        ui.statusText = uicontrol(panel, ...
            'Style', 'text', ...
            'HorizontalAlignment', 'left', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.12 0.42 0.20], ...
            'String', 'Mode: Normal', ...
            'BackgroundColor', [0.95 0.96 0.98], ...
            'ForegroundColor', [0.10 0.20 0.40]);

        modeGroup = uibuttongroup(panel, ...
            'Units', 'normalized', ...
            'Position', [0.48 0.05 0.46 0.30], ...
            'SelectionChangedFcn', @onModeChanged, ...
            'BackgroundColor', [0.95 0.96 0.98], ...
            'BorderType', 'none');

        ui.normalModeButton = uicontrol(modeGroup, ...
            'Style', 'radiobutton', ...
            'String', 'Normal', ...
            'Units', 'normalized', ...
            'Position', [0.01 0.05 0.24 0.9], ...
            'BackgroundColor', [0.95 0.96 0.98], ...
            'Value', 1);

        ui.addNodeModeButton = uicontrol(modeGroup, ...
            'Style', 'radiobutton', ...
            'String', 'Node', ...
            'Units', 'normalized', ...
            'Position', [0.25 0.05 0.22 0.9], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addElementModeButton = uicontrol(modeGroup, ...
            'Style', 'radiobutton', ...
            'String', 'Member', ...
            'Units', 'normalized', ...
            'Position', [0.49 0.05 0.24 0.9], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addLoadModeButton = uicontrol(modeGroup, ...
            'Style', 'radiobutton', ...
            'String', 'Load', ...
            'Units', 'normalized', ...
            'Position', [0.75 0.05 0.20 0.9], ...
            'BackgroundColor', [0.95 0.96 0.98]);
    end
    function buildNodePanel()
        ui.nodePanel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Node (X, Y)', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.63 0.46 0.22], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addNodeRowButton = uicontrol(ui.nodePanel, ...
            'Style', 'pushbutton', ...
            'String', '+ Node', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.88 0.24 0.10], ...
            'Callback', @onAddNodeRow);

        ui.deleteNodeRowButton = uicontrol(ui.nodePanel, ...
            'Style', 'pushbutton', ...
            'String', '- Node', ...
            'Units', 'normalized', ...
            'Position', [0.28 0.88 0.24 0.10], ...
            'Callback', @onDeleteNodeRow);

        ui.nodesTable = uitable(ui.nodePanel, ...
            'Units', 'normalized', ...
            'Position', [0.02 0.04 0.96 0.82], ...
            'Data', cell(0, 2), ...
            'ColumnName', {'X', 'Y'}, ...
            'ColumnEditable', [true true], ...
            'TooltipString', 'Examplee: x1+2, y2/3, px(2,1,4,30), py(2,1,4,30)', ...
            'CellSelectionCallback', @(src, evt) onTableSelection('nodes', evt), ...
            'CellEditCallback', @onAnyModelEdit);
    end

    function buildElementPanel()
        panel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Members (Node i, Node j, Material)', ...
            'Units', 'normalized', ...
            'Position', [0.50 0.63 0.48 0.22], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addElementRowButton = uicontrol(panel, ...
            'Style', 'pushbutton', ...
            'String', '+ Member', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.88 0.24 0.10], ...
            'Callback', @onAddElementRow);

        ui.deleteElementRowButton = uicontrol(panel, ...
            'Style', 'pushbutton', ...
            'String', '- Member', ...
            'Units', 'normalized', ...
            'Position', [0.28 0.88 0.24 0.10], ...
            'Callback', @onDeleteElementRow);

        ui.elementsTable = uitable(panel, ...
            'Units', 'normalized', ...
            'Position', [0.02 0.04 0.96 0.82], ...
            'Data', cell(0, 3), ...
            'ColumnName', {'i', 'j', 'Mat'}, ...
            'ColumnEditable', [true true true], ...
            'CellSelectionCallback', @(src, evt) onTableSelection('elements', evt), ...
            'CellEditCallback', @onAnyModelEdit);
    end

    function buildMaterialPanel()
        ui.materialPanel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Cross Sections and Young''s Modulus', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.46 0.46 0.15], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addMaterialRowButton = uicontrol(ui.materialPanel, ...
            'Style', 'pushbutton', ...
            'String', '+ Material', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.84 0.28 0.12], ...
            'Callback', @onAddMaterialRow);

        ui.deleteMaterialRowButton = uicontrol(ui.materialPanel, ...
            'Style', 'pushbutton', ...
            'String', '- Material', ...
            'Units', 'normalized', ...
            'Position', [0.32 0.84 0.28 0.12], ...
            'Callback', @onDeleteMaterialRow);

        ui.materialsTable = uitable(ui.materialPanel, ...
            'Units', 'normalized', ...
            'Position', [0.02 0.04 0.96 0.76], ...
            'Data', cell(0, 5), ...
            'ColumnName', {'Type', 'd/b', 't', 'h', 'E'}, ...
            'ColumnEditable', [true true true true true], ...
            'ColumnFormat', {{'Circular', 'Tube', 'Rectangular'}, 'numeric', 'numeric', 'numeric', 'numeric'}, ...
            'CellSelectionCallback', @(src, evt) onTableSelection('materials', evt), ...
            'CellEditCallback', @onAnyModelEdit);
    end

    function buildLoadPanel()
        ui.loadPanel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Load application points (X, Y, Fx/Fy or F/angle)', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.12 0.96 0.19], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addLoadRowButton = uicontrol(ui.loadPanel, ...
            'Style', 'pushbutton', ...
            'String', '+ Load', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.88 0.20 0.09], ...
            'Callback', @onAddLoadRow);

        ui.deleteLoadRowButton = uicontrol(ui.loadPanel, ...
            'Style', 'pushbutton', ...
            'String', '- Load', ...
            'Units', 'normalized', ...
            'Position', [0.24 0.88 0.20 0.09], ...
            'Callback', @onDeleteLoadRow);

        ui.loadsTable = uitable(ui.loadPanel, ...
            'Units', 'normalized', ...
            'Position', [0.02 0.04 0.96 0.80], ...
            'Data', cell(0, 6), ...
            'ColumnName', {'X', 'Y', 'Fx', 'Fy', 'F', 'phi'}, ...
            'ColumnEditable', [true true true true true true], ...
            'ColumnFormat', {'char', 'char', 'char', 'char', 'char', 'char'}, ...
            'CellSelectionCallback', @(src, evt) onTableSelection('loads', evt), ...
            'CellEditCallback', @onLoadTableEdited);
    end

    function buildAnglePanel()
        ui.anglePanel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Angles Between Members (Member 1, Member 2, Angle)', ...
            'Units', 'normalized', ...
            'Position', [0.50 0.46 0.48 0.15], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addAngleRowButton = uicontrol(ui.anglePanel, ...
            'Style', 'pushbutton', ...
            'String', '+ Angle', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.84 0.24 0.12], ...
            'Callback', @onAddAngleRow);

        ui.deleteAngleRowButton = uicontrol(ui.anglePanel, ...
            'Style', 'pushbutton', ...
            'String', '- Angle', ...
            'Units', 'normalized', ...
            'Position', [0.28 0.84 0.24 0.12], ...
            'Callback', @onDeleteAngleRow);

        ui.anglesTable = uitable(ui.anglePanel, ...
            'Units', 'normalized', ...
            'Position', [0.02 0.04 0.96 0.76], ...
            'Data', cell(0, 3), ...
            'ColumnName', {'Member 1', 'Member 2', 'Angle'}, ...
            'ColumnEditable', [true true true], ...
            'ColumnFormat', {'char', 'char', 'char'}, ...
            'TooltipString', 'Example: Member 1, Member 3, angle alpha or 60. The members must share one common node.', ...
            'CellSelectionCallback', @(src, evt) onTableSelection('angles', evt), ...
            'CellEditCallback', @onAnyModelEdit);
    end

    function buildSupportPanel()
        ui.supportPanel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Supports (Type, Angle)', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.14 0.96 0.13], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.supportsTable = uitable(ui.supportPanel, ...
            'Units', 'normalized', ...
            'Position', [0.02 0.06 0.96 0.88], ...
            'Data', cell(0, 2), ...
            'ColumnName', {'Type', 'Angle'}, ...
            'ColumnEditable', [true true], ...
            'ColumnFormat', {{'No Support', 'Pinned Support', 'Roller Support', 'Fixed Support'}, {'0', '90', '180', '270'}}, ...
            'CellSelectionCallback', @(src, evt) onTableSelection('supports', evt), ...
            'CellEditCallback', @onAnyModelEdit);
    end

    function buildVariablePanel()
        ui.variablePanel = uipanel( ...
            'Parent', ui.leftPanel, ...
            'Title', 'Preview Values for Variables (optional)', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.01 0.96 0.11], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.addVariableRowButton = uicontrol(ui.variablePanel, ...
            'Style', 'pushbutton', ...
            'String', '+ Variable', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.82 0.20 0.14], ...
            'Callback', @onAddVariableRow);

        ui.deleteVariableRowButton = uicontrol(ui.variablePanel, ...
            'Style', 'pushbutton', ...
            'String', '- Variable', ...
            'Units', 'normalized', ...
            'Position', [0.24 0.82 0.20 0.14], ...
            'Callback', @onDeleteVariableRow);

        ui.variablesTable = uitable(ui.variablePanel, ...
            'Units', 'normalized', ...
            'Position', [0.02 0.04 0.96 0.74], ...
            'Data', cell(0, 2), ...
            'ColumnName', {'Name', 'Preview value'}, ...
            'ColumnEditable', [true true], ...
            'TooltipString', 'Variables duerfen direkt in allen Feldern stehen. Hier kannst du nur optionale Preview values wie a | 4.2 hinterlegen.', ...
            'CellSelectionCallback', @(src, evt) onTableSelection('variables', evt), ...
            'CellEditCallback', @onAnyModelEdit);
    end

    function buildAdvancedToggle()
        ui.advancedToggleButton = uicontrol(ui.leftPanel, ...
            'Style', 'pushbutton', ...
            'String', 'Show Advanced Settings', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.56 0.96 0.04], ...
            'Callback', @onToggleAdvancedSettings);
    end

    function buildPlotPanel()
        plotPanel = uipanel( ...
            'Parent', ui.rightPanel, ...
            'Title', 'Truss View', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.34 0.96 0.64], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.axes = axes( ...
            'Parent', plotPanel, ...
            'Units', 'normalized', ...
            'Position', [0.06 0.08 0.90 0.88], ...
            'Box', 'on', ...
            'ButtonDownFcn', @onAxesClick);
        grid(ui.axes, 'on');
        axis(ui.axes, 'equal');
        xlabel(ui.axes, 'X');
        ylabel(ui.axes, 'Y');
        title(ui.axes, 'Undeformed Truss');
    end

    function buildResultPanel()
        panel = uipanel( ...
            'Parent', ui.rightPanel, ...
            'Title', 'Details and Results', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.02 0.96 0.30], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.infoBox = uicontrol(panel, ...
            'Style', 'edit', ...
            'Min', 0, ...
            'Max', 5, ...
            'Enable', 'inactive', ...
            'HorizontalAlignment', 'left', ...
            'Units', 'normalized', ...
            'Position', [0.02 0.10 0.36 0.86], ...
            'BackgroundColor', [1 1 1], ...
            'String', 'Ready.');

        ui.resultViewMenu = uicontrol(panel, ...
            'Style', 'popupmenu', ...
            'String', {'Member Forces', 'Support Reactions'}, ...
            'Units', 'normalized', ...
            'Position', [0.40 0.92 0.20 0.06], ...
            'BackgroundColor', [1 1 1], ...
            'Callback', @onResultViewChanged);

        ui.symbolicFormatLabel = uicontrol(panel, ...
            'Style', 'text', ...
            'String', 'Symbolik', ...
            'HorizontalAlignment', 'left', ...
            'Units', 'normalized', ...
            'Position', [0.62 0.92 0.10 0.05], ...
            'BackgroundColor', [0.95 0.96 0.98]);

        ui.symbolicFormatMenu = uicontrol(panel, ...
            'Style', 'popupmenu', ...
            'String', {'sin/cos', 'Fraction/Root'}, ...
            'Units', 'normalized', ...
            'Position', [0.73 0.92 0.25 0.06], ...
            'BackgroundColor', [1 1 1], ...
            'Value', 1, ...
            'Callback', @onSymbolicFormatChanged);

        ui.resultsTable = uitable(panel, ...
            'Units', 'normalized', ...
            'Position', [0.40 0.10 0.58 0.80], ...
            'Data', cell(0, 4), ...
            'ColumnName', {'Member', 'N', 'sigma', 'Length'}, ...
            'ColumnEditable', [false false false false], ...
            'CellSelectionCallback', @onResultsTableSelection);
    end

    function loadExampleModel()
        nodeEntries = {
            '0', '0'
            '5', '0'
            '10', '0'
            '2.5', '3'
            '7.5', '3'
            };
        elements = {
            1, 2, 1
            2, 3, 1
            1, 4, 1
            4, 2, 1
            2, 5, 1
            5, 3, 1
            4, 5, 1
            };
        materials = {
            'Circular', 0.05, 0, 0, 210e9
            };
        loads = {
            '2.5', '3', '', '', '12000', '-90'
            '7.5', '3', '', '', '12000', '-90'
            };
        supports = {
            'Pinned Support', '0'
            'No Support', '0'
            'Roller Support', '0'
            'No Support', '0'
            'No Support', '0'
            };

        set(ui.nodesTable, 'Data', nodeEntries);
        set(ui.elementsTable, 'Data', elements);
        set(ui.materialsTable, 'Data', materials);
        set(ui.anglesTable, 'Data', cell(0, 3));
        set(ui.loadsTable, 'Data', loads);
        set(ui.supportsTable, 'Data', supports);
        set(ui.variablesTable, 'Data', {'a', 4; 'h', 3; 'F', 1000});
        updateRowNames();
        state.results = [];
        state.symbolicResults = [];
        state.symbolicModel = [];
        state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
        state.symbolicAngleVariableNames = {};
        state.symbolicDisplayCache = emptySymbolicDisplayCache();
        state.pendingElementStart = [];
        updateInfo(sprintf(['Example model "%s" loaded.\n' ...
            'Click "Compute" to see displacements, member forces, and support reactions.\n' ...
            'Nodes can also be created using angles, e.g. with px(2,1,4,30) and py(2,1,4,30).\n' ...
            'Variables such as a, h, or F can be entered directly in the fields. Preview values are optional.'], ...
            state.exampleName));
    end

    function refreshAll()
        updateUnitLabels();
        applyAdvancedLayout();
        updateRowNames();
        refreshPlot();
        refreshResultsTable();
        updateSymbolicFormatControl();
        updateStatusLabel();
    end

    function updateSymbolicFormatControl()
        hasSymbolic = ~isempty(state.symbolicResults);
        if hasSymbolic
            set(ui.symbolicFormatMenu, 'Enable', 'on');
            set(ui.symbolicFormatLabel, 'ForegroundColor', [0.10 0.10 0.10]);
        else
            set(ui.symbolicFormatMenu, 'Enable', 'off');
            set(ui.symbolicFormatLabel, 'ForegroundColor', [0.45 0.45 0.45]);
        end
    end

    function updateUnitLabels()
        set(ui.nodePanel, 'Title', sprintf('Nodes [%s] with formulas x/y or px/py', state.units.length));
        set(ui.loadPanel, 'Title', sprintf('Load Application Points [%s, %s] with Fx/Fy or F/angle', ...
            state.units.length, state.units.force));
        set(ui.materialPanel, 'Title', sprintf('Cross Sections [%s, %s] and E [%s]', ...
            state.units.length, state.units.area, state.units.young));
        set(ui.supportPanel, 'Title', 'Supports (Type, Angle)');

        set(ui.nodesTable, 'ColumnName', ...
            {sprintf('X [%s]', state.units.length), sprintf('Y [%s]', state.units.length)});
        set(ui.materialsTable, 'ColumnName', ...
            {'Type', sprintf('d/b [%s]', state.units.length), sprintf('t [%s]', state.units.length), ...
             sprintf('h [%s]', state.units.length), sprintf('E [%s]', state.units.young)});
        set(ui.loadsTable, 'ColumnName', ...
            {sprintf('X [%s]', state.units.length), sprintf('Y [%s]', state.units.length), ...
             sprintf('Fx [%s]', state.units.force), sprintf('Fy [%s]', state.units.force), ...
             sprintf('F [%s]', state.units.force), 'phi [deg]'});
    end

    function onToggleAdvancedSettings(~, ~)
        state.advancedOpen = ~state.advancedOpen;
        applyAdvancedLayout();
        refreshAll();
    end

    function applyAdvancedLayout()
        if ~isfield(ui, 'materialPanel') || ~isfield(ui, 'anglePanel') || ~isfield(ui, 'variablePanel') || ...
                ~isfield(ui, 'loadPanel') || ~isfield(ui, 'supportPanel')
            return;
        end

        set(ui.advancedToggleButton, 'Position', [0.02 0.56 0.96 0.04]);
        if state.advancedOpen
            set(ui.advancedToggleButton, 'String', 'Hide Advanced Settings');
            set(ui.materialPanel, 'Visible', 'on', 'Position', [0.02 0.37 0.31 0.14]);
            set(ui.anglePanel, 'Visible', 'on', 'Position', [0.34 0.37 0.31 0.14]);
            set(ui.variablePanel, 'Visible', 'on', 'Position', [0.66 0.37 0.32 0.14]);
            set(ui.loadPanel, 'Position', [0.02 0.14 0.96 0.21]);
            set(ui.supportPanel, 'Position', [0.02 0.01 0.96 0.10]);
        else
            set(ui.advancedToggleButton, 'String', 'Show Advanced Settings');
            set(ui.materialPanel, 'Visible', 'off');
            set(ui.anglePanel, 'Visible', 'off');
            set(ui.variablePanel, 'Visible', 'off');
            set(ui.loadPanel, 'Position', [0.02 0.24 0.96 0.25]);
            set(ui.supportPanel, 'Position', [0.02 0.12 0.96 0.10]);
        end
    end

    function refreshPlot()
        cla(ui.axes);
        hold(ui.axes, 'on');
        state.cachedPlotSpan = [];

        [model, errMsg, isReady] = getDisplayModel();
        if isempty(model.nodes) && isempty(model.loadPoints)
            title(ui.axes, 'Truss View');
            text(0.5, 0.5, 'No valid nodes available yet.', ...
                'Parent', ui.axes, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'center', ...
                'Color', [0.25 0.25 0.25], ...
                'FontWeight', 'bold');
            axis(ui.axes, 'equal');
            grid(ui.axes, 'on');
            hold(ui.axes, 'off');
            state.cachedPlotSpan = [];
            return;
        end

        plotPoints = plotPointsForModel(model);
        if ~isempty(plotPoints)
            xSpan = max(plotPoints(:, 1)) - min(plotPoints(:, 1));
            ySpan = max(plotPoints(:, 2)) - min(plotPoints(:, 2));
            state.cachedPlotSpan = max([xSpan, ySpan, 1]);
        else
            state.cachedPlotSpan = 1;
        end

        nodes = model.nodes;
        elements = model.elements;
        supportDefs = model.supportDefs;

        maxAbsForce = 0;
        if ~isempty(state.results)
            maxAbsForce = max(abs(state.results.axialForces));
        end

        for e = 1:size(elements, 1)
            i = elements(e, 1);
            j = elements(e, 2);
            p1 = nodes(i, :);
            p2 = nodes(j, :);

            plot(ui.axes, [p1(1), p2(1)], [p1(2), p2(2)], ...
                '--', 'Color', [0.75 0.75 0.75], 'LineWidth', 1.0, ...
                'HitTest', 'off');

            if isempty(state.results) || ~isReady
                color = [0.15 0.15 0.15];
                xData = [p1(1), p2(1)];
                yData = [p1(2), p2(2)];
            else
                defNodes = nodes + state.results.scale * state.results.displacements;
                q1 = defNodes(i, :);
                q2 = defNodes(j, :);
                xData = [q1(1), q2(1)];
                yData = [q1(2), q2(2)];
                color = forceColor(state.results.axialForces(e), maxAbsForce);
            end

            if isequal(state.highlightElement, e)
                line(ui.axes, xData, yData, ...
                    'Color', [1.00 0.84 0.10], ...
                    'LineWidth', 7.0, ...
                    'HitTest', 'off');
            end

            line(ui.axes, xData, yData, ...
                'Color', color, ...
                'LineWidth', 3.0, ...
                'PickableParts', 'all', ...
                'ButtonDownFcn', @(src, evt) onElementClicked(e));
        end

        nodeSize = 56;
        for k = 1:size(nodes, 1)
            p = nodes(k, :);

            if isempty(state.results)
                markerFaceColor = [0.05 0.35 0.70];
            else
                markerFaceColor = [0.05 0.40 0.75];
            end

            line(ui.axes, p(1), p(2), ...
                'LineStyle', 'none', ...
                'Marker', 'o', ...
                'MarkerSize', 7, ...
                'MarkerFaceColor', markerFaceColor, ...
                'MarkerEdgeColor', [0.05 0.18 0.35], ...
                'PickableParts', 'all', ...
                'ButtonDownFcn', @(src, evt) onNodeClicked(k));

            text(p(1), p(2), sprintf('  %d', k), ...
                'Parent', ui.axes, ...
                'Color', [0.10 0.10 0.10], ...
                'FontWeight', 'bold', ...
                'VerticalAlignment', 'bottom', ...
                'HitTest', 'off');

            if ~strcmpi(supportDefs{k, 1}, 'No Support')
                drawSupportSymbol(p, supportDefs(k, :), nodeSize);
            end

        end

        for k = 1:size(model.loadPoints, 1)
            loadPoint = model.loadPoints(k, :);
            drawLoadArrow(loadPoint(1:2), loadPoint(3:4));
            line(ui.axes, loadPoint(1), loadPoint(2), ...
                'LineStyle', 'none', ...
                'Marker', 's', ...
                'MarkerSize', 8, ...
                'MarkerFaceColor', [0.10 0.55 0.12], ...
                'MarkerEdgeColor', [0.05 0.25 0.08], ...
                'PickableParts', 'all', ...
                'ButtonDownFcn', @(src, evt) onLoadPointClicked(k));
        end

        if strcmp(state.mode, 'addelement') && ~isempty(state.pendingElementStart)
            p = nodes(state.pendingElementStart, :);
            plot(ui.axes, p(1), p(2), 'o', ...
                'MarkerSize', 13, ...
                'LineWidth', 2, ...
                'MarkerEdgeColor', [0.95 0.60 0.05], ...
                'HitTest', 'off');
        end

        titleText = 'Bau-Preview';
        if isReady
            titleText = 'Undeformed Truss';
        end
        if ~isempty(state.results) && isReady
            titleText = sprintf('Deformed Truss (Deformation x %.3g)', state.results.scale);
        end
        title(ui.axes, titleText);
        axis(ui.axes, 'equal');
        grid(ui.axes, 'on');
        padAxes(plotPoints);
        applySymbolicAxisLabels(model);
        if ~isReady && ~isempty(errMsg)
            text(0.01, 0.98, sprintf('Preview aktiv: %s', errMsg), ...
                'Parent', ui.axes, ...
                'Units', 'normalized', ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', ...
                'Color', [0.65 0.12 0.12], ...
                'BackgroundColor', [1.0 0.98 0.98], ...
                'Margin', 4, ...
                'HitTest', 'off');
        end
        hold(ui.axes, 'off');
        state.cachedPlotSpan = [];
    end

    function drawSupportSymbol(p, supportDef, ~)
        supportType = normalizeSupportType(supportDef{1});
        angle = normalizeSupportAngle(supportDef{2});
        span = max(currentSpan(), 1);
        halfBase = 0.10 * span;
        triHeight = 0.11 * span;
        lineOffset = 0.04 * span;
        hatchStep = 0.05 * span;
        lineColor = [0.20 0.20 0.20];

        switch supportType
            case 'Pinned Support'
                localTriangle = [0 0; -halfBase -triHeight; halfBase -triHeight];
                tri = rotateAndTranslate(localTriangle, angle, p);
                patch('Parent', ui.axes, ...
                    'XData', tri(:, 1), ...
                    'YData', tri(:, 2), ...
                    'FaceColor', [0.78 0.78 0.78], ...
                    'EdgeColor', lineColor, ...
                    'LineWidth', 1.5, ...
                    'HitTest', 'off');

            case 'Roller Support'
                localTriangle = [0 0; -halfBase -triHeight; halfBase -triHeight];
                tri = rotateAndTranslate(localTriangle, angle, p);
                patch('Parent', ui.axes, ...
                    'XData', tri(:, 1), ...
                    'YData', tri(:, 2), ...
                    'FaceColor', [1 1 1], ...
                    'EdgeColor', lineColor, ...
                    'LineWidth', 1.5, ...
                    'HitTest', 'off');

                localBase = [-halfBase -triHeight - lineOffset; halfBase -triHeight - lineOffset];
                baseLine = rotateAndTranslate(localBase, angle, p);
                plot(ui.axes, baseLine(:, 1), baseLine(:, 2), '-', ...
                    'Color', lineColor, 'LineWidth', 2.0, 'HitTest', 'off');

                hatchXs = (-halfBase + hatchStep / 2):hatchStep:(halfBase - hatchStep / 2);
                for xVal = hatchXs
                    localHatch = [xVal - 0.02 * span, -triHeight - lineOffset - 0.03 * span; ...
                        xVal + 0.02 * span, -triHeight - lineOffset - 0.08 * span];
                    hatchLine = rotateAndTranslate(localHatch, angle, p);
                    plot(ui.axes, hatchLine(:, 1), hatchLine(:, 2), '-', ...
                        'Color', lineColor, 'LineWidth', 1.2, 'HitTest', 'off');
                end

            case 'Fixed Support'
                localWall = [0 -triHeight * 0.95; 0 triHeight * 0.95];
                wallLine = rotateAndTranslate(localWall, angle + 90, p);
                plot(ui.axes, wallLine(:, 1), wallLine(:, 2), '-', ...
                    'Color', lineColor, 'LineWidth', 3.0, 'HitTest', 'off');

                hatchYs = linspace(-triHeight * 0.75, triHeight * 0.75, 5);
                for yVal = hatchYs
                    localHatch = [0 yVal; -0.06 * span yVal - 0.04 * span];
                    hatchLine = rotateAndTranslate(localHatch, angle + 90, p);
                    plot(ui.axes, hatchLine(:, 1), hatchLine(:, 2), '-', ...
                        'Color', lineColor, 'LineWidth', 1.2, 'HitTest', 'off');
                end
        end

        plot(ui.axes, p(1), p(2), 'o', ...
            'MarkerSize', 7, ...
            'LineWidth', 1.2, ...
            'MarkerFaceColor', [0.95 0.96 0.98], ...
            'MarkerEdgeColor', [0.05 0.18 0.35], ...
            'HitTest', 'off');
    end

    function drawLoadArrow(p, f)
        span = max(currentSpan(), 1);
        normForce = norm(f);
        if normForce < eps
            return;
        end

        scale = 0.12 * span / normForce;
        q = p + scale * f;
        quiver(ui.axes, p(1), p(2), q(1) - p(1), q(2) - p(2), 0, ...
            'Color', [0.10 0.55 0.12], ...
            'LineWidth', 2, ...
            'MaxHeadSize', 0.8, ...
            'HitTest', 'off');
    end

    function span = currentSpan()
        if ~isempty(state.cachedPlotSpan) && isfinite(state.cachedPlotSpan)
            span = state.cachedPlotSpan;
            return;
        end
        [model, ~, ~] = getDisplayModel();
        points = plotPointsForModel(model);
        if isempty(points)
            span = 1;
            return;
        end
        xSpan = max(points(:, 1)) - min(points(:, 1));
        ySpan = max(points(:, 2)) - min(points(:, 2));
        span = max([xSpan, ySpan, 1]);
    end

    function padAxes(nodes)
        xMin = min(nodes(:, 1));
        xMax = max(nodes(:, 1));
        yMin = min(nodes(:, 2));
        yMax = max(nodes(:, 2));
        span = max([xMax - xMin, yMax - yMin, 1]);
        margin = 0.18 * span;

        xlim(ui.axes, [xMin - margin, xMax + margin]);
        ylim(ui.axes, [yMin - margin, yMax + margin]);
    end

    function points = plotPointsForModel(model)
        points = model.nodes;
        if isfield(model, 'loadPoints') && ~isempty(model.loadPoints)
            points = [points; model.loadPoints(:, 1:2)];
        end
        if isempty(points)
            points = zeros(0, 2);
        end
    end

    function applySymbolicAxisLabels(model)
        if ~isfield(model, 'symbolicNodes') || isempty(model.symbolicNodes) || ~isa(model.symbolicNodes, 'sym')
            xtickformat(ui.axes, 'auto');
            ytickformat(ui.axes, 'auto');
            return;
        end

        applySymbolicTicksForAxis(model.nodes(:, 1), model.symbolicNodes(:, 1), 'x');
        applySymbolicTicksForAxis(model.nodes(:, 2), model.symbolicNodes(:, 2), 'y');
    end

    function applySymbolicTicksForAxis(numericVals, symbolicVals, axisName)
        if isempty(numericVals) || isempty(symbolicVals)
            return;
        end
        roundedVals = round(double(numericVals), 8);
        [uniqueVals, ia] = unique(roundedVals, 'stable');
        if numel(uniqueVals) > 8
            return;
        end
        labels = arrayfun(@(idx) char(simplify(symbolicVals(idx))), ia, 'UniformOutput', false);
        [uniqueVals, order] = sort(uniqueVals);
        labels = labels(order);
        switch axisName
            case 'x'
                set(ui.axes, 'XTick', uniqueVals, 'XTickLabel', labels);
            case 'y'
                set(ui.axes, 'YTick', uniqueVals, 'YTickLabel', labels);
        end
    end

    function updateRowNames()
        nodeCount = size(getTableDataAsCell(ui.nodesTable), 1);
        set(ui.nodesTable, 'RowName', makeRowNames(nodeCount));
        set(ui.loadsTable, 'RowName', makeRowNames(size(getTableDataAsCell(ui.loadsTable), 1)));
        set(ui.anglesTable, 'RowName', makeRowNames(size(getTableDataAsCell(ui.anglesTable), 1)));
        set(ui.supportsTable, 'RowName', makeRowNames(size(getTableDataAsCell(ui.supportsTable), 1)));
        set(ui.variablesTable, 'RowName', makeRowNames(size(getTableDataAsCell(ui.variablesTable), 1)));
        set(ui.elementsTable, 'RowName', makeRowNames(size(getTableDataAsCell(ui.elementsTable), 1)));
        set(ui.materialsTable, 'RowName', makeRowNames(size(getTableDataAsCell(ui.materialsTable), 1)));
        set(ui.resultsTable, 'RowName', makeRowNames(size(getTableDataAsCell(ui.resultsTable), 1)));
    end

    function names = makeRowNames(n)
        names = arrayfun(@num2str, 1:n, 'UniformOutput', false);
    end

    function onLoadExample(~, ~)
        loadExampleModel();
        refreshAll();
    end

    function onCompute(~, ~)
        raw = readRawModelFromTables();
        variableDefs = collectVariableDefs(raw);
        angleVariableNames = collectAngleVariableNames(raw);
        previousState = snapshotResultState();
        progressHandle = beginComputeProgress();
        if ~isempty(variableDefs.names)
            try
                updateComputeProgress(progressHandle, 0.15, 'Building symbolic model...');
                model = buildSymbolicModel(raw, variableDefs);
                updateComputeProgress(progressHandle, 0.35, 'Selecting symbolic solver...');
                state.results = [];
                state.symbolicVariableDefs = variableDefs;
                state.symbolicAngleVariableNames = angleVariableNames;
                if canUseSymbolicJointSolver(model)
                    updateComputeProgress(progressHandle, 0.55, 'Checking joint equilibrium...');
                    try
                        state.symbolicResults = solveTrussSymbolicByEquilibrium(model);
                    catch eqErr
                        if isComputeCancelledError(eqErr)
                            rethrow(eqErr);
                        end
                        updateComputeProgress(progressHandle, 0.60, 'Switching to symbolic FEM system...');
                        state.symbolicResults = solveTrussSymbolic(model);
                    end
                else
                    updateComputeProgress(progressHandle, 0.55, 'Solving symbolic FEM system...');
                    state.symbolicResults = solveTrussSymbolic(model);
                end
                state.symbolicModel = model;
                state.symbolicDisplayCache = emptySymbolicDisplayCache();
                state.symbolicFastDisplay = shouldUseFastSymbolicDisplay(model, state.symbolicResults);
                updateComputeProgress(progressHandle, 0.80, 'Preparing display...');
                if shouldPrimeSymbolicDisplayCaches()
                    primeSymbolicDisplayCaches();
                end
                updateComputeProgress(progressHandle, 0.95, 'Updating GUI...');
                refreshAll();
                updateInfo(summaryTextSymbolic(model, state.symbolicResults, variableDefs));
                endComputeProgress(progressHandle);
            catch err
                if isComputeCancelledError(err)
                    restoreResultState(previousState);
                    refreshAll();
                    updateInfo('Computation cancelled.');
                else
                    state.symbolicResults = [];
                    state.results = [];
                    state.symbolicModel = [];
                    state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
                    state.symbolicAngleVariableNames = {};
                    state.symbolicDisplayCache = emptySymbolicDisplayCache();
                    state.symbolicFastDisplay = false;
                    refreshAll();
                    updateInfo(sprintf('Symbolische Computation failed:\n%s', err.message));
                end
                endComputeProgress(progressHandle);
            end
            return;
        end

        updateComputeProgress(progressHandle, 0.20, 'Checking numeric model...');
        [model, errMsg] = tryGetNumericModel();
        if ~isempty(errMsg)
            state.results = [];
            state.symbolicResults = [];
            state.symbolicModel = [];
            state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
            state.symbolicAngleVariableNames = {};
            state.symbolicDisplayCache = emptySymbolicDisplayCache();
            state.symbolicFastDisplay = false;
            refreshAll();
            updateInfo(errMsg);
            endComputeProgress(progressHandle);
            return;
        end

        try
            updateComputeProgress(progressHandle, 0.65, 'Solving equation system...');
            state.results = solveTruss(model);
            state.symbolicResults = [];
            state.symbolicModel = [];
            state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
            state.symbolicAngleVariableNames = {};
            state.symbolicDisplayCache = emptySymbolicDisplayCache();
            state.symbolicFastDisplay = false;
            updateComputeProgress(progressHandle, 0.95, 'Updating GUI...');
            refreshAll();
            updateInfo(summaryText(model, state.results));
            endComputeProgress(progressHandle);
        catch err
            if isComputeCancelledError(err)
                restoreResultState(previousState);
                refreshAll();
                updateInfo('Computation cancelled.');
            else
                state.results = [];
                state.symbolicResults = [];
                state.symbolicModel = [];
                state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
                state.symbolicAngleVariableNames = {};
                state.symbolicDisplayCache = emptySymbolicDisplayCache();
                state.symbolicFastDisplay = false;
                refreshAll();
                updateInfo(sprintf('Computation failed:\n%s', err.message));
            end
            endComputeProgress(progressHandle);
        end
    end

    function onResetView(~, ~)
        [model, ~, ~] = getDisplayModel();
        refreshPlot();
        plotPoints = plotPointsForModel(model);
        if ~isempty(plotPoints)
            padAxes(plotPoints);
            applySymbolicAxisLabels(model);
        end
        updateInfo('View reset.');
    end

    function onClearResults(~, ~)
        state.results = [];
        state.symbolicResults = [];
        state.symbolicModel = [];
        state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
        state.symbolicAngleVariableNames = {};
        state.symbolicDisplayCache = emptySymbolicDisplayCache();
        state.symbolicFastDisplay = false;
        refreshAll();
        updateInfo('Results cleared. Geometry and input data are kept.');
    end
    function onModeChanged(~, evt)
        newLabel = get(evt.NewValue, 'String');
        switch newLabel
            case 'Normal'
                state.mode = 'normal';
            case 'Node'
                state.mode = 'addnode';
            case 'Member'
                state.mode = 'addelement';
            case 'Load'
                state.mode = 'addload';
            otherwise
                state.mode = 'normal';
        end
        state.pendingElementStart = [];
        state.dragNode = [];
        updateStatusLabel();
        refreshPlot();
        switch state.mode
            case 'normal'
                updateInfo('Mode: Normal. Nodes can be moved with the mouse.');
            case 'addnode'
                updateInfo('Mode: Node by click. Click in the plot to add a new node.');
            case 'addelement'
                updateInfo('Mode: Member by click. Click two nodes in sequence to create a member.');
            case 'addload'
                updateInfo('Mode: Load by click. Click nodes or members in the plot to place load points, then enter the force values in the load table.');
        end
    end

    function updateStatusLabel()
        labels = struct( ...
            'normal', 'Mode: Normal', ...
            'addnode', 'Mode: Node', ...
            'addelement', 'Mode: Member', ...
            'addload', 'Mode: Load');
        set(ui.statusText, 'String', labels.(state.mode));
    end

    function onAddNodeRow(~, ~)
        nodeData = getTableDataAsCell(ui.nodesTable);
        supportData = getTableDataAsCell(ui.supportsTable);

        nodeData(end + 1, :) = {'', ''};
        supportData(end + 1, :) = {'No Support', '0'};

        set(ui.nodesTable, 'Data', nodeData);
        set(ui.supportsTable, 'Data', supportData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo('New node added. Please enter X and Y coordinates.');
    end

    function onDeleteNodeRow(~, ~)
        row = selectedRowFor('nodes');
        if isempty(row)
            updateInfo('Please select a row in the node table first before deleting.');
            return;
        end

        nodeData = getTableDataAsCell(ui.nodesTable);
        supportData = getTableDataAsCell(ui.supportsTable);
        elemData = getTableDataAsCell(ui.elementsTable);

        nodeData(row, :) = [];
        supportData(row, :) = [];
        elemData = removeNodeFromElementData(elemData, row);

        set(ui.nodesTable, 'Data', nodeData);
        set(ui.supportsTable, 'Data', supportData);
        set(ui.elementsTable, 'Data', elemData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Node %d removed. Affected members were adjusted or deleted.', row));
    end

    function onAddElementRow(~, ~)
        elemData = getTableDataAsCell(ui.elementsTable);
        nodeCount = size(getTableDataAsCell(ui.nodesTable), 1);
        matCount = max(size(getTableDataAsCell(ui.materialsTable), 1), 1);
        if nodeCount >= 2
            newRow = {1, 2, min(1, matCount)};
        else
            newRow = {'', '', 1};
        end
        elemData(end + 1, :) = newRow;
        set(ui.elementsTable, 'Data', elemData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo('New member added.');
    end

    function onDeleteElementRow(~, ~)
        row = selectedRowFor('elements');
        if isempty(row)
            updateInfo('Please select a row in the member table first before deleting.');
            return;
        end
        elemData = getTableDataAsCell(ui.elementsTable);
        elemData(row, :) = [];
        set(ui.elementsTable, 'Data', elemData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Member %d removed.', row));
    end

    function onAddMaterialRow(~, ~)
        materialData = getTableDataAsCell(ui.materialsTable);
        materialData(end + 1, :) = {'Circular', 0.05, 0, 0, 210e9};
        set(ui.materialsTable, 'Data', materialData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo('New cross section added.');
    end

    function onDeleteMaterialRow(~, ~)
        row = selectedRowFor('materials');
        if isempty(row)
            updateInfo('Please select a row in the material table first before deleting.');
            return;
        end

        materialData = getTableDataAsCell(ui.materialsTable);
        if size(materialData, 1) <= 1
            updateInfo('At least one material must remain.');
            return;
        end

        elemData = getTableDataAsCell(ui.elementsTable);
        elemMat = nan(size(elemData, 1), 1);
        for k = 1:size(elemData, 1)
            elemMat(k) = cellToRoundedInt(elemData{k, 3});
        end
        if any(elemMat == row)
            updateInfo('This material is still used by members. Please reassign those members first.');
            return;
        end

        materialData(row, :) = [];
        for k = 1:size(elemData, 1)
            matIdx = cellToRoundedInt(elemData{k, 3});
            if ~isnan(matIdx) && matIdx > row
                elemData{k, 3} = matIdx - 1;
            end
        end

        set(ui.materialsTable, 'Data', materialData);
        set(ui.elementsTable, 'Data', elemData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Material %d removed.', row));
    end

    function onAddAngleRow(~, ~)
        angleData = getTableDataAsCell(ui.anglesTable);
        angleData(end + 1, :) = {'', '', ''};
        set(ui.anglesTable, 'Data', angleData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo('New angle constraint added. Please enter Member 1, Member 2, and the angle.');
    end

    function onDeleteAngleRow(~, ~)
        row = selectedRowFor('angles');
        if isempty(row)
            updateInfo('Please select a row in the angle table first before deleting.');
            return;
        end
        angleData = getTableDataAsCell(ui.anglesTable);
        angleData(row, :) = [];
        set(ui.anglesTable, 'Data', angleData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Angle constraint %d removed.', row));
    end

    function onAddLoadRow(~, ~)
        loadData = getTableDataAsCell(ui.loadsTable);
        loadData(end + 1, :) = {'', '', '', '', '', ''};
        set(ui.loadsTable, 'Data', loadData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo('New load row added. Enter X, Y, and either Fx/Fy or F/angle, or place a load point in the plot.');
    end
    function onDeleteLoadRow(~, ~)
        row = selectedRowFor('loads');
        if isempty(row)
            updateInfo('Please select a row in the load table first before deleting.');
            return;
        end

        loadData = getTableDataAsCell(ui.loadsTable);
        loadData(row, :) = [];
        set(ui.loadsTable, 'Data', loadData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Load %d removed.', row));
    end

    function onAddVariableRow(~, ~)
        varData = getTableDataAsCell(ui.variablesTable);
        varData(end + 1, :) = {'', ''};
        set(ui.variablesTable, 'Data', varData);
        state.results = [];
        state.symbolicResults = [];
        refreshAll();
        updateInfo('New preview variable added. Enter for example a and optionally a numeric value.');
    end

    function onDeleteVariableRow(~, ~)
        row = selectedRowFor('variables');
        if isempty(row)
            updateInfo('Please select a row in the variables table first before deleting.');
            return;
        end
        varData = getTableDataAsCell(ui.variablesTable);
        varData(row, :) = [];
        set(ui.variablesTable, 'Data', varData);
        state.results = [];
        state.symbolicResults = [];
        refreshAll();
        updateInfo(sprintf('Variable %d removed.', row));
    end

    function onAnyModelEdit(~, ~)
        clearResultsAfterGeometryChange();
        refreshAll();
    end

    function onLoadTableEdited(~, evt)
        loadData = getTableDataAsCell(ui.loadsTable);
        if ~isempty(evt.Indices)
            row = evt.Indices(1);
            col = evt.Indices(2);
            if row <= size(loadData, 1)
                if any(col == [3, 4]) && any(isFilledCellValue(loadData(row, 3:4)))
                    loadData(row, 5:6) = {'', ''};
                elseif any(col == [5, 6]) && any(isFilledCellValue(loadData(row, 5:6)))
                    loadData(row, 3:4) = {'', ''};
                end
                set(ui.loadsTable, 'Data', loadData);
            end
        end
        clearResultsAfterGeometryChange();
        refreshAll();
    end

    function synchronizeNodeTables()
        nodeCount = size(getTableDataAsCell(ui.nodesTable), 1);
        supportData = resizeSupportTable(getTableDataAsCell(ui.supportsTable), nodeCount);

        set(ui.supportsTable, 'Data', supportData);
    end

    function onTableSelection(tableName, evt)
        if isempty(evt.Indices)
            state.selection.table = '';
            state.selection.rows = [];
        else
            state.selection.table = tableName;
            state.selection.rows = unique(evt.Indices(:, 1));
        end
    end

    function row = selectedRowFor(tableName)
        if strcmp(state.selection.table, tableName) && ~isempty(state.selection.rows)
            row = state.selection.rows(1);
        else
            row = [];
        end
    end

    function onAxesClick(~, ~)
        cp = get(ui.axes, 'CurrentPoint');
        xy = cp(1, 1:2);

        switch state.mode
            case 'addnode'
                addNodeByClick(xy);
            case 'addload'
                createLoadAtPoint(xy);
            otherwise
                % In the other modes, a background click does nothing.
        end
    end

    function addNodeByClick(xy)
        nodeData = getTableDataAsCell(ui.nodesTable);
        supportData = getTableDataAsCell(ui.supportsTable);

        nodeData(end + 1, :) = {formatNumber(xy(1)), formatNumber(xy(2))};
        supportData(end + 1, :) = {'No Support', '0'};

        set(ui.nodesTable, 'Data', nodeData);
        set(ui.supportsTable, 'Data', supportData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Node %d bei (%.4g, %.4g) added.', size(nodeData, 1), xy(1), xy(2)));
    end

    function onNodeClicked(idx)
        [model, ~, ~] = getDisplayModel();
        if idx > size(model.nodes, 1)
            return;
        end
        state.highlightElement = [];
        refreshPlot();

        switch state.mode
            case 'addelement'
                handleElementCreationClick(idx);
                return;
            case 'addload'
                createLoadAtPoint(model.nodes(idx, :));
                return;
            case 'normal'
                if idx <= model.originalNodeCount
                    state.dragNode = idx;
                    state.dragMoved = false;
                end
        end

        if isempty(state.results)
            if isempty(state.symbolicResults)
                updateInfo(nodeInfoText(model, idx, []));
            else
                updateInfo(nodeInfoText(model, idx, state.symbolicResults));
            end
        else
            updateInfo(nodeInfoText(model, idx, state.results));
        end
    end

    function handleElementCreationClick(idx)
        if isempty(state.pendingElementStart)
            state.pendingElementStart = idx;
            refreshPlot();
            updateInfo(sprintf('Start node %d selected. Now click the second node.', idx));
            return;
        end

        startNode = state.pendingElementStart;
        if startNode == idx
            updateInfo('Please select two different nodes for one member.');
            return;
        end

        elemData = getTableDataAsCell(ui.elementsTable);
        elemData(end + 1, :) = {startNode, idx, 1};
        set(ui.elementsTable, 'Data', elemData);
        state.pendingElementStart = [];

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Member between node %d and node %d added.', startNode, idx));
    end

    function onElementClicked(idx)
        [model, ~, isReady] = getDisplayModel();
        if idx > size(model.elements, 1)
            return;
        end
        state.highlightElement = idx;
        refreshPlot();

        if strcmp(state.mode, 'addload')
            cp = get(ui.axes, 'CurrentPoint');
            point = projectPointToElement(cp(1, 1:2), model, idx);
            createLoadAtPoint(point);
            return;
        end

        if (isempty(state.results) && isempty(state.symbolicResults)) || ~isReady
            e = model.elements(idx, :);
            infoText = sprintf('Member %d connects node %d and node %d (cross section %d).', idx, e(1), e(2), e(3));
            if isfield(model, 'materialDefs') && e(3) <= size(model.materialDefs, 1)
                infoText = sprintf('%s\nType: %s', infoText, model.materialDefs{e(3), 1});
            end
            updateInfo(infoText);
            return;
        end

        if ~isempty(state.results)
            resultData = state.results;
            isSymbolic = false;
        else
            resultData = state.symbolicResults;
            isSymbolic = true;
        end

        force = resultData.axialForces(idx);
        stress = resultData.stresses(idx);
        lengthVal = resultData.lengths(idx);
        areaVal = resultData.areas(idx);
        label = 'Zug';
        if ~isSymbolic
            if force < 0
                label = 'Druck';
            elseif abs(force) < max(abs(resultData.axialForces)) * 1e-9 + 1e-12
                label = 'Nullstab';
            end
        end

        sectionLabel = '';
        if isfield(model, 'materialDefs') && idx <= size(model.elements, 1)
            matIdx = model.elements(idx, 3);
            if matIdx <= size(model.materialDefs, 1)
                sectionLabel = sprintf('\nCross section = %s', model.materialDefs{matIdx, 1});
            end
        end

        if isSymbolic
            updateInfo(getCachedSymbolicMemberInfo(idx, force, stress, lengthVal, areaVal, label, sectionLabel));
        else
            updateInfo(sprintf(['Member %d\nAxial Force N = %.6g %s\nStress sigma = %.6g %s\n' ...
                'Length = %.6g %s\nArea A = %.6g %s\nType = %s%s'], ...
                idx, force, state.units.force, stress, state.units.stress, ...
                lengthVal, state.units.length, areaVal, state.units.area, label, sectionLabel));
        end
    end

    function point = projectPointToElement(xy, model, idx)
        e = model.elements(idx, :);
        p1 = model.nodes(e(1), :);
        p2 = model.nodes(e(2), :);
        d = p2 - p1;
        denom = dot(d, d);
        if denom < eps
            point = p1;
            return;
        end
        t = dot(xy - p1, d) / denom;
        t = max(0, min(1, t));
        point = p1 + t * d;
    end

    function createLoadAtPoint(xy)
        [displayModel, displayErr, ~] = getDisplayModel();
        [snappedPoint, isOnStructure] = snapPointToStructure(xy, displayModel);
        if ~isOnStructure
            if isempty(displayErr)
                updateInfo('The load must lie on a visible node or member.');
            else
                updateInfo(sprintf('The load must lie on a visible node or member.\nCurrent note: %s', displayErr));
            end
            return;
        end

        loadData = getTableDataAsCell(ui.loadsTable);
        loadData(end + 1, :) = {formatNumber(snappedPoint(1)), formatNumber(snappedPoint(2)), '', '', '', ''};
        set(ui.loadsTable, 'Data', loadData);

        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf(['Load point %d added at (%.4g, %.4g).\n' ...
            'Enter either Fx/Fy or F and phi for this row in the load table.'], ...
            size(loadData, 1), snappedPoint(1), snappedPoint(2)));
    end
    function onLoadPointClicked(idx)
        loadData = getTableDataAsCell(ui.loadsTable);
        if idx > size(loadData, 1)
            return;
        end
        state.highlightElement = [];
        refreshPlot();

        row = loadData(idx, :);
        x = cellToDouble(row{1});
        y = cellToDouble(row{2});
        fx = row{3};
        fy = row{4};
        mag = row{5};
        ang = row{6};

        if strcmp(state.mode, 'addload')
            createLoadAtPoint([x, y]);
            return;
        end

        inputMode = detectLoadInputMode(row);
        updateInfo(sprintf('load point %d\nX = %s %s\nY = %s %s\n%s', ...
            idx, formatAnyEntry(row{1}), state.units.length, formatAnyEntry(row{2}), state.units.length, ...
            loadDescriptionText(fx, fy, mag, ang, inputMode)));
    end

    function [snappedPoint, ok] = snapPointToStructure(xy, model)
        snappedPoint = xy;
        ok = false;

        if isempty(model.nodes)
            return;
        end

        span = max(currentSpan(), 1);
        clickTol = max(geometryTolerance(model.nodes), 0.02 * span);

        nodeDistances = sqrt(sum((model.nodes - xy) .^ 2, 2));
        [bestNodeDistance, bestNodeIdx] = min(nodeDistances);
        if ~isempty(bestNodeDistance) && bestNodeDistance <= clickTol
            snappedPoint = model.nodes(bestNodeIdx, :);
            ok = true;
            return;
        end

        bestDistance = inf;
        for eIdx = 1:size(model.elements, 1)
            e = model.elements(eIdx, :);
            p1 = model.nodes(e(1), :);
            p2 = model.nodes(e(2), :);
            [distance, ~, proj] = pointToSegmentDistance(xy, p1, p2);
            if distance < bestDistance
                bestDistance = distance;
                snappedPoint = proj;
            end
        end

        ok = bestDistance <= clickTol;
    end

    function modeName = detectLoadInputMode(row)
        row = getCellMatrix(row, 6);
        hasComp = any(isFilledCellValue(row(1, 3:4)));
        hasPolar = any(isFilledCellValue(row(1, 5:6)));
        if hasComp && ~hasPolar
            modeName = 'components';
        elseif hasPolar && ~hasComp
            modeName = 'polar';
        elseif hasComp && hasPolar
            modeName = 'mixed';
        else
            modeName = 'empty';
        end
    end

    function textOut = loadDescriptionText(fx, fy, mag, ang, inputMode)
        switch inputMode
            case 'components'
                textOut = sprintf('Fx = %s %s\nFy = %s %s', ...
                    formatAnyEntry(fx), state.units.force, formatAnyEntry(fy), state.units.force);
            case 'polar'
                textOut = sprintf('F = %s %s\nphi = %s deg', ...
                    formatAnyEntry(mag), state.units.force, formatAnyEntry(ang));
            case 'mixed'
                textOut = sprintf(['Fx = %s %s\nFy = %s %s\nF = %s %s\nphi = %s deg\n' ...
                    'Note: Please use only one of the two input modes.'], ...
                    formatAnyEntry(fx), state.units.force, formatAnyEntry(fy), state.units.force, ...
                    formatAnyEntry(mag), state.units.force, formatAnyEntry(ang));
            otherwise
                textOut = 'No load magnitude entered yet.';
        end
    end

    function textOut = nodeInfoText(model, idx, results)
        if idx <= model.originalNodeCount
            nodeType = 'Original node';
        else
            nodeType = 'Automatically inserted load point';
        end

        if isfield(model, 'symbolicNodes') && ~isempty(model.symbolicNodes) && idx <= size(model.symbolicNodes, 1)
            textOut = sprintf('Node %d (%s)\nX = %s %s\nY = %s %s', ...
                idx, nodeType, char(simplify(model.symbolicNodes(idx, 1))), state.units.length, ...
                char(simplify(model.symbolicNodes(idx, 2))), state.units.length);
        elseif isa(model.nodes, 'sym')
            textOut = sprintf('Node %d (%s)\nX = %s %s\nY = %s %s', ...
                idx, nodeType, char(simplify(model.nodes(idx, 1))), state.units.length, ...
                char(simplify(model.nodes(idx, 2))), state.units.length);
        else
            textOut = sprintf('Node %d (%s)\nX = %.6g %s\nY = %.6g %s', ...
                idx, nodeType, model.nodes(idx, 1), state.units.length, model.nodes(idx, 2), state.units.length);
        end
        if ~isempty(results)
            hasDisp = isfield(results, 'displacements') && ~isempty(results.displacements) && size(results.displacements, 1) >= idx;
            if hasDisp
                u = results.displacements(idx, :);
                if isa(u, 'sym')
                    textOut = sprintf('%s\nux = %s %s\nuy = %s %s', textOut, ...
                        formatSymbolicText(u(1)), state.units.length, formatSymbolicText(u(2)), state.units.length);
                else
                    textOut = sprintf('%s\nux = %.6g %s\nuy = %.6g %s', textOut, u(1), state.units.length, u(2), state.units.length);
                end
            elseif isfield(results, 'solverMode') && strcmp(results.solverMode, 'joint-equilibrium')
                textOut = sprintf('%s\nux/uy not computed in symbolic fast mode.', textOut);
            end
        end
    end

    function onResultViewChanged(src, ~)
        if get(src, 'Value') == 1
            state.resultView = 'members';
        else
            state.resultView = 'reactions';
        end
        state.highlightElement = [];
        refreshResultsTable();
        refreshPlot();
    end

    function onSymbolicFormatChanged(src, ~)
        if get(src, 'Value') == 1
            state.symbolicFormat = 'trig';
        else
            state.symbolicFormat = 'exact';
        end
        refreshResultsTable();
        refreshCurrentSymbolicInfo();
    end

    function refreshCurrentSymbolicInfo()
        if isempty(state.symbolicResults)
            return;
        end
        if strcmp(state.selection.table, 'results') && ~isempty(state.selection.rows)
            row = state.selection.rows(1);
            if strcmp(state.resultView, 'members')
                previousMode = state.mode;
                state.mode = 'normal';
                onElementClicked(row);
                state.mode = previousMode;
            else
                if row <= numel(state.symbolicResults.reactionNodeIds)
                    onReactionClicked(state.symbolicResults.reactionNodeIds(row));
                else
                    updateInfo(getCachedSymbolicSummary());
                end
            end
        elseif ~isempty(state.symbolicModel)
            updateInfo(getCachedSymbolicSummary());
        end
    end

    function onResultsTableSelection(~, evt)
        onTableSelection('results', evt);
        if isempty(evt.Indices) || (isempty(state.results) && isempty(state.symbolicResults))
            return;
        end
        row = evt.Indices(1, 1);
        if strcmp(state.resultView, 'members')
            state.highlightElement = row;
            refreshPlot();
            previousMode = state.mode;
            state.mode = 'normal';
            onElementClicked(row);
            state.mode = previousMode;
        else
            state.highlightElement = [];
            refreshPlot();
            if ~isempty(state.results)
                reactionNodeIds = state.results.reactionNodeIds;
            else
                reactionNodeIds = state.symbolicResults.reactionNodeIds;
            end
            onReactionClicked(reactionNodeIds(row));
        end
    end

    function onReactionClicked(nodeIdx)
        [model, ~, ~] = getDisplayModel();
        if ~isempty(state.results)
            resultData = state.results;
            isSymbolic = false;
        elseif ~isempty(state.symbolicResults)
            resultData = state.symbolicResults;
            isSymbolic = true;
        else
            return;
        end
        if nodeIdx > size(resultData.reactions, 1)
            return;
        end
        r = resultData.reactions(nodeIdx, :);
        if isSymbolic
            textOut = getCachedSymbolicReactionInfo(nodeIdx, r);
        else
            textOut = sprintf('Support reaction at node %d\nRx = %.6g %s\nRy = %.6g %s', ...
                nodeIdx, r(1), state.units.force, r(2), state.units.force);
        end
        if all(~model.supports(nodeIdx, :))
            textOut = sprintf('%s\nNote: This node is not supported.', textOut);
        end
        updateInfo(textOut);
    end

    function onWindowMouseMove(~, ~)
        if isempty(state.dragNode) || ~strcmp(state.mode, 'normal')
            return;
        end

        cp = get(ui.axes, 'CurrentPoint');
        xy = cp(1, 1:2);
        nodeData = getTableDataAsCell(ui.nodesTable);
        if state.dragNode > size(nodeData, 1)
            state.dragNode = [];
            return;
        end

        nodeData(state.dragNode, :) = {formatNumber(xy(1)), formatNumber(xy(2))};
        set(ui.nodesTable, 'Data', nodeData);
        state.dragMoved = true;
        clearResultsAfterGeometryChange();
        refreshAll();
        updateInfo(sprintf('Node %d moved auf (%.4g, %.4g).', state.dragNode, xy(1), xy(2)));
    end

    function onWindowMouseUp(~, ~)
        state.dragNode = [];
        state.dragMoved = false;
    end

    function clearResultsAfterGeometryChange()
        state.results = [];
        state.symbolicResults = [];
        state.symbolicModel = [];
        state.symbolicVariableDefs = struct('names', {{}}, 'previewValues', []);
        state.symbolicAngleVariableNames = {};
        state.symbolicDisplayCache = emptySymbolicDisplayCache();
        state.highlightElement = [];
    end

    function refreshResultsTable()
        if isempty(state.results) && isempty(state.symbolicResults)
            set(ui.resultsTable, 'Data', cell(0, 4));
            if strcmp(state.resultView, 'members')
                set(ui.resultsTable, 'ColumnName', ...
                    {'Member', sprintf('N [%s]', state.units.force), sprintf('sigma [%s]', state.units.stress), sprintf('Length [%s]', state.units.length)});
            else
                set(ui.resultsTable, 'ColumnName', ...
                    {'Node', sprintf('Rx [%s]', state.units.force), sprintf('Ry [%s]', state.units.force), 'Supported'});
            end
            updateRowNames();
            return;
        end

        resultData = state.results;
        isSymbolic = false;
        if isempty(resultData)
            resultData = state.symbolicResults;
            isSymbolic = true;
        end

        if isSymbolic
            rows = getCachedSymbolicRows(state.resultView, state.symbolicFormat, resultData);
            if strcmp(state.resultView, 'members')
                set(ui.resultsTable, 'ColumnName', ...
                    {'Member', sprintf('N [%s]', state.units.force), sprintf('sigma [%s]', state.units.stress), sprintf('Length [%s]', state.units.length)});
            else
                set(ui.resultsTable, 'ColumnName', ...
                    {'Node', sprintf('Rx [%s]', state.units.force), sprintf('Ry [%s]', state.units.force), 'Supported'});
            end
            set(ui.resultsTable, 'Data', rows);
            updateRowNames();
            return;
        end

        if strcmp(state.resultView, 'members')
            rows = cell(size(resultData.axialForces, 1), 4);
            for e = 1:size(rows, 1)
                rows{e, 1} = e;
                rows{e, 2} = formatResultCell(resultData.axialForces(e), isSymbolic);
                rows{e, 3} = formatResultCell(resultData.stresses(e), isSymbolic);
                rows{e, 4} = formatResultCell(resultData.lengths(e), isSymbolic);
            end
            set(ui.resultsTable, 'ColumnName', ...
                {'Member', sprintf('N [%s]', state.units.force), sprintf('sigma [%s]', state.units.stress), sprintf('Length [%s]', state.units.length)});
        else
            nodeIds = resultData.reactionNodeIds;
            rows = cell(numel(nodeIds), 4);
            for k = 1:numel(nodeIds)
                nodeIdx = nodeIds(k);
                rows{k, 1} = nodeIdx;
                rows{k, 2} = formatResultCell(resultData.reactions(nodeIdx, 1), isSymbolic);
                rows{k, 3} = formatResultCell(resultData.reactions(nodeIdx, 2), isSymbolic);
                rows{k, 4} = any(resultData.model.supports(nodeIdx, :));
            end
            set(ui.resultsTable, 'ColumnName', ...
                {'Node', sprintf('Rx [%s]', state.units.force), sprintf('Ry [%s]', state.units.force), 'Supported'});
        end
        set(ui.resultsTable, 'Data', rows);
        updateRowNames();
    end

    function rows = getCachedSymbolicRows(viewName, formatMode, resultData)
        if ~isfield(state.symbolicDisplayCache, formatMode)
            state.symbolicDisplayCache = emptySymbolicDisplayCache();
        end
        if isfield(state.symbolicDisplayCache.(formatMode), viewName) && ...
                ~isempty(state.symbolicDisplayCache.(formatMode).(viewName))
            rows = state.symbolicDisplayCache.(formatMode).(viewName);
            return;
        end

        rows = buildSymbolicRowsForView(viewName, resultData, formatMode);
        state.symbolicDisplayCache.(formatMode).(viewName) = rows;
    end

    function primeSymbolicDisplayCaches()
        if isempty(state.symbolicResults)
            return;
        end
        formats = {'trig', 'exact'};
        views = {'members', 'reactions'};
        for f = 1:numel(formats)
            for v = 1:numel(views)
                drawnow limitrate;
                throwIfComputeCancelled();
                if isempty(state.symbolicDisplayCache.(formats{f}).(views{v}))
                    state.symbolicDisplayCache.(formats{f}).(views{v}) = ...
                        buildSymbolicRowsForView(views{v}, state.symbolicResults, formats{f});
                end
            end
            state.symbolicDisplayCache.(formats{f}).summary = ...
                summaryTextSymbolic(state.symbolicModel, state.symbolicResults, state.symbolicVariableDefs, formats{f});
        end
    end

    function txt = getCachedSymbolicSummary()
        formatMode = state.symbolicFormat;
        txt = state.symbolicDisplayCache.(formatMode).summary;
        if isempty(txt)
            txt = summaryTextSymbolic(state.symbolicModel, state.symbolicResults, state.symbolicVariableDefs, formatMode);
            state.symbolicDisplayCache.(formatMode).summary = txt;
        end
    end

    function tf = shouldPrimeSymbolicDisplayCaches()
        tf = ~state.symbolicFastDisplay;
    end

    function textOut = getCachedSymbolicMemberInfo(idx, force, stress, lengthVal, areaVal, label, sectionLabel)
        formatMode = state.symbolicFormat;
        infoCache = state.symbolicDisplayCache.(formatMode).memberInfo;
        if numel(infoCache) >= idx && ~isempty(infoCache{idx})
            textOut = infoCache{idx};
            return;
        end
        textOut = sprintf(['Member %d\nAxial Force N = %s %s\nStress sigma = %s %s\n' ...
            'Length = %s %s\nArea A = %s %s\nType = %s%s'], ...
            idx, formatSymbolicText(force, 'detail', formatMode), state.units.force, ...
            formatSymbolicText(stress, 'detail', formatMode), state.units.stress, ...
            formatSymbolicText(lengthVal, 'detail', formatMode), state.units.length, ...
            formatSymbolicText(areaVal, 'detail', formatMode), state.units.area, label, sectionLabel);
        if numel(infoCache) < idx
            infoCache{idx} = [];
        end
        infoCache{idx} = textOut;
        state.symbolicDisplayCache.(formatMode).memberInfo = infoCache;
    end

    function textOut = getCachedSymbolicReactionInfo(nodeIdx, reactionVec)
        formatMode = state.symbolicFormat;
        infoCache = state.symbolicDisplayCache.(formatMode).reactionInfo;
        if numel(infoCache) >= nodeIdx && ~isempty(infoCache{nodeIdx})
            textOut = infoCache{nodeIdx};
            return;
        end
        textOut = sprintf('Support reaction at node %d\nRx = %s %s\nRy = %s %s', ...
            nodeIdx, formatSymbolicText(reactionVec(1), 'reaction-detail', formatMode), state.units.force, ...
            formatSymbolicText(reactionVec(2), 'reaction-detail', formatMode), state.units.force);
        if numel(infoCache) < nodeIdx
            infoCache{nodeIdx} = [];
        end
        infoCache{nodeIdx} = textOut;
        state.symbolicDisplayCache.(formatMode).reactionInfo = infoCache;
    end

    function rows = buildSymbolicRowsForView(viewName, resultData, formatMode)
        if strcmp(viewName, 'members')
            rows = cell(size(resultData.axialForces, 1), 4);
            for e = 1:size(rows, 1)
                if mod(e, 5) == 0
                    drawnow limitrate;
                    throwIfComputeCancelled();
                end
                rows{e, 1} = e;
                rows{e, 2} = formatSymbolicText(resultData.axialForces(e), 'table', formatMode);
                rows{e, 3} = formatSymbolicText(resultData.stresses(e), 'table', formatMode);
                rows{e, 4} = formatSymbolicText(resultData.lengths(e), 'table', formatMode);
            end
        else
            nodeIds = resultData.reactionNodeIds;
            rows = cell(numel(nodeIds), 4);
            for k = 1:numel(nodeIds)
                if mod(k, 3) == 0
                    drawnow limitrate;
                    throwIfComputeCancelled();
                end
                nodeIdx = nodeIds(k);
                rows{k, 1} = nodeIdx;
                rows{k, 2} = formatSymbolicText(resultData.reactions(nodeIdx, 1), 'reaction-table', formatMode);
                rows{k, 3} = formatSymbolicText(resultData.reactions(nodeIdx, 2), 'reaction-table', formatMode);
                rows{k, 4} = any(resultData.model.supports(nodeIdx, :));
            end
        end
    end

    function value = formatResultCell(entry, isSymbolic)
        if isSymbolic || isa(entry, 'sym')
            value = formatSymbolicText(entry);
        else
            value = entry;
        end
    end

    function txt = formatSymbolicText(expr, usage, formatMode)
        if nargin < 2 || isempty(usage)
            usage = 'detail';
        end
        if nargin < 3 || isempty(formatMode)
            formatMode = state.symbolicFormat;
        end
        try
            expr = applyAngleVariableDisplaySubstitutions(expr);
            [simplifySteps, useLightFormatting] = symbolicFormattingOptions(usage);
            if strcmp(formatMode, 'trig')
                [exprForDisplay, tempAngleVars, originalAngleVars] = applyDisplayAngleAssumptions(expr);
                formatted = rewrite(exprForDisplay, 'sincos');
                if ~useLightFormatting
                    formatted = simplify(formatted, 'Steps', min(simplifySteps, 20));
                end
                if shouldApplyAngleConstraintDisplaySubstitutions(usage)
                    formatted = applyAngleConstraintDisplaySubstitutions(formatted);
                    formatted = applyAngleVariableDisplaySubstitutions(formatted);
                end
                if ~isempty(tempAngleVars)
                    formatted = subs(formatted, tempAngleVars, originalAngleVars);
                    formatted = rewrite(formatted, 'sincos');
                end
                if ~useLightFormatting
                    formatted = simplify(formatted, 'Steps', min(simplifySteps, 20));
                end
            else
                if useLightFormatting
                    formatted = expr;
                else
                    expr = simplify(expr, 'IgnoreAnalyticConstraints', true, 'Steps', simplifySteps);
                    formatted = simplify(expr, 'IgnoreAnalyticConstraints', true, 'Steps', simplifySteps);
                end
                if shouldApplyAngleConstraintDisplaySubstitutions(usage)
                    formatted = applyAngleConstraintDisplaySubstitutions(formatted);
                    formatted = applyAngleVariableDisplaySubstitutions(formatted);
                    if ~useLightFormatting
                        formatted = simplify(formatted, 'IgnoreAnalyticConstraints', true, 'Steps', min(simplifySteps, 20));
                    end
                end
            end
            txt = postProcessSymbolicDisplayText(char(formatted), usage);
        catch
            txt = postProcessSymbolicDisplayText(char(expr), usage);
        end
    end

    function tf = shouldApplyAngleConstraintDisplaySubstitutions(usage)
        usageLower = lower(string(usage));
        tf = ~startsWith(usageLower, "reaction");
    end

    function exprOut = applyAngleVariableDisplaySubstitutions(exprIn)
        exprOut = exprIn;
        if isempty(state.symbolicAngleVariableNames)
            return;
        end
        for idx = 1:numel(state.symbolicAngleVariableNames)
            angSym = sym(state.symbolicAngleVariableNames{idx});
            for factor = 12:-2:2
                exprOut = subs(exprOut, sym(factor) * sym(pi) / 180 * angSym, sym(factor) * angSym);
                exprOut = subs(exprOut, angSym * sym(factor) * sym(pi) / 180, sym(factor) * angSym);
            end
            exprOut = subs(exprOut, sym(pi) / 180 * angSym, angSym);
            exprOut = subs(exprOut, angSym * sym(pi) / 180, angSym);
        end
    end

    function [simplifySteps, useLightFormatting] = symbolicFormattingOptions(usage)
        if strcmp(usage, 'table')
            if state.symbolicFastDisplay
                simplifySteps = 0;
                useLightFormatting = true;
            else
                simplifySteps = 12;
                useLightFormatting = false;
            end
        else
            if state.symbolicFastDisplay
                simplifySteps = 20;
                useLightFormatting = false;
            else
                simplifySteps = 100;
                useLightFormatting = false;
            end
        end
    end

    function tf = shouldUseFastSymbolicDisplay(model, results)
        nElem = size(model.elements, 1);
        nLoads = size(model.loadPoints, 1);
        solverMode = '';
        if isfield(results, 'solverMode')
            solverMode = results.solverMode;
        end
        tf = nElem >= 12 || nLoads >= 3 || strcmp(solverMode, 'symbolic-fem');
    end

    function [exprOut, tempVars, originalVars] = applyDisplayAngleAssumptions(exprIn)
        exprOut = exprIn;
        tempVars = sym.empty(1, 0);
        originalVars = sym.empty(1, 0);
        if isempty(state.symbolicAngleVariableNames)
            return;
        end
        for idx = 1:numel(state.symbolicAngleVariableNames)
            originalVar = sym(state.symbolicAngleVariableNames{idx});
            tempVar = sym(sprintf('__angdisp_%d__', idx), 'real');
            assumeAlso(tempVar > 0);
            assumeAlso(tempVar < pi/2);
            exprOut = subs(exprOut, originalVar, tempVar);
            tempVars(end + 1) = tempVar; %#ok<AGROW>
            originalVars(end + 1) = originalVar; %#ok<AGROW>
        end
    end

    function cache = emptySymbolicDisplayCache()
        cache = struct( ...
            'trig', struct('members', [], 'reactions', [], 'memberInfo', {{}}, 'reactionInfo', {{}}, 'summary', ''), ...
            'exact', struct('members', [], 'reactions', [], 'memberInfo', {{}}, 'reactionInfo', {{}}, 'summary', ''));
    end

    function txt = postProcessSymbolicDisplayText(txt, usage)
        if nargin < 2
            usage = 'detail';
        end
        txt = regexprep(txt, '([A-Za-z0-9_]+)\^\(1/2\)', 'sqrt($1)');
        txt = regexprep(txt, '\(([^()]+)\)\^\(1/2\)', 'sqrt($1)');
        txt = regexprep(txt, 'sqrt\(([A-Za-z0-9_]+)\)\*([A-Za-z]\w*)', '$2*sqrt($1)');
        txt = regexprep(txt, '(^|[+\-])([0-9]+)\*sqrt\(([A-Za-z0-9_]+)\)\*([A-Za-z]\w*)', '$1$2*$4*sqrt($3)');
        if shouldApplyAngleConstraintDisplaySubstitutions(usage)
            txt = applyAngleConstantDisplayTextSubstitutions(txt);
            txt = applyAngleNameTextRewrites(txt);
        end
        txt = strrep(txt, '*1/', '/');
        txt = strrep(txt, ')/1/', ')/');
        txt = regexprep(txt, '\(([^()]+)\)\^\(-1\)', '1/($1)');
        txt = regexprep(txt, '\(1/cos\(([^()]+)\)\^2\)\^\(1/2\)', '1/cos($1)');
    end

    function txt = applyAngleNameTextRewrites(txtIn)
        txt = txtIn;
        for idx = 1:numel(state.symbolicAngleVariableNames)
            angName = state.symbolicAngleVariableNames{idx};
            trigProd = ['cos(' angName ')/sin(' angName ')*1/cos(' angName ')'];
            trigProdInv = ['1/cos(' angName ')*cos(' angName ')/sin(' angName ')'];
            cotProd = ['cot(' angName ')*1/cos(' angName ')'];
            cotProdInv = ['1/cos(' angName ')*cot(' angName ')'];
            trigProdParen = ['(cos(' angName ')/sin(' angName '))*(1/cos(' angName '))'];
            trigProdParenInv = ['(1/cos(' angName '))*(cos(' angName ')/sin(' angName '))'];
            cotProdParen = ['(cot(' angName '))*(1/cos(' angName '))'];
            cotProdParenInv = ['(1/cos(' angName '))*(cot(' angName '))'];
            cotOnlyPattern = ['(?<![A-Za-z0-9_])cot\(' regexptranslate('escape', angName) '\)(?![A-Za-z0-9_])'];
            txt = strrep(txt, trigProd, ['1/sin(' angName ')']);
            txt = strrep(txt, trigProdInv, ['1/sin(' angName ')']);
            txt = strrep(txt, cotProd, ['1/sin(' angName ')']);
            txt = strrep(txt, cotProdInv, ['1/sin(' angName ')']);
            txt = strrep(txt, trigProdParen, ['1/sin(' angName ')']);
            txt = strrep(txt, trigProdParenInv, ['1/sin(' angName ')']);
            txt = strrep(txt, cotProdParen, ['1/sin(' angName ')']);
            txt = strrep(txt, cotProdParenInv, ['1/sin(' angName ')']);
            txt = regexprep(txt, cotOnlyPattern, ['cos(' angName ')/sin(' angName ')']);
        end
    end

    function [refComponent, normalComponent, lengthComponent, thetaText, ok] = angleDisplayGeometry(model, constraintIdx, textUsage)
        if nargin < 3 || isempty(textUsage)
            textUsage = 'detail';
        end
        refComponent = [];
        normalComponent = [];
        lengthComponent = [];
        thetaText = '';
        ok = false;

        [commonNode, refNode, targetNode] = sharedNodesForAngleConstraint(model.elements, ...
            model.angleConstraints(constraintIdx).elem1, model.angleConstraints(constraintIdx).elem2, constraintIdx);
        theta = model.angleConstraints(constraintIdx).angle;
        thetaText = postProcessSymbolicDisplayText(char(applyAngleVariableDisplaySubstitutions(sym(theta))), textUsage);

        pCommon = model.nodes(commonNode, :);
        pRef = model.nodes(refNode, :);
        pTarget = model.nodes(targetNode, :);
        uRef = simplify(pRef - pCommon);
        vTarget = simplify(pTarget - pCommon);
        refLength = simplify(sqrt(sum(uRef.^2)));
        if isAlways(refLength == 0, 'Unknown', 'false')
            return;
        end

        normalBase = [-uRef(2), uRef(1)];
        refComponent = simplify((vTarget * uRef.') / refLength);
        normalComponent = simplify((vTarget * normalBase.') / refLength);
        lengthComponent = simplify(sqrt(sum(vTarget.^2)));
        if isAlways(lengthComponent == 0, 'Unknown', 'false')
            return;
        end
        ok = true;
    end
    function txt = applyAngleConstantDisplayTextSubstitutions(txtIn)
        txt = txtIn;
        if isempty(state.symbolicModel) || ~isfield(state.symbolicModel, 'angleConstraints') || isempty(state.symbolicModel.angleConstraints)
            return;
        end
        model = state.symbolicModel;
        for k = 1:numel(model.angleConstraints)
            try
                [refComponent, normalComponent, lengthComponent, thetaText, ok] = angleDisplayGeometry(model, k, 'reaction-detail');
                if ~ok
                    continue;
                end
                replacements = {
                    simplify(lengthComponent / normalComponent), ['1/sin(' thetaText ')']
                    simplify(lengthComponent / refComponent), ['1/cos(' thetaText ')']
                    simplify(normalComponent / lengthComponent), ['sin(' thetaText ')']
                    simplify(refComponent / lengthComponent), ['cos(' thetaText ')']
                    simplify(normalComponent / refComponent), ['tan(' thetaText ')']
                    simplify(refComponent / normalComponent), ['cot(' thetaText ')']
                    };

                for repIdx = 1:size(replacements, 1)
                    ratioExpr = simplify(replacements{repIdx, 1});
                    if ~isPureNumericSymbolic(ratioExpr)
                        continue;
                    end
                    ratioText = postProcessSymbolicDisplayText(char(ratioExpr), 'reaction-detail');
                    if isempty(ratioText)
                        continue;
                    end
                    txt = strrep(txt, ratioText, replacements{repIdx, 2});
                    txt = strrep(txt, ['(' ratioText ')'], replacements{repIdx, 2});
                end
            catch
            end
        end
    end
    function progressHandle = beginComputeProgress()
        progressHandle = struct('waitbar', [], 'previousPointer', get(ui.fig, 'Pointer'));
        try
            state.computeCancelRequested = false;
            set(ui.fig, 'Pointer', 'watch');
            set(ui.computeButton, 'Enable', 'off');
            drawnow;
            if usejava('desktop')
                progressHandle.waitbar = waitbar(0.05, 'Computation starts...', ...
                    'Name', 'Truss Calculator', 'CreateCancelBtn', @onComputeCancelRequested);
            end
        catch
        end
    end

    function updateComputeProgress(progressHandle, fraction, message)
        try
            if isfield(progressHandle, 'waitbar') && ~isempty(progressHandle.waitbar) && isgraphics(progressHandle.waitbar)
                waitbar(max(0, min(1, fraction)), progressHandle.waitbar, message);
            end
            if state.computeCancelRequested
                set(ui.statusText, 'String', 'Mode: Cancellation requested...');
            else
                set(ui.statusText, 'String', 'Mode: Rechnet...');
            end
            drawnow;
            throwIfComputeCancelled();
        catch err
            if isComputeCancelledError(err)
                rethrow(err);
            end
        end
    end

    function endComputeProgress(progressHandle)
        try
            if isfield(progressHandle, 'waitbar') && ~isempty(progressHandle.waitbar) && isgraphics(progressHandle.waitbar)
                close(progressHandle.waitbar);
            end
        catch
        end
        try
            if isfield(progressHandle, 'previousPointer')
                set(ui.fig, 'Pointer', progressHandle.previousPointer);
            else
                set(ui.fig, 'Pointer', 'arrow');
            end
            set(ui.computeButton, 'Enable', 'on');
            updateStatusLabel();
            state.computeCancelRequested = false;
            drawnow;
        catch
        end
    end

    function onComputeCancelRequested(varargin)
        state.computeCancelRequested = true;
        try
            if ~isempty(varargin) && isgraphics(varargin{1})
                delete(varargin{1});
            end
            set(ui.statusText, 'String', 'Mode: Cancellation requested...');
            drawnow;
        catch
        end
    end

    function throwIfComputeCancelled()
        if state.computeCancelRequested
            error('truss_calculator:ComputeCancelled', 'Computation was cancelled by the user.');
        end
    end

    function tf = isComputeCancelledError(err)
        tf = strcmp(err.identifier, 'truss_calculator:ComputeCancelled');
    end

    function snapshot = snapshotResultState()
        snapshot = struct();
        snapshot.results = state.results;
        snapshot.symbolicResults = state.symbolicResults;
        snapshot.symbolicModel = state.symbolicModel;
        snapshot.symbolicVariableDefs = state.symbolicVariableDefs;
        snapshot.symbolicAngleVariableNames = state.symbolicAngleVariableNames;
        snapshot.symbolicDisplayCache = state.symbolicDisplayCache;
        snapshot.symbolicFastDisplay = state.symbolicFastDisplay;
        snapshot.resultView = state.resultView;
        snapshot.highlightElement = state.highlightElement;
    end

    function restoreResultState(snapshot)
        state.results = snapshot.results;
        state.symbolicResults = snapshot.symbolicResults;
        state.symbolicModel = snapshot.symbolicModel;
        state.symbolicVariableDefs = snapshot.symbolicVariableDefs;
        state.symbolicAngleVariableNames = snapshot.symbolicAngleVariableNames;
        state.symbolicDisplayCache = snapshot.symbolicDisplayCache;
        state.symbolicFastDisplay = snapshot.symbolicFastDisplay;
        state.resultView = snapshot.resultView;
        state.highlightElement = snapshot.highlightElement;
    end

    function exprOut = applyAngleConstraintDisplaySubstitutions(exprIn)
        exprOut = exprIn;
        if isempty(state.symbolicModel) || ~isfield(state.symbolicModel, 'angleConstraints') || isempty(state.symbolicModel.angleConstraints)
            return;
        end
        model = state.symbolicModel;
        for k = 1:numel(model.angleConstraints)
            try
                [refComponent, normalComponent, lengthComponent, ~, ok] = angleDisplayGeometry(model, k, 'reaction-detail');
                if ~ok
                    continue;
                end
                thetaRad = sym(pi) / 180 * sym(model.angleConstraints(k).angle);
                exprOut = applyAngleRatioSubstitutions(exprOut, refComponent, normalComponent, lengthComponent, thetaRad);
            catch
            end
        end
        exprOut = simplify(exprOut, 'IgnoreAnalyticConstraints', true);
    end
    function exprOut = applyAngleRatioSubstitutions(exprIn, refComponent, normalComponent, lengthComponent, thetaRad)
        exprOut = exprIn;
        if ~isPureNumericSymbolic(normalComponent / refComponent)
            exprOut = subs(exprOut, normalComponent / refComponent, tan(thetaRad));
        end
        if ~isPureNumericSymbolic(refComponent / normalComponent)
            exprOut = subs(exprOut, refComponent / normalComponent, cot(thetaRad));
        end
        exprOut = subs(exprOut, lengthComponent / normalComponent, 1 / sin(thetaRad));
        exprOut = subs(exprOut, lengthComponent / refComponent, 1 / cos(thetaRad));
        exprOut = subs(exprOut, normalComponent / lengthComponent, sin(thetaRad));
        exprOut = subs(exprOut, refComponent / lengthComponent, cos(thetaRad));
    end

    function tf = isPureNumericSymbolic(exprIn)
        exprSimplified = simplify(exprIn);
        tf = isempty(symvar(exprSimplified));
    end

    function signVal = symbolicDirectionSign(value)
        if isAlways(value > 0, 'Unknown', 'false')
            signVal = sym(1);
        elseif isAlways(value < 0, 'Unknown', 'false')
            signVal = sym(-1);
        else
            signVal = [];
            try
                approxValue = evaluateScalarExpression(char(value), state.symbolicVariableDefs, 'preview');
                if isfinite(approxValue) && abs(approxValue) > 1e-12
                    signVal = sym(sign(approxValue));
                end
            catch
            end
        end
    end

    function txt = formatAnyEntry(entry)
        if isa(entry, 'sym')
            txt = formatSymbolicText(entry);
            return;
        end
        if isnumeric(entry) || islogical(entry)
            if isscalar(entry)
                txt = formatNumber(double(entry));
            else
                txt = mat2str(double(entry));
            end
            return;
        end
        if isstring(entry)
            entry = char(entry);
        end
        if isempty(entry)
            txt = '0';
            return;
        end
        txt = strtrim(char(entry));
        if isempty(txt)
            txt = '0';
        end
    end

    function txt = formatLoadTableEntry(entry)
        if isempty(entry)
            txt = '';
            return;
        end
        if isstring(entry)
            entry = char(entry);
        end
        if ischar(entry)
            txt = strtrim(entry);
            return;
        end
        if isa(entry, 'sym')
            txt = formatSymbolicText(entry);
            return;
        end
        if isnumeric(entry) || islogical(entry)
            txt = formatNumber(double(entry));
            return;
        end
        txt = strtrim(char(string(entry)));
    end

    function txt = summaryText(model, results)
        maxDisp = max(sqrt(sum(results.displacements .^ 2, 2)));
        maxForce = max(abs(results.axialForces));
        reactionNorm = max(abs(results.reactions(:)));
        txt = sprintf([ ...
            'Computation successful.\n' ...
            'Visible nodes: %d\n' ...
            'Original nodes: %d\n' ...
            'Members: %d\n' ...
            'Load application points: %d\n' ...
            'Units: L=%s, F=%s, sigma=%s, E=%s, A=%s\n' ...
            'Max. displacement: %.6g %s\n' ...
            'Max. member force: %.6g %s\n' ...
            'Max. Support reaction: %.6g %s\n' ...
            'Deformation scale in plot: %.6g'], ...
            size(model.nodes, 1), model.originalNodeCount, size(model.elements, 1), size(model.loadPoints, 1), ...
            state.units.length, state.units.force, state.units.stress, state.units.young, state.units.area, ...
            maxDisp, state.units.length, maxForce, state.units.force, reactionNorm, state.units.force, results.scale);
    end

    function txt = summaryTextSymbolic(model, results, variableDefs, formatMode)
        if nargin < 4 || isempty(formatMode)
            formatMode = state.symbolicFormat;
        end
        if isempty(variableDefs.names)
            varText = 'none';
        else
            varText = strjoin(variableDefs.names.', ', ');
        end
        txt = sprintf([ ...
            'Symbolic computation successful.\n' ...
            'Variables: %s\n' ...
            'Visible nodes: %d\n' ...
            'Members: %d\n' ...
            'Display: %s\n' ...
            'Units: L=%s, F=%s, sigma=%s, E=%s, A=%s\n' ...
            'The results in the lower right can be switched between sin/cos and Fraction/Root.\n' ...
            'Example max. member force (symbolic): %s %s'], ...
            varText, size(model.nodes, 1), size(model.elements, 1), symbolicFormatLabel(formatMode), ...
            state.units.length, state.units.force, state.units.stress, state.units.young, state.units.area, ...
            formatSymbolicText(results.axialForces(1), 'detail', formatMode), state.units.force);
    end

    function label = symbolicFormatLabel(formatMode)
        if nargin < 1 || isempty(formatMode)
            formatMode = state.symbolicFormat;
        end
        if strcmp(formatMode, 'trig')
            label = 'sin/cos';
        else
            label = 'Fraction/Root';
        end
    end

    function [model, errMsg] = tryGetNumericModel()
        errMsg = '';
        model = struct('nodes', [], 'elements', [], 'materials', [], 'materialDefs', [], 'loads', [], ...
            'supports', [], 'supportDefs', [], 'loadPoints', [], 'angleConstraints', []);

        raw = readRawModelFromTables();

        try
            variableDefs = collectVariableDefs(raw);
            baseModel = struct();
            baseModel.variables = variableDefs;
            baseModel.elements = sanitizeIntegerMatrix(raw.elements, 3, 'Member Table');
            baseModel.angleConstraints = sanitizeAngleConstraintTable(raw.angleConstraints, baseModel.elements, variableDefs, 'numeric');
            baseModel.nodes = resolveNodeEntriesWithAngles(raw.nodeEntries, baseModel.elements, raw.angleConstraints, variableDefs, 'numeric');
            baseModel.materialDefs = sanitizeMaterialTable(raw.materials, 'Cross-section table', variableDefs, 'numeric');
            baseModel.materials = materialDefsToMatrix(baseModel.materialDefs);
            baseModel.supportDefs = sanitizeSupportTable(raw.supports, size(baseModel.nodes, 1), 'Support Table');
            baseModel.supports = supportDefsToConstraintMatrix(baseModel.supportDefs);
            baseModel.loadPoints = sanitizeLoadPointTable(raw.loadPoints, 'Load Table', variableDefs, 'numeric');
            baseModel.originalNodeCount = size(baseModel.nodes, 1);
            validateBaseModel(baseModel);
            model = expandModelWithLoadPoints(baseModel);
            validateModel(model);
        catch err
            errMsg = err.message;
        end
    end

    function model = buildSymbolicModel(raw, variableDefs)
        baseModel = struct();
        baseModel.variables = variableDefs;
        baseModel.elements = sanitizeIntegerMatrix(raw.elements, 3, 'Member Table');
        baseModel.angleConstraints = sanitizeAngleConstraintTable(raw.angleConstraints, baseModel.elements, variableDefs, 'symbolic');
        [baseModel.nodes, baseModel.symbolicNodes] = resolveNodeEntriesWithAngles(raw.nodeEntries, baseModel.elements, raw.angleConstraints, variableDefs, 'symbolic');
        baseModel.materialDefs = sanitizeMaterialTable(raw.materials, 'Cross-section table', variableDefs, 'symbolic');
        baseModel.materials = materialDefsToMatrix(baseModel.materialDefs);
        baseModel.supportDefs = sanitizeSupportTable(raw.supports, size(baseModel.nodes, 1), 'Support Table');
        baseModel.supports = supportDefsToConstraintMatrix(baseModel.supportDefs);
        baseModel.loadPoints = sanitizeLoadPointTable(raw.loadPoints, 'Load Table', variableDefs, 'symbolic');
        baseModel.originalNodeCount = size(baseModel.nodes, 1);
        validateBaseModel(baseModel);
        model = expandModelWithLoadPointsSymbolic(baseModel);
        validateModel(model);
    end

    function [model, errMsg, isReady] = getDisplayModel()
        if ~isempty(state.symbolicModel)
            try
                model = buildDisplayModelFromSymbolicState();
                errMsg = '';
                isReady = true;
                return;
            catch
            end
        end
        [model, errMsg] = tryGetNumericModel();
        isReady = isempty(errMsg);
        if isReady
            return;
        end
        model = buildPreviewModel();
    end

    function model = buildDisplayModelFromSymbolicState()
        model = state.symbolicModel;
        variableDefs = state.symbolicVariableDefs;

        model.symbolicNodes = state.symbolicModel.nodes;
        model.nodes = double(vpa(substitutePreviewIntoSym(model.symbolicNodes, variableDefs, true)));

        if isfield(model, 'loadPoints') && ~isempty(model.loadPoints)
            model.loadPoints = double(vpa(substitutePreviewIntoSym(model.loadPoints, variableDefs, true)));
        else
            model.loadPoints = zeros(0, 4);
        end

        if any(~isfinite(model.nodes), 'all')
            error('The symbolic display could not be converted to numeric preview values.');
        end
        if ~isempty(model.loadPoints) && any(~isfinite(model.loadPoints), 'all')
            error('The symbolic load points could not be converted to numeric preview values.');
        end
    end

    function model = buildPreviewModel()
        raw = readRawModelFromTables();
        variableDefs = collectVariableDefs(raw);
        if hasActiveAngleConstraints(raw.angleConstraints)
            try
                previewNodes = resolveNodeEntriesWithAngles(raw.nodeEntries, sanitizeIntegerMatrix(raw.elements, 3, 'Member Table'), ...
                    raw.angleConstraints, variableDefs, 'preview');
                symbolicNodesAll = resolveNodeEntriesWithAngles(raw.nodeEntries, sanitizeIntegerMatrix(raw.elements, 3, 'Member Table'), ...
                    raw.angleConstraints, variableDefs, 'symbolic');
                model = struct();
                model.nodes = previewNodes;
                model.symbolicNodes = symbolicNodesAll;
                model.variableDefs = variableDefs;
                model.originalNodeCount = size(model.nodes, 1);
                model.nodeOrigin = [(1:model.originalNodeCount).', zeros(model.originalNodeCount, 1)];
                model.supportDefs = sanitizeSupportTable(raw.supports, size(model.nodes, 1), 'Support Table');
                model.supports = supportDefsToConstraintMatrix(model.supportDefs);
                model.elements = sanitizeIntegerMatrix(raw.elements, 3, 'Member Table');
                model.materialDefs = buildPreviewMaterialDefs(raw.materials, variableDefs);
                model.materials = materialDefsToMatrix(model.materialDefs);
                model.loadPoints = buildPreviewLoadPoints(raw.loadPoints, variableDefs);
                model.loads = zeros(size(model.nodes, 1), 2);
                return;
            catch
            end
        end
        nodeEntries = getCellMatrix(raw.nodeEntries, 2);
        nRows = size(nodeEntries, 1);

        allCoords = nan(nRows, 2);
        validNodeRows = false(nRows, 1);
        for r = 1:nRows
            try
                xVal = evaluateCoordinate(nodeEntries{r, 1}, allCoords, r, variableDefs, 'preview');
                yVal = evaluateCoordinate(nodeEntries{r, 2}, allCoords, r, variableDefs, 'preview');
                if isfinite(xVal) && isfinite(yVal)
                    allCoords(r, :) = [xVal, yVal];
                    validNodeRows(r) = true;
                end
            catch
            end
        end

        model = struct();
        model.nodes = allCoords(validNodeRows, :);
        model.symbolicNodes = sym([]);
        try
            symbolicNodesAll = evaluateNodeEntries(raw.nodeEntries, variableDefs, 'symbolic');
            model.symbolicNodes = symbolicNodesAll(validNodeRows, :);
        catch
            model.symbolicNodes = sym([]);
        end
        model.variableDefs = variableDefs;
        model.originalNodeCount = size(model.nodes, 1);
        model.nodeOrigin = [(1:model.originalNodeCount).', zeros(model.originalNodeCount, 1)];
        rowToNode = zeros(nRows, 1);
        rowToNode(validNodeRows) = 1:model.originalNodeCount;

        supportData = resizeSupportTable(getCellMatrix(raw.supports, 2), nRows);
        model.supportDefs = cell(0, 2);
        for r = 1:nRows
            nodeIdx = rowToNode(r);
            if nodeIdx < 1
                continue;
            end
            model.supportDefs(nodeIdx, :) = {normalizeSupportType(supportData{r, 1}), num2str(normalizeSupportAngle(supportData{r, 2}))};
        end
        model.supports = supportDefsToConstraintMatrix(model.supportDefs);

        elemData = getCellMatrix(raw.elements, 3);
        model.elements = zeros(0, 3);
        for r = 1:size(elemData, 1)
            iOrig = cellToRoundedInt(elemData{r, 1});
            jOrig = cellToRoundedInt(elemData{r, 2});
            matIdx = cellToRoundedInt(elemData{r, 3});
            if ~isfinite(iOrig) || ~isfinite(jOrig) || iOrig < 1 || jOrig < 1 || ...
                    iOrig > nRows || jOrig > nRows || iOrig == jOrig
                continue;
            end
            if rowToNode(iOrig) < 1 || rowToNode(jOrig) < 1
                continue;
            end
            if ~isfinite(matIdx) || matIdx < 1
                matIdx = 1;
            end
            model.elements(end + 1, :) = [rowToNode(iOrig), rowToNode(jOrig), matIdx];
        end

        model.materialDefs = buildPreviewMaterialDefs(raw.materials, variableDefs);
        model.materials = materialDefsToMatrix(model.materialDefs);

        model.loadPoints = buildPreviewLoadPoints(raw.loadPoints, variableDefs);

        model.loads = zeros(size(model.nodes, 1), 2);
    end

    function validateBaseModel(model)
        nNodes = size(model.nodes, 1);
        isSymbolicModel = isa(model.nodes, 'sym') || isa(model.materials, 'sym') || isa(model.loadPoints, 'sym');
        if nNodes < 2
            error('Please create at least two nodes.');
        end
        if size(model.elements, 1) < 1
            error('Please create at least one member.');
        end
        if size(model.materials, 1) < 1
            error('Please create at least one material.');
        end
        if size(model.supports, 1) ~= nNodes
            error('Die Support Table muss genau so viele rown wie die Node Table haben.');
        end
        for e = 1:size(model.elements, 1)
            i = model.elements(e, 1);
            j = model.elements(e, 2);
            m = model.elements(e, 3);
            if i < 1 || i > nNodes || j < 1 || j > nNodes
                error('Member %d references an invalid node.', e);
            end
            if i == j
                error('Member %d uses the same start and end node.', e);
            end
            if m < 1 || m > size(model.materials, 1)
                error('Member %d verweist auf ein unvalids Material.', e);
            end
            if isSymbolicModel
                dx = simplify(model.nodes(i, 1) - model.nodes(j, 1));
                dy = simplify(model.nodes(i, 2) - model.nodes(j, 2));
                if isAlways(dx == 0, 'Unknown', 'false') && isAlways(dy == 0, 'Unknown', 'false')
                    error('Member %d hat Length 0.', e);
                end
            else
                if norm(model.nodes(i, :) - model.nodes(j, :)) < 1e-12
                    error('Member %d hat nahezu Length 0.', e);
                end
            end
        end
        if ~any(model.supports(:))
            error('At least one degree of freedom must be restrained.');
        end
    end

    function validateModel(model)
        validateBaseModel(model);
        if size(model.loads, 1) ~= size(model.nodes, 1)
            error('Internal error: The processed nodal loads do not match the number of nodes.');
        end
    end

    function model = readRawModelFromTables()
        model = struct();
        model.nodeEntries = getTableDataAsCell(ui.nodesTable);
        model.elements = getTableDataAsCell(ui.elementsTable);
        model.materials = getTableDataAsCell(ui.materialsTable);
        model.angleConstraints = getTableDataAsCell(ui.anglesTable);
        model.loadPoints = getTableDataAsCell(ui.loadsTable);
        model.supports = getTableDataAsCell(ui.supportsTable);
        model.variables = getTableDataAsCell(ui.variablesTable);
    end

    function applyRawModelToTables(model)
        requiredFields = {'nodeEntries', 'elements', 'materials', 'supports'};
        for k = 1:numel(requiredFields)
            if ~isfield(model, requiredFields{k})
                error('The loaded structure does not contain all required fields.');
            end
        end

        set(ui.nodesTable, 'Data', getCellMatrix(model.nodeEntries, 2));
        set(ui.elementsTable, 'Data', getCellMatrix(model.elements, 3));
        if isfield(model, 'materialDefs')
            set(ui.materialsTable, 'Data', getCellMatrix(model.materialDefs, 5));
        else
            materialData = model.materials;
            if iscell(materialData) && ~isempty(materialData) && size(materialData, 2) == 5
                set(ui.materialsTable, 'Data', getCellMatrix(materialData, 5));
            elseif ~iscell(materialData) && ~isempty(materialData) && size(materialData, 2) == 5
                set(ui.materialsTable, 'Data', num2cell(materialData));
            else
                set(ui.materialsTable, 'Data', convertLegacyMaterialsToMaterialDefs(model));
            end
        end
        if isfield(model, 'angleConstraints')
            set(ui.anglesTable, 'Data', getCellMatrix(model.angleConstraints, 3));
        else
            set(ui.anglesTable, 'Data', cell(0, 3));
        end
        if isfield(model, 'supportDefs')
            set(ui.supportsTable, 'Data', resizeSupportTable(getCellMatrix(model.supportDefs, 2), size(model.nodeEntries, 1)));
        else
            set(ui.supportsTable, 'Data', convertLegacySupportsToSupportDefs(model));
        end
        if isfield(model, 'loadPoints')
            loadPointData = model.loadPoints;
            if iscell(loadPointData) && ~isempty(loadPointData) && size(loadPointData, 2) == 6
                set(ui.loadsTable, 'Data', getCellMatrix(loadPointData, 6));
            elseif ~iscell(loadPointData) && ~isempty(loadPointData) && size(loadPointData, 2) == 6
                set(ui.loadsTable, 'Data', convertProcessedLoadPointsToLoadTable(loadPointData));
            else
                set(ui.loadsTable, 'Data', convertProcessedLoadPointsToLoadTable(loadPointData));
            end
        elseif isfield(model, 'loads')
            set(ui.loadsTable, 'Data', convertLegacyLoadsToLoadPoints(model));
        else
            set(ui.loadsTable, 'Data', cell(0, 6));
        end
        if isfield(model, 'variables')
            set(ui.variablesTable, 'Data', getCellMatrix(model.variables, 2));
        else
            set(ui.variablesTable, 'Data', cell(0, 2));
        end
        synchronizeNodeTables();
    end

    function model = expandModelWithLoadPoints(baseModel)
        model = baseModel;
        model.loads = zeros(size(baseModel.nodes, 1), 2);
        model.nodeOrigin = [(1:baseModel.originalNodeCount).', zeros(baseModel.originalNodeCount, 1)];

        tol = geometryTolerance(baseModel.nodes);
        for k = 1:size(baseModel.loadPoints, 1)
            drawnow limitrate;
            throwIfComputeCancelled();
            point = baseModel.loadPoints(k, 1:2);
            force = baseModel.loadPoints(k, 3:4);
            nodeIdx = findOrCreateNodeForLoad(point);
            model.loadPoints(k, 1:2) = model.nodes(nodeIdx, :);
            model.loads(nodeIdx, :) = model.loads(nodeIdx, :) + force;
        end

        function nodeIdx = findOrCreateNodeForLoad(point)
            nodeIdx = findMatchingNode(point);
            if ~isempty(nodeIdx)
                return;
            end

            [elemIdx, projectedPoint] = findContainingElement(point);
            if isempty(elemIdx)
                nodeIdx = findMatchingNode(projectedPoint);
                if ~isempty(nodeIdx)
                    return;
                end
                error(['A load application point at (%.6g, %.6g) does not lie on a node or member. ' ...
                    'Please Loads auf das Fachwerk setzen.'], point(1), point(2));
            end

            e = model.elements(elemIdx, :);
            nodeIdx = size(model.nodes, 1) + 1;
            model.nodes(nodeIdx, :) = projectedPoint;
            model.supports(nodeIdx, :) = [false, false];
            model.supportDefs(nodeIdx, :) = {'No Support', '0'};
            model.loads(nodeIdx, :) = [0, 0];
            model.nodeOrigin(nodeIdx, :) = [0, 1];

            model.elements(elemIdx, :) = [e(1), nodeIdx, e(3)];
            model.elements(end + 1, :) = [nodeIdx, e(2), e(3)];
        end

        function idx = findMatchingNode(point)
            distances = sqrt(sum((model.nodes - point) .^ 2, 2));
            idx = find(distances <= tol, 1);
        end

        function [elemIdx, projectedPoint] = findContainingElement(point)
            elemIdx = [];
            projectedPoint = point;
            bestDistance = inf;

            for eIdx = 1:size(model.elements, 1)
                e = model.elements(eIdx, :);
                p1 = model.nodes(e(1), :);
                p2 = model.nodes(e(2), :);
                [distance, t, proj] = pointToSegmentDistance(point, p1, p2);
                if distance <= tol && t > 1e-8 && t < 1 - 1e-8 && distance < bestDistance
                    elemIdx = eIdx;
                    projectedPoint = proj;
                    bestDistance = distance;
                elseif distance <= tol && (t <= 1e-8 || t >= 1 - 1e-8)
                    idx = findMatchingNode(proj);
                    if ~isempty(idx)
                        elemIdx = [];
                        projectedPoint = proj;
                        return;
                    end
                end
            end
        end
    end

    function model = expandModelWithLoadPointsSymbolic(baseModel)
        model = baseModel;
        model.loads = sym(zeros(size(baseModel.nodes, 1), 2));
        model.nodeOrigin = [(1:baseModel.originalNodeCount).', zeros(baseModel.originalNodeCount, 1)];

        for k = 1:size(baseModel.loadPoints, 1)
            drawnow limitrate;
            throwIfComputeCancelled();
            point = baseModel.loadPoints(k, 1:2);
            force = baseModel.loadPoints(k, 3:4);
            nodeIdx = findMatchingNodeSymbolic(point);
            if isempty(nodeIdx)
                [elemIdx, projectedPoint] = findContainingElementSymbolic(point);
                if isempty(elemIdx)
                    error('In symbolic mode, a load application point must lie on an existing node or member.');
                end
                e = model.elements(elemIdx, :);
                nodeIdx = size(model.nodes, 1) + 1;
                model.nodes(nodeIdx, :) = projectedPoint;
                model.supports(nodeIdx, :) = [false, false];
                model.supportDefs(nodeIdx, :) = {'No Support', '0'};
                model.loads(nodeIdx, :) = sym([0, 0]);
                model.nodeOrigin(nodeIdx, :) = [0, 1];
                if isfield(model, 'symbolicNodes') && ~isempty(model.symbolicNodes)
                    model.symbolicNodes(nodeIdx, :) = projectedPoint;
                end
                model.elements(elemIdx, :) = [e(1), nodeIdx, e(3)];
                model.elements(end + 1, :) = [nodeIdx, e(2), e(3)];
            end
            model.loadPoints(k, 1:2) = model.nodes(nodeIdx, :);
            model.loads(nodeIdx, :) = model.loads(nodeIdx, :) + force;
        end

        function idx = findMatchingNodeSymbolic(point)
            idx = [];
            for nodeIdxLocal = 1:size(model.nodes, 1)
                dx = simplify(model.nodes(nodeIdxLocal, 1) - point(1));
                dy = simplify(model.nodes(nodeIdxLocal, 2) - point(2));
                if isAlways(dx == 0, 'Unknown', 'false') && isAlways(dy == 0, 'Unknown', 'false')
                    idx = nodeIdxLocal;
                    return;
                end
            end
        end

        function [elemIdx, projectedPoint] = findContainingElementSymbolic(point)
            elemIdx = [];
            projectedPoint = point;
            for eIdx = 1:size(model.elements, 1)
                e = model.elements(eIdx, :);
                p1 = model.nodes(e(1), :);
                p2 = model.nodes(e(2), :);
                d = p2 - p1;

                if ~isAlways(d(1) == 0, 'Unknown', 'false')
                    lambda = simplify((point(1) - p1(1)) / d(1));
                    onLine = isAlways(simplify(point(2) - p1(2) - lambda * d(2)) == 0, 'Unknown', 'false');
                elseif ~isAlways(d(2) == 0, 'Unknown', 'false')
                    lambda = simplify((point(2) - p1(2)) / d(2));
                    onLine = isAlways(simplify(point(1) - p1(1) - lambda * d(1)) == 0, 'Unknown', 'false');
                else
                    continue;
                end

                if onLine && isAlways(lambda > 0, 'Unknown', 'false') && isAlways(lambda < 1, 'Unknown', 'false')
                    elemIdx = eIdx;
                    projectedPoint = simplify(p1 + lambda * d);
                    return;
                end
            end
        end
    end

    function tol = geometryTolerance(nodes)
        span = max([range(nodes(:, 1)), range(nodes(:, 2)), 1]);
        tol = max(1e-8 * span, 1e-10);
    end

    function [distance, t, proj] = pointToSegmentDistance(point, p1, p2)
        d = p2 - p1;
        denom = dot(d, d);
        if denom < eps
            proj = p1;
            t = 0;
            distance = norm(point - p1);
            return;
        end
        t = dot(point - p1, d) / denom;
        tClamped = max(0, min(1, t));
        proj = p1 + tClamped * d;
        distance = norm(point - proj);
        t = tClamped;
    end

    function rows = convertLegacyLoadsToLoadPoints(model)
        nodeEntries = getCellMatrix(model.nodeEntries, 2);
        loads = cellToNumericIfPossible(getCellMatrix(model.loads, 2), 0);
        rows = cell(0, 6);
        for k = 1:min(size(nodeEntries, 1), size(loads, 1))
            if any(abs(loads(k, :)) > 0)
                rows(end + 1, :) = {formatLoadTableEntry(nodeEntries{k, 1}), formatLoadTableEntry(nodeEntries{k, 2}), ...
                    formatLoadTableEntry(loads(k, 1)), formatLoadTableEntry(loads(k, 2)), '', ''}; %#ok<AGROW>
            end
        end
    end

    function rows = convertProcessedLoadPointsToLoadTable(loadPoints)
        if isempty(loadPoints)
            rows = cell(0, 6);
            return;
        end
        if iscell(loadPoints)
            points = cellToNumericIfPossible(getCellMatrix(loadPoints, size(loadPoints, 2)), 0);
        else
            points = loadPoints;
        end
        rows = cell(size(points, 1), 6);
        for k = 1:size(points, 1)
            fx = points(k, 3);
            fy = points(k, 4);
            mag = hypot(fx, fy);
            ang = atan2d(fy, fx);
            rows(k, :) = {formatLoadTableEntry(points(k, 1)), formatLoadTableEntry(points(k, 2)), ...
                formatLoadTableEntry(fx), formatLoadTableEntry(fy), ...
                formatLoadTableEntry(mag), formatLoadTableEntry(ang)};
        end
    end

    function rows = convertLegacyMaterialsToMaterialDefs(model)
        materials = getCellMatrix(model.materials, 2);
        rows = cell(size(materials, 1), 5);
        for k = 1:size(materials, 1)
            areaVal = cellToDouble(materials{k, 1});
            eVal = cellToDouble(materials{k, 2});
            if ~isfinite(areaVal) || areaVal <= 0
                areaVal = pi * 0.05^2 / 4;
            end
            if ~isfinite(eVal) || eVal <= 0
                eVal = 210e9;
            end
            diameter = sqrt(4 * areaVal / pi);
            rows(k, :) = {'Circular', diameter, 0, 0, eVal};
        end
    end

    function rows = convertLegacySupportsToSupportDefs(model)
        supports = getCellMatrix(model.supports, 2);
        rows = cell(size(supports, 1), 2);
        for k = 1:size(supports, 1)
            fixX = cellToLogicalPreview(supports{k, 1});
            fixY = cellToLogicalPreview(supports{k, 2});
            if fixX && fixY
                rows(k, :) = {'Pinned Support', '0'};
            elseif fixY
                rows(k, :) = {'Roller Support', '0'};
            elseif fixX
                rows(k, :) = {'Roller Support', '90'};
            else
                rows(k, :) = {'No Support', '0'};
            end
        end
    end

    function result = solveTruss(model)
        nNodes = size(model.nodes, 1);
        nElem = size(model.elements, 1);
        nDof = 2 * nNodes;

        K = zeros(nDof, nDof);
        F = reshape(model.loads.', [], 1);
        fixed = reshape(model.supports.', [], 1);
        fixed = logical(fixed);

        lengths = zeros(nElem, 1);
        areas = zeros(nElem, 1);
        axialForces = zeros(nElem, 1);
        stresses = zeros(nElem, 1);
        elementData = cell(nElem, 1);

        for e = 1:nElem
            if mod(e, 5) == 0
                drawnow limitrate;
                throwIfComputeCancelled();
            end
            ni = model.elements(e, 1);
            nj = model.elements(e, 2);
            matIdx = model.elements(e, 3);

            p1 = model.nodes(ni, :);
            p2 = model.nodes(nj, :);
            d = p2 - p1;
            L = norm(d);
            c = d(1) / L;
            s = d(2) / L;

            A = model.materials(matIdx, 1);
            E = model.materials(matIdx, 2);
            kLocal = (A * E / L) * [ ...
                c^2, c * s, -c^2, -c * s
                c * s, s^2, -c * s, -s^2
                -c^2, -c * s, c^2, c * s
                -c * s, -s^2, c * s, s^2];

            dof = [2 * ni - 1, 2 * ni, 2 * nj - 1, 2 * nj];
            K(dof, dof) = K(dof, dof) + kLocal;

            lengths(e) = L;
            areas(e) = A;
            elementData{e} = struct('A', A, 'E', E, 'L', L, 'c', c, 's', s, 'dof', dof);
        end

        free = ~fixed;
        if ~any(free)
            error('All degrees of freedom are blocked. Please leave at least one free degree of freedom.');
        end

        Kff = K(free, free);
        if rcond(Kff) < 1e-14
            error('The system is singular or nearly singular. Please check supports and geometry.');
        end

        U = zeros(nDof, 1);
        U(free) = Kff \ F(free);
        R = K * U - F;

        for e = 1:nElem
            if mod(e, 5) == 0
                drawnow limitrate;
                throwIfComputeCancelled();
            end
            ed = elementData{e};
            ue = U(ed.dof);
            extension = [-ed.c, -ed.s, ed.c, ed.s] * ue;
            axialForces(e) = ed.A * ed.E / ed.L * extension;
            stresses(e) = axialForces(e) / ed.A;
        end

        Uxy = reshape(U, 2, []).';
        Rxy = reshape(R, 2, []).';
        scale = deformationScale(model.nodes, Uxy);

        result = struct();
        result.displacements = Uxy;
        result.reactions = Rxy;
        result.axialForces = axialForces;
        result.stresses = stresses;
        result.lengths = lengths;
        result.areas = areas;
        result.scale = scale;
        result.model = model;
        result.reactionNodeIds = find(any(model.supports, 2));
    end

    function result = solveTrussSymbolic(model)
        nNodes = size(model.nodes, 1);
        nElem = size(model.elements, 1);
        nDof = 2 * nNodes;

        K = sym(zeros(nDof, nDof));
        F = reshape(model.loads.', [], 1);
        fixed = reshape(model.supports.', [], 1);
        fixed = logical(fixed);

        lengths = sym(zeros(nElem, 1));
        areas = sym(zeros(nElem, 1));
        axialForces = sym(zeros(nElem, 1));
        stresses = sym(zeros(nElem, 1));
        elementData = cell(nElem, 1);

        for e = 1:nElem
            if mod(e, 5) == 0
                drawnow limitrate;
                throwIfComputeCancelled();
            end
            ni = model.elements(e, 1);
            nj = model.elements(e, 2);
            matIdx = model.elements(e, 3);

            p1 = model.nodes(ni, :);
            p2 = model.nodes(nj, :);
            d = p2 - p1;
            L = sqrt(d(1)^2 + d(2)^2);
            c = d(1) / L;
            s = d(2) / L;

            A = model.materials(matIdx, 1);
            E = model.materials(matIdx, 2);
            kLocal = (A * E / L) * [ ...
                c^2, c * s, -c^2, -c * s
                c * s, s^2, -c * s, -s^2
                -c^2, -c * s, c^2, c * s
                -c * s, -s^2, c * s, s^2];

            dof = [2 * ni - 1, 2 * ni, 2 * nj - 1, 2 * nj];
            K(dof, dof) = K(dof, dof) + kLocal;

            lengths(e) = L;
            areas(e) = A;
            elementData{e} = struct('A', A, 'E', E, 'L', L, 'c', c, 's', s, 'dof', dof);
        end

        free = ~fixed;
        U = sym(zeros(nDof, 1));
        drawnow;
        throwIfComputeCancelled();
        U(free) = solveSymbolicLinearSystem(K(free, free), F(free));
        R = K * U - F;

        for e = 1:nElem
            if mod(e, 5) == 0
                drawnow limitrate;
                throwIfComputeCancelled();
            end
            ed = elementData{e};
            ue = U(ed.dof);
            extension = [-ed.c, -ed.s, ed.c, ed.s] * ue;
            axialForces(e) = ed.A * ed.E / ed.L * extension;
            stresses(e) = axialForces(e) / ed.A;
        end

        Uxy = reshape(U, 2, []).';
        Rxy = reshape(R, 2, []).';

        result = struct();
        result.displacements = Uxy;
        result.reactions = Rxy;
        result.axialForces = axialForces;
        result.stresses = stresses;
        result.lengths = lengths;
        result.areas = areas;
        result.scale = 1;
        result.model = model;
        result.reactionNodeIds = find(any(model.supports, 2));
        result.solverMode = 'symbolic-fem';
    end

    function x = solveSymbolicLinearSystem(A, b)
        previewA = double(vpa(substitutePreviewIntoSym(A, state.symbolicVariableDefs, true)));
        previewB = double(vpa(substitutePreviewIntoSym(b, state.symbolicVariableDefs, true)));
        n = size(previewA, 1);
        r = rank(previewA);
        if r == n
            x = A \ b;
            return;
        end

        [~, pivotCols] = rref(previewA);
        [~, pivotRows] = rref(previewA.');
        if numel(pivotCols) ~= r || numel(pivotRows) ~= r
            x = A \ b;
            return;
        end

        reducedA = A(pivotRows, pivotCols);
        reducedB = b(pivotRows);
        previewReduced = previewA(pivotRows, pivotCols);
        previewSol = previewReduced \ previewB(pivotRows);
        residual = previewA(:, pivotCols) * previewSol - previewB;
        if any(~isfinite(previewSol)) || norm(residual, inf) > 1e-7 * max(1, norm(previewB, inf))
            x = A \ b;
            return;
        end

        x = sym(zeros(size(b)));
        x(pivotCols) = reducedA \ reducedB;
    end

    function tf = canUseSymbolicJointSolver(model)
        nNodes = size(model.nodes, 1);
        nElem = size(model.elements, 1);
        reactionCount = nnz(model.supports);
        tf = (nElem + reactionCount) <= 2 * nNodes;
    end

    function result = solveTrussSymbolicByEquilibrium(model)
        nNodes = size(model.nodes, 1);
        nElem = size(model.elements, 1);

        reactionNodeIds = find(any(model.supports, 2));
        reactionMeta = zeros(nnz(model.supports), 2);

        eqCount = 2 * nNodes;
        unknownCount = nElem + nnz(model.supports);
        if unknownCount > eqCount
            error('The symbolic fast solver expects no more unknowns than joint equations.');
        end

        Aeq = sym(zeros(eqCount, unknownCount));
        beq = sym(zeros(eqCount, 1));

        for nodeIdx = 1:nNodes
            rowX = 2 * nodeIdx - 1;
            rowY = 2 * nodeIdx;
            beq(rowX) = -model.loads(nodeIdx, 1);
            beq(rowY) = -model.loads(nodeIdx, 2);
        end

        lengths = sym(zeros(nElem, 1));
        areas = sym(zeros(nElem, 1));
        stresses = sym(zeros(nElem, 1));

        for e = 1:nElem
            if mod(e, 5) == 0
                drawnow limitrate;
                throwIfComputeCancelled();
            end
            ni = model.elements(e, 1);
            nj = model.elements(e, 2);
            matIdx = model.elements(e, 3);
            p1 = model.nodes(ni, :);
            p2 = model.nodes(nj, :);
            dx = p2(1) - p1(1);
            dy = p2(2) - p1(2);
            L = sqrt(dx^2 + dy^2);
            c = dx / L;
            s = dy / L;

            rowXi = 2 * ni - 1;
            rowYi = 2 * ni;
            rowXj = 2 * nj - 1;
            rowYj = 2 * nj;

            Aeq(rowXi, e) = Aeq(rowXi, e) + c;
            Aeq(rowYi, e) = Aeq(rowYi, e) + s;
            Aeq(rowXj, e) = Aeq(rowXj, e) - c;
            Aeq(rowYj, e) = Aeq(rowYj, e) - s;

            lengths(e) = L;
            areas(e) = model.materials(matIdx, 1);
        end

        col = nElem;
        for nodeIdx = 1:nNodes
            drawnow limitrate;
            throwIfComputeCancelled();
            if model.supports(nodeIdx, 1)
                col = col + 1;
                Aeq(2 * nodeIdx - 1, col) = sym(1);
                reactionMeta(col - nElem, :) = [nodeIdx, 1];
            end
            if model.supports(nodeIdx, 2)
                col = col + 1;
                Aeq(2 * nodeIdx, col) = sym(1);
                reactionMeta(col - nElem, :) = [nodeIdx, 2];
            end
        end

        if col ~= unknownCount
            error('Internal error while building the reaction unknowns.');
        end

        previewA = double(vpa(substitutePreviewIntoSym(Aeq, state.symbolicVariableDefs, true)));
        if rank(previewA) < unknownCount
            error(['The symbolic fast solver detected a singular or statically indeterminate system. ' ...
                'Please check geometry and supports.']);
        end

        if eqCount == unknownCount
            activeRows = 1:eqCount;
        else
            [~, activeRows] = rref(previewA.');
            if numel(activeRows) ~= unknownCount
                error('The joint equilibrium equations do not provide uniquely independent rows for the fast solver.');
            end
        end

        drawnow;
        throwIfComputeCancelled();
        x = Aeq(activeRows, :) \ beq(activeRows);
        axialForces = x(1:nElem);
        reactions = sym(zeros(nNodes, 2));
        for k = 1:size(reactionMeta, 1)
            drawnow limitrate;
            throwIfComputeCancelled();
            nodeIdx = reactionMeta(k, 1);
            dirIdx = reactionMeta(k, 2);
            reactions(nodeIdx, dirIdx) = x(nElem + k);
        end

        for e = 1:nElem
            if mod(e, 5) == 0
                drawnow limitrate;
                throwIfComputeCancelled();
            end
            stresses(e) = axialForces(e) / areas(e);
        end

        result = struct();
        result.displacements = sym([]);
        result.reactions = reactions;
        result.axialForces = axialForces;
        result.stresses = stresses;
        result.lengths = lengths;
        result.areas = areas;
        result.scale = 1;
        result.model = model;
        result.reactionNodeIds = reactionNodeIds;
        result.solverMode = 'joint-equilibrium';
    end

    function scale = deformationScale(nodes, Uxy)
        maxDisp = max(sqrt(sum(Uxy .^ 2, 2)));
        span = max([range(nodes(:, 1)), range(nodes(:, 2)), 1]);
        if maxDisp < 1e-14
            scale = 1;
        else
            scale = 0.18 * span / maxDisp;
        end
    end

    function color = forceColor(force, maxAbsForce)
        if maxAbsForce < 1e-14 || abs(force) < maxAbsForce * 1e-6
            color = [0.96 0.96 0.96];
        elseif force > 0
            color = [0.08 0.42 0.88];
        else
            color = [0.85 0.15 0.15];
        end
    end

    function nodes = evaluateNodeEntries(entries, variableDefs, mode)
        if nargin < 2
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 3
            mode = 'numeric';
        end
        entries = getCellMatrix(entries, 2);
        n = size(entries, 1);
        if strcmp(mode, 'symbolic')
            nodes = sym(zeros(n, 2));
        else
            nodes = zeros(n, 2);
        end

        for i = 1:n
            xVal = evaluateCoordinate(entries{i, 1}, nodes, i, variableDefs, mode);
            yVal = evaluateCoordinate(entries{i, 2}, nodes, i, variableDefs, mode);

            if strcmp(mode, 'numeric') && (~isfinite(xVal) || ~isfinite(yVal))
                error('Node %d does not contain valid coordinates.', i);
            end

            nodes(i, :) = [xVal, yVal];
        end
    end

    function [nodesOut, symbolicNodes] = resolveNodeEntriesWithAngles(entries, elements, angleData, variableDefs, mode)
        if nargin < 4
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 5
            mode = 'numeric';
        end

        if ~hasActiveAngleConstraints(angleData)
            nodesOut = evaluateNodeEntries(entries, variableDefs, mode);
            if strcmp(mode, 'symbolic')
                symbolicNodes = nodesOut;
            else
                symbolicNodes = sym(nodesOut);
            end
            return;
        end

        angleConstraints = sanitizeAngleConstraintTable(angleData, elements, variableDefs, mode);
        [symbolicNodes, unknownVars] = evaluateNodeEntriesWithUnknowns(entries, variableDefs, mode);
        if isempty(unknownVars)
            nodesOut = finalizeResolvedNodes(symbolicNodes, mode);
            return;
        end

        eqns = sym.empty(0, 1);
        for k = 1:numel(angleConstraints)
            [commonNode, otherNode1, otherNode2] = sharedNodesForAngleConstraint(elements, angleConstraints(k).elem1, angleConstraints(k).elem2, k);
            pCommon = symbolicNodes(commonNode, :);
            p1 = symbolicNodes(otherNode1, :);
            p2 = symbolicNodes(otherNode2, :);
            v1 = p1 - pCommon;
            v2 = p2 - pCommon;
            theta = sym(angleConstraints(k).angle);
            thetaRad = sym(pi) / 180 * theta;
            eqns(end + 1, 1) = dot(v1, v2) - sqrt(dot(v1, v1)) * sqrt(dot(v2, v2)) * cos(thetaRad); %#ok<AGROW>
        end

        if numel(eqns) < numel(unknownVars)
            error(['The angle constraints are not sufficient to determine all missing node coordinates. ' ...
                'Please provide additional coordinates, lengths, or angles.']);
        end

        try
            solutions = solve(eqns, unknownVars, 'Real', true, 'ReturnConditions', false);
        catch err
            error('The angle constraints could not be resolved:\n%s', err.message);
        end

        solutionValues = extractSolutionValues(solutions, unknownVars);
        if isempty(solutionValues)
            error('No matching geometry solution was found for the angle constraints.');
        end

        symbolicNodes = subs(symbolicNodes, unknownVars, solutionValues);
        nodesOut = finalizeResolvedNodes(symbolicNodes, mode);
    end

    function [nodes, unknownVars] = evaluateNodeEntriesWithUnknowns(entries, variableDefs, mode)
        entries = getCellMatrix(entries, 2);
        n = size(entries, 1);
        nodes = sym(zeros(n, 2));
        unknownVars = sym.empty(0, 1);
        evalMode = mode;
        if strcmp(mode, 'preview')
            evalMode = 'preview';
        elseif ~strcmp(mode, 'symbolic')
            evalMode = 'numeric';
        end

        for i = 1:n
            if isBlankCell(entries{i, 1})
                nodes(i, 1) = sym(sprintf('x_missing_%d', i), 'real');
                unknownVars(end + 1, 1) = nodes(i, 1); %#ok<AGROW>
            else
                nodes(i, 1) = sym(evaluateCoordinate(entries{i, 1}, nodes, i, variableDefs, evalMode));
            end

            if isBlankCell(entries{i, 2})
                nodes(i, 2) = sym(sprintf('y_missing_%d', i), 'real');
                unknownVars(end + 1, 1) = nodes(i, 2); %#ok<AGROW>
            else
                nodes(i, 2) = sym(evaluateCoordinate(entries{i, 2}, nodes, i, variableDefs, evalMode));
            end
        end
    end

    function nodesOut = finalizeResolvedNodes(symbolicNodes, mode)
        if strcmp(mode, 'symbolic')
            nodesOut = symbolicNodes;
        else
            nodesOut = double(vpa(symbolicNodes));
        end
    end

    function values = extractSolutionValues(solutions, unknownVars)
        values = [];
        if isempty(solutions)
            return;
        end
        if isstruct(solutions)
            values = sym(zeros(size(unknownVars)));
            for idx = 1:numel(unknownVars)
                fieldName = char(unknownVars(idx));
                if ~isfield(solutions, fieldName)
                    values = [];
                    return;
                end
                fieldVal = solutions.(fieldName);
                if isempty(fieldVal)
                    values = [];
                    return;
                end
                values(idx) = fieldVal(1);
            end
            return;
        end
        if isa(solutions, 'sym') && numel(solutions) >= numel(unknownVars)
            values = solutions(1:numel(unknownVars));
        end
    end

    function [commonNode, otherNode1, otherNode2] = sharedNodesForAngleConstraint(elements, elem1, elem2, rowIdx)
        nodes1 = elements(elem1, 1:2);
        nodes2 = elements(elem2, 1:2);
        common = intersect(nodes1, nodes2);
        if numel(common) ~= 1
            error('Angle constraint %d: Member %d and Member %d must have exactly one common node.', rowIdx, elem1, elem2);
        end
        commonNode = common(1);
        otherNode1 = nodes1(nodes1 ~= commonNode);
        otherNode2 = nodes2(nodes2 ~= commonNode);
    end

    function constraints = sanitizeAngleConstraintTable(data, elements, variableDefs, mode)
        if nargin < 3
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 4
            mode = 'numeric';
        end
        data = getCellMatrix(data, 3);
        keep = false(size(data, 1), 1);
        for r = 1:size(data, 1)
            keep(r) = any(~cellfun(@isBlankCell, data(r, :)));
        end
        filtered = data(keep, :);
        constraints = struct('elem1', cell(size(filtered, 1), 1), 'elem2', cell(size(filtered, 1), 1), 'angle', cell(size(filtered, 1), 1));
        for r = 1:size(filtered, 1)
            elem1 = cellToRoundedInt(filtered{r, 1});
            elem2 = cellToRoundedInt(filtered{r, 2});
            if ~isfinite(elem1) || ~isfinite(elem2)
                error('Angle table: row %d requires two valid member numbers.', r);
            end
            if isBlankCell(filtered{r, 3})
                error('Angle table: row %d requires an angle value or an angle variable.', r);
            end
            if elem1 < 1 || elem1 > size(elements, 1) || elem2 < 1 || elem2 > size(elements, 1)
                error('Angle table: row %d references an invalid member.', r);
            end
            if elem1 == elem2
                error('Angle table: row %d requires two different members.', r);
            end
            constraints(r).elem1 = elem1;
            constraints(r).elem2 = elem2;
            constraints(r).angle = evaluateEntryValue(filtered{r, 3}, variableDefs, mode);
        end
    end

    function tf = hasActiveAngleConstraints(data)
        data = getCellMatrix(data, 3);
        tf = false;
        for r = 1:size(data, 1)
            if any(~cellfun(@isBlankCell, data(r, :)))
                tf = true;
                return;
            end
        end
    end

    function value = evaluateCoordinate(entry, nodesSoFar, currentRow, variableDefs, mode)
        if nargin < 4
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 5
            mode = 'numeric';
        end
        if isnumeric(entry) || islogical(entry)
            value = double(entry);
            return;
        end

        if isstring(entry)
            entry = char(entry);
        end

        if isempty(entry)
            error('Node %d ist unvollstaendig.', currentRow);
        end

        expr = strtrim(char(entry));
        if isempty(expr)
            error('Node %d ist unvollstaendig.', currentRow);
        end

        for k = 1:(currentRow - 1)
            expr = regexprep(expr, sprintf('(?<![A-Za-z0-9_])x%d(?![A-Za-z0-9_])', k), ['(' formatNumber(nodesSoFar(k, 1)) ')']);
            expr = regexprep(expr, sprintf('(?<![A-Za-z0-9_])y%d(?![A-Za-z0-9_])', k), ['(' formatNumber(nodesSoFar(k, 2)) ')']);
        end

        expr = replacePolarHelpers(expr, nodesSoFar, currentRow, variableDefs, mode);

        value = evaluateScalarExpression(expr, variableDefs, mode);
        if isempty(value) || ~isscalar(value)
            error(['Coordinate expression "' expr '" could not be evaluated. ' ...
                'Allowed are numbers, x1/y1, and px(...), py(...).']);
        end
        if strcmp(mode, 'numeric')
            value = double(value);
        else
            value = sym(value);
        end
    end

    function expr = replacePolarHelpers(expr, nodesSoFar, currentRow, variableDefs, mode)
        pattern = 'p([xy])\(\s*([0-9]+)\s*,\s*([0-9]+)\s*,\s*([^,()]+)\s*,\s*([^)]+)\)';
        while true
            [startIdx, endIdx, tokens] = regexp(expr, pattern, 'start', 'end', 'tokens', 'once');
            if isempty(startIdx)
                break;
            end

            axisName = lower(tokens{1});
            startNode = str2double(tokens{2});
            refNode = str2double(tokens{3});
            lengthVal = evaluateScalarExpression(tokens{4}, variableDefs, mode);
            angleDeg = evaluateScalarExpression(tokens{5}, variableDefs, mode);

            if any(~isfinite([startNode, refNode]))
                error('px/py in Node %d contains unvalid Argumente.', currentRow);
            end
            if startNode < 1 || refNode < 1 || startNode >= currentRow || refNode >= currentRow
                error('px/py in node %d may only reference already defined nodes.', currentRow);
            end
            if strcmp(mode, 'numeric') && (any(~isfinite(nodesSoFar(startNode, :))) || any(~isfinite(nodesSoFar(refNode, :))))
                error('px/py in Node %d verweist auf unvollstaendige reference nodes.', currentRow);
            end

            basePoint = nodesSoFar(startNode, :);
            refPoint = nodesSoFar(refNode, :);
            direction = refPoint - basePoint;
            if strcmp(mode, 'numeric') && norm(direction) < 1e-12
                error('px/py in node %d uses two identical reference points.', currentRow);
            end

            baseAngle = atan2(direction(2), direction(1));
            if strcmp(mode, 'symbolic')
                absoluteAngle = baseAngle + sym(pi) / 180 * angleDeg;
            else
                absoluteAngle = baseAngle + deg2rad(angleDeg);
            end
            newPoint = basePoint + lengthVal * [cos(absoluteAngle), sin(absoluteAngle)];
            if axisName == 'x'
                replacement = ['(' formatNumber(newPoint(1)) ')'];
            else
                replacement = ['(' formatNumber(newPoint(2)) ')'];
            end

            expr = [expr(1:startIdx - 1), replacement, expr(endIdx + 1:end)];
        end
    end

    function value = evaluateScalarExpression(expr, variableDefs, mode)
        if nargin < 2
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 3
            mode = 'numeric';
        end
        if strcmp(mode, 'numeric')
            expr = substituteVariablePreviewValues(expr, variableDefs, false);
            value = str2double(expr);
            if isnan(value)
                value = str2num(expr); %#ok<ST2NM>
            end
        elseif strcmp(mode, 'preview')
            expr = substituteVariablePreviewValues(expr, variableDefs, true);
            value = str2double(expr);
            if isnan(value)
                value = str2num(expr); %#ok<ST2NM>
            end
        else
            value = str2sym(expr);
        end
    end

    function matrix = sanitizeIntegerMatrix(data, nCols, label)
        matrix = sanitizeNumericMatrix(data, nCols, label);
        if any(abs(matrix - round(matrix)) > 1e-9, 'all')
            error('%s contains values that must be integers.', label);
        end
        matrix = round(matrix);
    end

    function defs = sanitizeMaterialTable(data, label, variableDefs, mode)
        if nargin < 3
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 4
            mode = 'numeric';
        end
        data = getCellMatrix(data, 5);
        if isempty(data)
            defs = cell(0, 5);
            return;
        end

        defs = cell(size(data, 1), 5);
        for r = 1:size(data, 1)
            typeVal = normalizeSectionType(data{r, 1});
            dOrB = evaluateEntryValue(data{r, 2}, variableDefs, mode);
            tVal = evaluateEntryValue(data{r, 3}, variableDefs, mode);
            hVal = evaluateEntryValue(data{r, 4}, variableDefs, mode);
            eVal = evaluateEntryValue(data{r, 5}, variableDefs, mode);

            if strcmp(mode, 'numeric') && (~isfinite(eVal) || eVal <= 0)
                error('%s: row %d has no valid Young''s modulus > 0.', label, r);
            elseif strcmp(mode, 'symbolic') && ~isAlways(eVal > 0, 'Unknown', 'false')
                error('%s: row %d requires a positive Young''s modulus.', label, r);
            end

            switch typeVal
                case 'Circular'
                    if ~isPositiveForMode(dOrB, mode)
                        error('%s: row %d requires a diameter > 0 for Circular.', label, r);
                    end
                    tVal = 0;
                    hVal = 0;
                case 'Tube'
                    if ~isPositiveForMode(dOrB, mode) || ~isPositiveForMode(tVal, mode)
                        error('%s: row %d requires D > 0 and t > 0 for Tube.', label, r);
                    end
                    if strcmp(mode, 'numeric')
                        invalidInner = dOrB - 2 * tVal <= 0;
                    else
                        invalidInner = ~isAlways(dOrB - 2 * tVal > 0, 'Unknown', 'false');
                    end
                    if invalidInner
                        error('%s: row %d has no positive inner thickness left for Tube.', label, r);
                    end
                    hVal = 0;
                case 'Rectangular'
                    if ~isPositiveForMode(dOrB, mode) || ~isPositiveForMode(hVal, mode)
                        error('%s: row %d requires b > 0 and h > 0 for Rectangular.', label, r);
                    end
                    tVal = 0;
            end

            defs(r, :) = {typeVal, dOrB, tVal, hVal, eVal};
        end
    end

    function defs = buildPreviewMaterialDefs(data, variableDefs)
        if nargin < 2
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        data = getCellMatrix(data, 5);
        defs = cell(0, 5);
        for r = 1:size(data, 1)
            typeVal = normalizeSectionType(data{r, 1});
            dOrB = tryEvaluatePreviewCell(data{r, 2}, variableDefs);
            tVal = tryEvaluatePreviewCell(data{r, 3}, variableDefs);
            hVal = tryEvaluatePreviewCell(data{r, 4}, variableDefs);
            eVal = tryEvaluatePreviewCell(data{r, 5}, variableDefs);
            if ~isfinite(eVal) || eVal <= 0
                continue;
            end
            switch typeVal
                case 'Circular'
                    if ~isfinite(dOrB) || dOrB <= 0
                        continue;
                    end
                    defs(end + 1, :) = {typeVal, dOrB, 0, 0, eVal}; %#ok<AGROW>
                case 'Tube'
                    if ~isfinite(dOrB) || dOrB <= 0 || ~isfinite(tVal) || tVal <= 0 || dOrB - 2 * tVal <= 0
                        continue;
                    end
                    defs(end + 1, :) = {typeVal, dOrB, tVal, 0, eVal}; %#ok<AGROW>
                case 'Rectangular'
                    if ~isfinite(dOrB) || dOrB <= 0 || ~isfinite(hVal) || hVal <= 0
                        continue;
                    end
                    defs(end + 1, :) = {typeVal, dOrB, 0, hVal, eVal}; %#ok<AGROW>
            end
        end
    end

    function matrix = materialDefsToMatrix(defs)
        defs = getCellMatrix(defs, 5);
        useSymbolic = any(cellfun(@(x) isa(x, 'sym'), defs(:)));
        if useSymbolic
            matrix = sym(zeros(size(defs, 1), 2));
        else
            matrix = zeros(size(defs, 1), 2);
        end
        for r = 1:size(defs, 1)
            typeVal = normalizeSectionType(defs{r, 1});
            dOrB = defs{r, 2};
            tVal = defs{r, 3};
            hVal = defs{r, 4};
            eVal = defs{r, 5};
            areaVal = computeSectionArea(typeVal, dOrB, tVal, hVal);
            matrix(r, :) = [areaVal, eVal];
        end
    end

    function areaVal = computeSectionArea(typeVal, dOrB, tVal, hVal)
        switch normalizeSectionType(typeVal)
            case 'Circular'
                areaVal = pi / 4 * dOrB^2;
            case 'Tube'
                innerD = dOrB - 2 * tVal;
                areaVal = pi / 4 * (dOrB^2 - innerD^2);
            case 'Rectangular'
                areaVal = dOrB * hVal;
            otherwise
                areaVal = NaN;
        end
    end

    function defs = sanitizeSupportTable(data, nRows, label)
        data = resizeSupportTable(getCellMatrix(data, 2), nRows);
        defs = cell(nRows, 2);
        for r = 1:nRows
            defs{r, 1} = normalizeSupportType(data{r, 1});
            defs{r, 2} = num2str(normalizeSupportAngle(data{r, 2}));
            if isempty(defs{r, 1}) || isempty(defs{r, 2})
                error('%s contains an invalid entry in row %d.', label, r);
            end
        end
    end

    function matrix = supportDefsToConstraintMatrix(defs)
        defs = getCellMatrix(defs, 2);
        matrix = false(size(defs, 1), 2);
        for r = 1:size(defs, 1)
            supportType = normalizeSupportType(defs{r, 1});
            angle = normalizeSupportAngle(defs{r, 2});
            switch supportType
                case 'Pinned Support'
                    matrix(r, :) = [true, true];
                case 'Fixed Support'
                    matrix(r, :) = [true, true];
                case 'Roller Support'
                    if mod(angle, 180) == 0
                        matrix(r, :) = [false, true];
                    else
                        matrix(r, :) = [true, false];
                    end
                otherwise
                    matrix(r, :) = [false, false];
            end
        end
    end

    function matrix = sanitizeNumericMatrix(data, nCols, label)
        data = getCellMatrix(data, nCols);
        matrix = zeros(size(data, 1), nCols);
        for r = 1:size(data, 1)
            for c = 1:nCols
                value = cellToDouble(data{r, c});
                if ~isfinite(value)
                    error('%s contains an invalid numeric value in row %d, column %d.', label, r, c);
                end
                matrix(r, c) = value;
            end
        end
    end

    function matrix = sanitizeLoadPointTable(data, label, variableDefs, mode)
        if nargin < 3
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 4
            mode = 'numeric';
        end
        data = getCellMatrix(data, 6);
        keep = false(size(data, 1), 1);
        for r = 1:size(data, 1)
            keep(r) = any(~cellfun(@(x) isempty(x) || (ischar(x) && isempty(strtrim(x))) || (isstring(x) && strlength(x) == 0), data(r, :)));
        end
        filtered = data(keep, :);

        if strcmp(mode, 'symbolic')
            matrix = sym(zeros(size(filtered, 1), 4));
        else
            matrix = zeros(size(filtered, 1), 4);
        end

        for r = 1:size(filtered, 1)
            x = evaluateEntryValue(filtered{r, 1}, variableDefs, mode);
            y = evaluateEntryValue(filtered{r, 2}, variableDefs, mode);
            fxRaw = evaluateOptionalEntry(filtered{r, 3}, variableDefs, mode);
            fyRaw = evaluateOptionalEntry(filtered{r, 4}, variableDefs, mode);
            magRaw = evaluateOptionalEntry(filtered{r, 5}, variableDefs, mode);
            angRaw = evaluateOptionalEntry(filtered{r, 6}, variableDefs, mode);

            hasComp = ~isempty(fxRaw) || ~isempty(fyRaw);
            hasPolar = ~isempty(magRaw) || ~isempty(angRaw);
            if hasComp && hasPolar
                error('%s: row %d may contain only Fx/Fy or F/angle, not both.', label, r);
            end

            usePolar = hasPolar;
            if usePolar
                if isempty(magRaw) || isempty(angRaw)
                    error('%s: row %d requires for F/Angle beide Angaben.', label, r);
                end
                if strcmp(mode, 'symbolic')
                    fx = magRaw * cos(sym(pi) / 180 * angRaw);
                    fy = magRaw * sin(sym(pi) / 180 * angRaw);
                else
                    fx = magRaw * cosd(angRaw);
                    fy = magRaw * sind(angRaw);
                end
            else
                if isempty(fxRaw)
                    fxRaw = zeroForMode(mode);
                end
                if isempty(fyRaw)
                    fyRaw = zeroForMode(mode);
                end
                fx = fxRaw;
                fy = fyRaw;
            end

            matrix(r, :) = [x, y, fx, fy];
        end
    end

    function matrix = buildPreviewLoadPoints(data, variableDefs)
        data = getCellMatrix(data, 6);
        matrix = zeros(0, 4);
        for r = 1:size(data, 1)
            try
                rowMatrix = double(sanitizeLoadPointTable(data(r, :), 'Load Table', variableDefs, 'preview'));
                if ~isempty(rowMatrix)
                    matrix(end + 1:end + size(rowMatrix, 1), :) = rowMatrix;
                end
            catch
            end
        end
    end

    function out = getCellMatrix(data, nCols)
        if isempty(data)
            out = cell(0, nCols);
            return;
        end
        if iscell(data)
            out = data;
        else
            out = num2cell(data);
        end
        if size(out, 2) ~= nCols
            error('Internal error: unexpected number of columns in a table.');
        end
    end

    function value = cellToDouble(entry)
        if isnumeric(entry) || islogical(entry)
            value = double(entry);
            return;
        end
        if isstring(entry)
            entry = char(entry);
        end
        if isempty(entry)
            value = NaN;
            return;
        end
        txt = strtrim(char(entry));
        if isempty(txt)
            value = NaN;
            return;
        end
        value = str2double(txt);
    end

    function tf = isBlankCell(value)
        if isstring(value)
            value = char(value);
        end
        if isempty(value)
            tf = true;
            return;
        end
        if ischar(value)
            tf = isempty(strtrim(value));
        else
            tf = false;
        end
    end

    function tf = isFilledText(value)
        if isstring(value)
            value = char(value);
        end
        tf = ~(isempty(value) || (ischar(value) && isempty(strtrim(value))));
    end

    function tf = isFilledCellValue(entries)
        tf = cellfun(@(x) isFilledText(string(x)), entries);
    end

    function value = cellToRoundedInt(entry)
        value = cellToDouble(entry);
        if isfinite(value)
            value = round(value);
        end
    end

    function variableDefs = sanitizeVariableTable(data)
        data = getCellMatrix(data, 2);
        names = {};
        previewValues = [];
        for r = 1:size(data, 1)
            nameVal = strtrim(char(string(data{r, 1})));
            if isempty(nameVal)
                continue;
            end
            if isempty(regexp(nameVal, '^[A-Za-z]\w*$', 'once'))
                error('Variable name "%s" is invalid. Allowed are names such as a, b, h1.', nameVal);
            end
            if ismember(lower(nameVal), lower(names))
                error('Die Variable "%s" ist doppelt vorhanden.', nameVal);
            end
            previewVal = cellToDouble(data{r, 2});
            names{end + 1, 1} = nameVal; %#ok<AGROW>
            previewValues(end + 1, 1) = previewVal; %#ok<AGROW>
        end
        variableDefs = struct('names', {names}, 'previewValues', previewValues);
    end

    function variableDefs = collectVariableDefs(raw)
        explicitDefs = sanitizeVariableTable(raw.variables);
        names = {};
        previewValues = [];

        candidateCells = {};
        candidateCells = [candidateCells; raw.nodeEntries(:)];
        candidateCells = [candidateCells; raw.angleConstraints(:)];
        candidateCells = [candidateCells; raw.loadPoints(:)];
        materialCells = getCellMatrix(raw.materials, 5);
        if ~isempty(materialCells)
            materialValueCells = materialCells(:, 2:5);
            candidateCells = [candidateCells; materialValueCells(:)];
        end

        reserved = {'px', 'py', 'sin', 'cos', 'tan', 'sqrt', 'exp', 'log', 'pi'};
        for idx = 1:numel(candidateCells)
            entry = candidateCells{idx};
            if isnumeric(entry) || islogical(entry) || isempty(entry)
                continue;
            end
            txt = strtrim(char(string(entry)));
            if isempty(txt)
                continue;
            end
            tokens = regexp(txt, '(?<![A-Za-z0-9_])([A-Za-z]\w*)(?![A-Za-z0-9_])', 'tokens');
            for t = 1:numel(tokens)
                nameVal = tokens{t}{1};
                if any(strcmpi(nameVal, reserved))
                    continue;
                end
                if ~isempty(regexp(nameVal, '^[xy]\d+$', 'once'))
                    continue;
                end
                if ~ismember(lower(nameVal), lower(names))
                    names{end + 1, 1} = nameVal; %#ok<AGROW>
                    previewValues(end + 1, 1) = previewValueFor(nameVal); %#ok<AGROW>
                end
            end
        end
        variableDefs = struct('names', {names}, 'previewValues', previewValues);

        function previewVal = previewValueFor(nameVal)
            previewVal = NaN;
            matchIdx = find(strcmpi(nameVal, explicitDefs.names), 1);
            if ~isempty(matchIdx) && matchIdx <= numel(explicitDefs.previewValues)
                previewVal = explicitDefs.previewValues(matchIdx);
            end
        end
    end

    function names = collectAngleVariableNames(raw)
        names = {};
        candidateCells = {};
        if isfield(raw, 'angleConstraints')
            angleCells = getCellMatrix(raw.angleConstraints, 3);
            if ~isempty(angleCells)
                candidateCells = [candidateCells; angleCells(:, 3)];
            end
        end
        if isfield(raw, 'loadPoints')
            loadCells = getCellMatrix(raw.loadPoints, 6);
            if ~isempty(loadCells)
                candidateCells = [candidateCells; loadCells(:, 6)];
            end
        end

        reserved = {'px', 'py', 'sin', 'cos', 'tan', 'sqrt', 'exp', 'log', 'pi'};
        for idx = 1:numel(candidateCells)
            entry = candidateCells{idx};
            if isnumeric(entry) || islogical(entry) || isempty(entry)
                continue;
            end
            txt = strtrim(char(string(entry)));
            if isempty(txt)
                continue;
            end
            tokens = regexp(txt, '(?<![A-Za-z0-9_])([A-Za-z]\w*)(?![A-Za-z0-9_])', 'tokens');
            for t = 1:numel(tokens)
                nameVal = tokens{t}{1};
                if any(strcmpi(nameVal, reserved))
                    continue;
                end
                if ~ismember(lower(nameVal), lower(names))
                    names{end + 1, 1} = nameVal; %#ok<AGROW>
                end
            end
        end
    end

    function value = evaluateEntryValue(entry, variableDefs, mode)
        if nargin < 2
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 3
            mode = 'numeric';
        end
        if isnumeric(entry) || islogical(entry)
            if strcmp(mode, 'symbolic')
                value = sym(double(entry));
            else
                value = double(entry);
            end
            return;
        end
        if isstring(entry)
            entry = char(entry);
        end
        if isempty(entry) || isempty(strtrim(char(entry)))
            if strcmp(mode, 'symbolic')
                value = sym(0);
            else
                value = NaN;
            end
            return;
        end
        value = evaluateScalarExpression(strtrim(char(entry)), variableDefs, mode);
    end

    function value = evaluateOptionalEntry(entry, variableDefs, mode)
        if nargin < 2
            variableDefs = sanitizeVariableTable(cell(0, 2));
        end
        if nargin < 3
            mode = 'numeric';
        end
        if (ischar(entry) || isstring(entry)) && isempty(strtrim(char(entry)))
            value = [];
            return;
        end
        if isempty(entry)
            value = [];
            return;
        end
        value = evaluateEntryValue(entry, variableDefs, mode);
    end

    function value = tryEvaluatePreviewCell(entry, variableDefs)
        try
            value = evaluateEntryValue(entry, variableDefs, 'preview');
            if isempty(value) || ~isscalar(value)
                value = NaN;
            end
        catch
            value = NaN;
        end
    end

    function expr = substituteVariablePreviewValues(expr, variableDefs, useFallbackOne)
        if nargin < 3
            useFallbackOne = false;
        end
        if isempty(variableDefs.names)
            return;
        end
        for idx = 1:numel(variableDefs.names)
            if idx <= numel(variableDefs.previewValues) && isfinite(variableDefs.previewValues(idx))
                replacementValue = formatNumber(variableDefs.previewValues(idx));
            elseif useFallbackOne
                replacementValue = '1';
            else
                continue;
            end
            pattern = sprintf('(?<![A-Za-z0-9_])%s(?![A-Za-z0-9_])', regexptranslate('escape', variableDefs.names{idx}));
            expr = regexprep(expr, pattern, replacementValue);
        end
    end

    function exprOut = substitutePreviewIntoSym(exprIn, variableDefs, useFallbackOne)
        exprOut = exprIn;
        if nargin < 3
            useFallbackOne = false;
        end
        if ~isa(exprOut, 'sym') || isempty(variableDefs.names)
            return;
        end
        symNames = sym.empty(1, 0);
        replaceVals = [];
        for idx = 1:numel(variableDefs.names)
            if idx <= numel(variableDefs.previewValues) && isfinite(variableDefs.previewValues(idx))
                symNames(end + 1) = sym(variableDefs.names{idx}); %#ok<AGROW>
                replaceVals(end + 1) = variableDefs.previewValues(idx); %#ok<AGROW>
            elseif useFallbackOne
                symNames(end + 1) = sym(variableDefs.names{idx}); %#ok<AGROW>
                replaceVals(end + 1) = 1; %#ok<AGROW>
            end
        end
        if ~isempty(symNames)
            exprOut = subs(exprOut, symNames, replaceVals);
        end
    end

    function tf = isPositiveForMode(value, mode)
        if strcmp(mode, 'numeric')
            tf = isfinite(value) && value > 0;
        else
            tf = isAlways(value > 0, 'Unknown', 'false');
        end
    end

    function value = zeroForMode(mode)
        if strcmp(mode, 'symbolic')
            value = sym(0);
        else
            value = 0;
        end
    end

    function value = cellToLogicalPreview(entry)
        if islogical(entry)
            value = entry;
            return;
        end
        if isnumeric(entry)
            value = logical(entry);
            return;
        end
        if isempty(entry)
            value = false;
            return;
        end
        textValue = strtrim(char(entry));
        value = any(strcmpi(textValue, {'1', 'true', 'ja', 'x'}));
    end

    function supportType = normalizeSupportType(entry)
        if isstring(entry)
            entry = char(entry);
        end
        if isempty(entry)
            supportType = 'No Support';
            return;
        end
        textValue = strtrim(char(entry));
        if isempty(textValue)
            supportType = 'No Support';
        elseif any(strcmpi(textValue, {'Pinned Support', 'Festlager'}))
            supportType = 'Pinned Support';
        elseif any(strcmpi(textValue, {'Roller Support', 'Loslager'}))
            supportType = 'Roller Support';
        elseif any(strcmpi(textValue, {'Fixed Support', 'Einspannung'}))
            supportType = 'Fixed Support';
        else
            supportType = 'No Support';
        end
    end

    function angle = normalizeSupportAngle(entry)
        angle = cellToDouble(entry);
        if ~isfinite(angle)
            angle = 0;
        end
        angle = mod(90 * round(angle / 90), 360);
    end

    function sectionType = normalizeSectionType(entry)
        if isstring(entry)
            entry = char(entry);
        end
        if isempty(entry)
            sectionType = 'Circular';
            return;
        end
        textValue = strtrim(char(entry));
        if any(strcmpi(textValue, {'Circular', 'Rund'}))
            sectionType = 'Circular';
        elseif any(strcmpi(textValue, {'Tube', 'Pipe', 'Rohr'}))
            sectionType = 'Tube';
        elseif any(strcmpi(textValue, {'Rectangular', 'Viereck', 'Rechteck'}))
            sectionType = 'Rectangular';
        else
            sectionType = 'Circular';
        end
    end

    function data = resizeSupportTable(data, rows)
        data = getCellMatrix(data, 2);
        defaults = {'No Support', '0'};
        if size(data, 1) < rows
            for r = size(data, 1) + 1:rows
                data(r, :) = defaults;
            end
        elseif size(data, 1) > rows
            data(rows + 1:end, :) = [];
        end
        for r = 1:size(data, 1)
            if isempty(data{r, 1})
                data{r, 1} = defaults{1};
            end
            if isempty(data{r, 2})
                data{r, 2} = defaults{2};
            end
        end
    end

    function points = rotateAndTranslate(localPoints, angleDeg, origin)
        theta = deg2rad(angleDeg);
        rot = [cos(theta), -sin(theta); sin(theta), cos(theta)];
        points = (rot * localPoints.').';
        points(:, 1) = points(:, 1) + origin(1);
        points(:, 2) = points(:, 2) + origin(2);
    end

    function data = getTableDataAsCell(tableHandle)
        data = get(tableHandle, 'Data');
        if isempty(data)
            data = cell(0, numel(get(tableHandle, 'ColumnName')));
            return;
        end
        if ~iscell(data)
            data = num2cell(data);
        end
    end

    function elemData = removeNodeFromElementData(elemData, deletedNode)
        elemData = getCellMatrix(elemData, 3);
        keep = true(size(elemData, 1), 1);

        for r = 1:size(elemData, 1)
            i = cellToRoundedInt(elemData{r, 1});
            j = cellToRoundedInt(elemData{r, 2});

            if any(isnan([i, j])) || i == deletedNode || j == deletedNode
                keep(r) = false;
                continue;
            end
            if i > deletedNode
                elemData{r, 1} = i - 1;
            end
            if j > deletedNode
                elemData{r, 2} = j - 1;
            end
        end

        elemData = elemData(keep, :);
    end

    function out = cellToNumericIfPossible(data, emptyValue)
        nCols = size(data, 2);
        data = getCellMatrix(data, nCols);
        out = zeros(size(data));
        for r = 1:size(data, 1)
            for c = 1:size(data, 2)
                val = cellToDouble(data{r, c});
                if isnan(val)
                    val = emptyValue;
                end
                out(r, c) = val;
            end
        end
    end

    function txt = formatNumber(value)
        if isa(value, 'sym')
            txt = char(value);
        else
            txt = sprintf('%.15g', value);
        end
    end

    function updateInfo(message)
        set(ui.infoBox, 'String', message);
    end
end















