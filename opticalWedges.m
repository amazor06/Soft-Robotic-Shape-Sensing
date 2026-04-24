function opticalWedgeApp()
% OPTICALWEDGEAPP  (performance-optimised)
% Key changes vs original:
%   - segmentLengthInsideSolid replaced with analytic slab intersection
%     (eliminates 180-sample Monte-Carlo loop per ray entirely)
%   - runDetectorSimulation fully vectorised - no inner loops
%   - Sensitivity finite-differences use a tiny dedicated scalar fast-path
%     (no ray struct allocation, much smaller density)
%   - Ray drawing batched into single plot3 call with NaN separators
%   - Static geometry (LED, detectors, axes labels) drawn once and cached;
%     only wedge patches and ray lines are updated on each redraw
%   - drawnow limitrate throttles repaints during slider drag

    close all force;
    clc;

    % ------------------------------------------------------------------
    % Initial state
    % ------------------------------------------------------------------
    state.shiftZ      = 0.00;
    state.shiftY      = 0.00;
    state.alpha       = 2.00;
    state.rayDensity  = 7;
    state.showBlocked = true;

    % ------------------------------------------------------------------
    % Handles for objects that are updated (not recreated) each redraw
    % ------------------------------------------------------------------
    h.leftWedgePatch  = [];
    h.rightWedgePatch = [];
    h.incomingLines   = [];
    h.outgoingLinesL  = [];
    h.outgoingLinesR  = [];
    h.frontLeftWedge  = [];
    h.frontRightWedge = [];

    % ------------------------------------------------------------------
    % Build UI
    % ------------------------------------------------------------------
    fig = uifigure( ...
        'Name', 'Optical Wedge Simulator', ...
        'Color', [0.92 0.94 0.96], ...
        'Position', [60 40 1560 920]);

    side = uipanel(fig, ...
        'Title', 'Model Information', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [10 10 470 900]);

    main = uipanel(fig, ...
        'Title', 'Geometry and Rays', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.94 0.95 0.97], ...
        'Position', [490 10 1060 900]);

    ax3d = uiaxes(main, ...
        'Position', [20 300 660 570], ...
        'Box', 'on', ...
        'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', ...
        'Color', [0.95 0.96 0.98], ...
        'FontName', 'Helvetica');
    title(ax3d, '3D View');
    xlabel(ax3d, 'X'); ylabel(ax3d, 'Y'); zlabel(ax3d, 'Z');
    view(ax3d, 12, 18);
    axis(ax3d, 'equal');

    axFront = uiaxes(main, ...
        'Position', [700 300 340 570], ...
        'Box', 'on', ...
        'XGrid', 'on', 'YGrid', 'on', ...
        'Color', [0.95 0.96 0.98], ...
        'FontName', 'Helvetica');
    title(axFront, 'Front View (mirrored to match 3D)');
    xlabel(axFront, '-Y'); ylabel(axFront, 'Z');
    axis(axFront, 'equal');

    ctrl = uipanel(main, ...
        'Title', 'Controls', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [20 20 1020 250]);

    % ------------------------------------------------------------------
    % Sidebar
    % ------------------------------------------------------------------
    uilabel(side, ...
        'Text', 'Extracted Data', ...
        'FontSize', 22, 'FontWeight', 'bold', ...
        'Position', [18 840 220 30]);

    cardsPanel = uipanel(side, ...
        'Title', '', 'BorderType', 'none', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [15 15 440 800]);

    metricY = 700;
    cardH   = 58;
    gap     = 8;

    card1 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'Right Transmission', '0.0000', 'Fraction of light reaching right detector  [0-1, Beer-Lambert weighted]'); metricY = metricY-(cardH+gap);
    card2 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'Left Transmission',  '0.0000', 'Fraction of light reaching left detector  [0-1, Beer-Lambert weighted]');  metricY = metricY-(cardH+gap);
    card3 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'Differential Signal','0.0000', 'Right minus left transmission  [0-1, positive = more light on right]');    metricY = metricY-(cardH+gap);
    card4 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'Right Mean Path',    '0.0000', 'Weighted avg. ray path length through wedge material to right detector  [scene units]'); metricY = metricY-(cardH+gap);
    card5 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'Left Mean Path',     '0.0000', 'Weighted avg. ray path length through wedge material to left detector  [scene units]');  metricY = metricY-(cardH+gap);
    card6 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'Right Blocked Frac.','0.0000', 'Fraction of rays with T < 0.5 reaching right detector  [0-1]'); metricY = metricY-(cardH+gap);
    card7 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'Left Blocked Frac.', '0.0000', 'Fraction of rays with T < 0.5 reaching left detector  [0-1]');

    sensPanel = uipanel(cardsPanel, ...
        'Title', '', 'BorderType', 'none', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [0 0 440 92]);

    sens1 = makeMiniMetricCard(sensPanel, [0   46 215 42], 'dT_R / dZ  [1/u]', '0.0000');
    sens2 = makeMiniMetricCard(sensPanel, [225 46 215 42], 'dT_L / dZ  [1/u]', '0.0000');
    sens3 = makeMiniMetricCard(sensPanel, [0    0 215 42], 'dT_R / dY  [1/u]', '0.0000');
    sens4 = makeMiniMetricCard(sensPanel, [225  0 215 42], 'dT_L / dY  [1/u]', '0.0000');

    % ------------------------------------------------------------------
    % Controls
    % ------------------------------------------------------------------
    uilabel(ctrl, 'Text', 'Vertical Wedge Shift (Z)',   'FontWeight', 'bold', 'Position', [20 185 160 22]);
    shiftZSlider = uislider(ctrl, 'Limits', [-1 1], 'Value', state.shiftZ,     'MajorTicks', -1:0.5:1, 'Position', [190 195 260 3]);
    shiftZValue  = uilabel(ctrl,  'Text', sprintf('%.2f', state.shiftZ),        'Position', [460 185 60 22]);

    uilabel(ctrl, 'Text', 'Horizontal Wedge Shift (Y)', 'FontWeight', 'bold', 'Position', [20 130 170 22]);
    shiftYSlider = uislider(ctrl, 'Limits', [-1 1], 'Value', state.shiftY,     'MajorTicks', -1:0.5:1, 'Position', [190 140 260 3]);
    shiftYValue  = uilabel(ctrl,  'Text', sprintf('%.2f', state.shiftY),        'Position', [460 130 60 22]);

    uilabel(ctrl, 'Text', 'Attenuation alpha', 'FontWeight', 'bold', 'Position', [20 75 120 22]);
    alphaSlider  = uislider(ctrl, 'Limits', [0 10], 'Value', state.alpha,      'MajorTicks', 0:2:10, 'Position', [190 85 260 3]);
    alphaValue   = uilabel(ctrl,  'Text', sprintf('%.2f', state.alpha),         'Position', [460 75 60 22]);

    uilabel(ctrl, 'Text', 'Ray Density', 'FontWeight', 'bold', 'Position', [20 20 100 22]);
    densitySlider = uislider(ctrl, 'Limits', [5 11], 'Value', state.rayDensity, 'MajorTicks', 5:11, 'MinorTicks', [], 'Position', [190 30 260 3]);
    densityValue  = uilabel(ctrl,  'Text', sprintf('%d', state.rayDensity),      'Position', [460 20 60 22]);

    blockedCheck = uicheckbox(ctrl, 'Text', 'Show blocked outgoing rays', 'Value', state.showBlocked, 'Position', [560 185 190 22]);

    uibutton(ctrl, 'Text', 'Reset View',                       'Position', [560  70 120 34], 'ButtonPushedFcn', @(~,~) resetView());

    % ------------------------------------------------------------------
    % Draw static geometry once, cache handles
    % ------------------------------------------------------------------
    initStaticGeometry();

    % Callbacks
    shiftZSlider.ValueChangedFcn  = @(~,~) redraw();
    shiftYSlider.ValueChangedFcn  = @(~,~) redraw();
    alphaSlider.ValueChangedFcn   = @(~,~) redraw();
    densitySlider.ValueChangedFcn = @(~,~) redraw();
    blockedCheck.ValueChangedFcn  = @(~,~) redraw();

    redraw();

    % ==================================================================
    % Static geometry - drawn once, never recreated
    % ==================================================================
    function initStaticGeometry()
        hold(ax3d, 'on');
        grid(ax3d, 'on');
        axis(ax3d, [-5.5 5.2 -2.4 2.4 -2.0 2.0]);
        daspect(ax3d, [1 1 1]);

        % Coordinate arrows
        plot3(ax3d, [0 1.2],[0 0],[0 0], 'r-', 'LineWidth', 1.8);
        plot3(ax3d, [0 0],[0 1.2],[0 0], 'g-', 'LineWidth', 1.8);
        plot3(ax3d, [0 0],[0 0],[0 1.2], 'b-', 'LineWidth', 1.8);
        text(ax3d, 1.28, 0, 0, 'X', 'Color', 'r', 'FontWeight', 'bold');
        text(ax3d, 0, 1.28, 0, 'Y', 'Color', 'g', 'FontWeight', 'bold');
        text(ax3d, 0, 0, 1.28, 'Z', 'Color', 'b', 'FontWeight', 'bold');

        % LED
        [Xs,Ys,Zs] = cylinder(0.16, 28);
        surf(ax3d, Xs*0.46-4.8, Ys*0.46, Zs*0.32-0.16, ...
            'FaceColor', [0.85 0.30 0.26], 'EdgeColor', 'none', 'FaceLighting', 'gouraud');

        % Fixed detectors
        drawBlock(ax3d, 3.8, -0.62, 0, 0.12, 0.82, 0.82, [0.13 0.16 0.20]);
        drawBlock(ax3d, 3.8,  0.68, 0, 0.12, 0.95, 0.82, [0.13 0.16 0.20]);

        % Placeholder wedge patches - vertices updated each redraw
        F6 = [1 2 3 4; 1 5 6 2; 4 3 7 8; 1 4 8 5; 2 6 7 3; 5 6 7 8];
        h.leftWedgePatch  = patch(ax3d, 'Vertices', zeros(8,3), 'Faces', F6, ...
            'FaceColor', [0.81 0.84 0.87], 'EdgeColor', [0.45 0.48 0.52], 'FaceAlpha', 1, 'LineWidth', 1);
        h.rightWedgePatch = patch(ax3d, 'Vertices', zeros(8,3), 'Faces', F6, ...
            'FaceColor', [0.81 0.84 0.87], 'EdgeColor', [0.45 0.48 0.52], 'FaceAlpha', 1, 'LineWidth', 1);

        % Placeholder batched ray lines
        h.incomingLines  = plot3(ax3d, NaN, NaN, NaN, '-', 'Color', [0.45 0.58 0.72], 'LineWidth', 0.35);
        h.outgoingLinesL = plot3(ax3d, NaN, NaN, NaN, '-', 'Color', [0.90 0.70 0.30], 'LineWidth', 0.8);
        h.outgoingLinesR = plot3(ax3d, NaN, NaN, NaN, '-', 'Color', [0.90 0.70 0.30], 'LineWidth', 0.8);

        % Front view static items
        hold(axFront, 'on');
        grid(axFront, 'on');
        axis(axFront, [-1.8 1.8 -1.8 1.8]);
        daspect(axFront, [1 1 1]);

        rectangle(axFront, 'Position', [ 0.62-0.82/2, -0.41, 0.82, 0.82], ...
            'FaceColor', [0.13 0.16 0.20], 'EdgeColor', 'k');
        rectangle(axFront, 'Position', [-0.68-0.95/2, -0.41, 0.95, 0.82], ...
            'FaceColor', [0.13 0.16 0.20], 'EdgeColor', 'k');
        plot(axFront, 0, 0, 'o', 'MarkerFaceColor', [0.85 0.30 0.26], 'MarkerEdgeColor', 'k', 'MarkerSize', 7);
        text(axFront, -1.65, 1.55, 'LED reference', 'FontSize', 11);
        title(axFront, 'Front View (-Y vs Z)');

        % Movable wedge outlines in front view
        h.frontLeftWedge  = rectangle(axFront, 'Position', [0 0 1 1], ...
            'FaceColor', [0.81 0.84 0.87], 'EdgeColor', [0.35 0.40 0.45], 'LineWidth', 1.3);
        h.frontRightWedge = rectangle(axFront, 'Position', [0 0 1 1], ...
            'FaceColor', [0.81 0.84 0.87], 'EdgeColor', [0.35 0.40 0.45], 'LineWidth', 1.3);
    end

    % ==================================================================
    function resetView()
        % 1. Reset UI Sliders to initial state values
        shiftZSlider.Value = 0.00;
        shiftYSlider.Value = 0.00;
        alphaSlider.Value  = 2.00;
        densitySlider.Value = 7;
        blockedCheck.Value  = true;
        
        % 2. Reset the 3D Camera angle
        view(ax3d, 12, 18);
        axis(ax3d, 'equal');
        
        % 3. Run the redraw function to sync the logic and labels
        redraw();
    end

    % ==================================================================
    function redraw()
        state.shiftZ      = shiftZSlider.Value;
        state.shiftY      = shiftYSlider.Value;
        state.alpha       = alphaSlider.Value;
        state.rayDensity  = round(densitySlider.Value);
        state.showBlocked = blockedCheck.Value;

        shiftZValue.Text  = sprintf('%.2f', state.shiftZ);
        shiftYValue.Text  = sprintf('%.2f', state.shiftY);
        alphaValue.Text   = sprintf('%.2f', state.alpha);
        densityValue.Text = sprintf('%d',   state.rayDensity);

        sim = simulateAtShift(state.shiftZ, state.shiftY, state.alpha, state.rayDensity);

        % Sensitivity via scalar fast-path (no ray struct, fixed small density)
        eps_fd = 0.03;
        fd     = 5;
        SR_Zm = scalarTransmission(state.shiftZ-eps_fd, state.shiftY, state.alpha, fd, true);
        SR_Zp = scalarTransmission(state.shiftZ+eps_fd, state.shiftY, state.alpha, fd, true);
        SL_Zm = scalarTransmission(state.shiftZ-eps_fd, state.shiftY, state.alpha, fd, false);
        SL_Zp = scalarTransmission(state.shiftZ+eps_fd, state.shiftY, state.alpha, fd, false);
        SR_Ym = scalarTransmission(state.shiftZ, state.shiftY-eps_fd, state.alpha, fd, true);
        SR_Yp = scalarTransmission(state.shiftZ, state.shiftY+eps_fd, state.alpha, fd, true);
        SL_Ym = scalarTransmission(state.shiftZ, state.shiftY-eps_fd, state.alpha, fd, false);
        SL_Yp = scalarTransmission(state.shiftZ, state.shiftY+eps_fd, state.alpha, fd, false);

        SR = sim.left.transmission;
        SL = sim.right.transmission;

        setMetricCard(card1, 'Right Transmission', SR, 'Fraction of light reaching right detector  [0-1, Beer-Lambert weighted]');
        setMetricCard(card2, 'Left Transmission',  SL, 'Fraction of light reaching left detector  [0-1, Beer-Lambert weighted]');
        setMetricCard(card3, 'Differential Signal', SR-SL, 'Right minus left transmission  [0-1, positive = more light on right]');
        setMetricCard(card4, 'Right Mean Path',    sim.left.avgPathLength,      'Weighted avg. ray path length through wedge material to right detector  [scene units]');
        setMetricCard(card5, 'Left Mean Path',     sim.right.avgPathLength,     'Weighted avg. ray path length through wedge material to left detector  [scene units]');
        setMetricCard(card6, 'Right Blocked Frac.', sim.left.blockedFraction,   'Fraction of rays with T < 0.5 reaching right detector  [0-1]');
        setMetricCard(card7, 'Left Blocked Frac.',  sim.right.blockedFraction,  'Fraction of rays with T < 0.5 reaching left detector  [0-1]');

        setMiniMetricCard(sens1, 'dT_R / dZ  [1/u]', (SR_Zp - SR_Zm) / (2*eps_fd));
        setMiniMetricCard(sens2, 'dT_L / dZ  [1/u]', (SL_Zp - SL_Zm) / (2*eps_fd));
        setMiniMetricCard(sens3, 'dT_R / dY  [1/u]', (SR_Yp - SR_Ym) / (2*eps_fd));
        setMiniMetricCard(sens4, 'dT_L / dY  [1/u]', (SL_Yp - SL_Ym) / (2*eps_fd));

        % Update wedge patch vertices (no new objects created)
        set(h.leftWedgePatch,  'Vertices', leftWedgeVertices(sim.leftSolid));
        set(h.rightWedgePatch, 'Vertices', rightWedgeVertices(sim.rightSolid));

        % Batch incoming rays into one line object
        allRays = [sim.left.rays, sim.right.rays];
        step    = max(1, round(numel(allRays) / 60));
        idx     = 1:step:numel(allRays);
        n       = numel(idx);
        iX = NaN(3,n); iY = NaN(3,n); iZ = NaN(3,n);
        for k = 1:n
            r = allRays(idx(k));
            iX(:,k) = [r.s(1); r.d(1); NaN];
            iY(:,k) = [r.s(2); r.d(2); NaN];
            iZ(:,k) = [r.s(3); r.d(3); NaN];
        end
        set(h.incomingLines, 'XData', iX(:)', 'YData', iY(:)', 'ZData', iZ(:)');

        % Batch outgoing rays
        h.outgoingLinesL = batchOutgoingRays(h.outgoingLinesL, sim.left.rays,  state.showBlocked);
        h.outgoingLinesR = batchOutgoingRays(h.outgoingLinesR, sim.right.rays, state.showBlocked);

        % Update front-view wedge outlines
        ls = sim.leftSolid;
        set(h.frontLeftWedge,  'Position', [-ls.yMax, ls.zMin, ls.yMax-ls.yMin, ls.zMax-ls.zMin]);
        rs = sim.rightSolid;
        set(h.frontRightWedge, 'Position', [-rs.yMax, rs.zMin, rs.yMax-rs.yMin, rs.zMax-rs.zMin]);

        drawnow limitrate;
    end

    % ==================================================================
    function hLine = batchOutgoingRays(hLine, rays, showBlocked)
        nRays = numel(rays);
        step  = max(1, round(nRays / 120));
        idx   = 1:step:nRays;
        if ~showBlocked
            keep = arrayfun(@(k) rays(k).T >= 0.6, idx);
            idx  = idx(keep);
        end
        n = numel(idx);
        if n == 0
            set(hLine, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
            return;
        end
        X = NaN(3,n); Y = NaN(3,n); Z = NaN(3,n);
        for k = 1:n
            r = rays(idx(k));
            X(:,k) = [r.s(1); r.d(1); NaN];
            Y(:,k) = [r.s(2); r.d(2); NaN];
            Z(:,k) = [r.s(3); r.d(3); NaN];
        end
        Tvals = arrayfun(@(k) rays(k).T, idx);
        col   = (1 - median(Tvals)) * [0.95 0.82 0.45] + median(Tvals) * [0.80 0.50 0.08];
        set(hLine, 'XData', X(:)', 'YData', Y(:)', 'ZData', Z(:)', 'Color', col);
    end
end

% ======================================================================
% Scalar-only transmission for finite-difference sensitivity
% Returns a single number; allocates no ray struct
% ======================================================================
function S = scalarTransmission(shiftZ, shiftY, alpha, n, useLeftDet)
    ledCenter = [-4.8, 0, 0];
    srcPts    = makeSourcePoints(ledCenter, 0.24, 0.24, n, n);
    [leftSolid, rightSolid] = makeSolids(shiftZ, shiftY);

    if useLeftDet
        detPts = makeDetectorPoints([3.8, -0.62, 0.00], 0.82, 0.82, n, n);
    else
        detPts = makeDetectorPoints([3.8,  0.68, 0.00], 0.95, 0.82, n, n);
    end

    nS = size(srcPts,1);
    nD = size(detPts,1);
    Sp = repmat(srcPts,  nD, 1);
    Dp = repelem(detPts, nS, 1);

    L  = segmentLengthAnalytic(Sp, Dp, leftSolid,  true) + ...
         segmentLengthAnalytic(Sp, Dp, rightSolid, false);

    dirs = Dp - Sp;
    dist = sqrt(sum(dirs.^2, 2));
    W    = max(dirs(:,1)./dist, 0) ./ (dist.^1.15);
    T    = exp(-alpha * L);
    S    = sum(W.*T) / max(sum(W), 1e-12);
end

% ======================================================================
function sim = simulateAtShift(shiftZ, shiftY, alpha, rayDensity)
    ledCenter = [-4.8, 0, 0];
    srcPts    = makeSourcePoints(ledCenter, 0.24, 0.24, rayDensity, rayDensity);
    [leftSolid, rightSolid] = makeSolids(shiftZ, shiftY);

    detHyL=0.82; detHzL=0.82; detHyR=0.95; detHzR=0.82;
    leftDetCenter  = [3.8, -0.62, 0.00];
    rightDetCenter = [3.8,  0.68, 0.00];

    leftDetPts  = makeDetectorPoints(leftDetCenter,  detHyL, detHzL, rayDensity, rayDensity);
    rightDetPts = makeDetectorPoints(rightDetCenter, detHyR, detHzR, rayDensity, rayDensity);

    sim.left  = runDetectorSimulation(srcPts, leftDetPts,  alpha, leftSolid, rightSolid);
    sim.right = runDetectorSimulation(srcPts, rightDetPts, alpha, leftSolid, rightSolid);

    sim.leftSolid  = leftSolid;
    sim.rightSolid = rightSolid;
    sim.leftDetectorCenter  = leftDetCenter;
    sim.rightDetectorCenter = rightDetCenter;
    sim.detHyLeft=detHyL; sim.detHzLeft=detHzL;
    sim.detHyRight=detHyR; sim.detHzRight=detHzR;
end

% ======================================================================
function [leftSolid, rightSolid] = makeSolids(shiftZ, shiftY)
    leftSolid.xFront          = 0;
    leftSolid.yMin            = -1.25 + shiftY;
    leftSolid.yMax            =  0.00 + shiftY;
    leftSolid.zMin            = -0.95 + shiftZ;
    leftSolid.zMax            =  0.95 + shiftZ;
    leftSolid.thicknessBottom = 1.15;
    leftSolid.thicknessTop    = 0.30;

    rightSolid.xFront         = 0;
    rightSolid.yMin           =  0.00 + shiftY;
    rightSolid.yMax           =  1.35 + shiftY;
    rightSolid.zMin           = -1.28 + shiftZ;
    rightSolid.zMax           =  1.28 + shiftZ;
    rightSolid.thicknessNear  = 0.25;
    rightSolid.thicknessFar   = 1.10;
end

% ======================================================================
% Analytic chord length through wedge (replaces 180-sample Monte Carlo)
%
% Both wedges are axis-aligned boxes whose back X face varies linearly
% in one transverse coordinate.  We clip the segment to the Y/Z extents,
% then solve the X entry/exit analytically.
%
% S, D : N x 3 arrays of segment start/end points
% isLeft: true = left wedge (thickness varies with Z),
%         false = right wedge (thickness varies with Y)
% ======================================================================
function L = segmentLengthAnalytic(S, D, solid, isLeft)
    N   = size(S, 1);
    dir = D - S;
    len = sqrt(sum(dir.^2, 2));
    safe = 1e-30;

    % Clamp parametric interval to Y slab
    tyA = (solid.yMin - S(:,2)) ./ (dir(:,2) + safe);
    tyB = (solid.yMax - S(:,2)) ./ (dir(:,2) + safe);
    ty0 = min(tyA, tyB);  ty1 = max(tyA, tyB);

    % Clamp to Z slab
    tzA = (solid.zMin - S(:,3)) ./ (dir(:,3) + safe);
    tzB = (solid.zMax - S(:,3)) ./ (dir(:,3) + safe);
    tz0 = min(tzA, tzB);  tz1 = max(tzA, tzB);

    % Combined transverse interval clamped to [0,1]
    t0 = max(max(ty0, tz0), 0);
    t1 = min(min(ty1, tz1), 1);
    miss = (t1 <= t0);

    % Wedge back-face X at the midpoint of the transverse interval
    tMid = (t0 + t1) * 0.5;
    pMid = S + tMid .* dir;

    if isLeft
        u     = max(0, min(1, (pMid(:,3) - solid.zMin) / (solid.zMax - solid.zMin)));
        xBack = solid.xFront + solid.thicknessBottom + u*(solid.thicknessTop - solid.thicknessBottom);
    else
        u     = max(0, min(1, (pMid(:,2) - solid.yMin) / (solid.yMax - solid.yMin)));
        xBack = solid.xFront + solid.thicknessNear + u*(solid.thicknessFar - solid.thicknessNear);
    end

    % X slab interval
    xf = repmat(solid.xFront, N, 1);
    txA = (xf    - S(:,1)) ./ (dir(:,1) + safe);
    txB = (xBack - S(:,1)) ./ (dir(:,1) + safe);
    tx0 = min(txA, txB);  tx1 = max(txA, txB);

    tEnter = max(max(t0, tx0), 0);
    tExit  = min(min(t1, tx1), 1);

    chord       = max(tExit - tEnter, 0) .* len;
    chord(miss) = 0;
    L = chord;
end

% ======================================================================
function result = runDetectorSimulation(srcPts, detPts, alpha, leftSolid, rightSolid)
    nS = size(srcPts, 1);
    nD = size(detPts, 1);

    S = repmat(srcPts,  nD, 1);
    D = repelem(detPts, nS, 1);

    L = segmentLengthAnalytic(S, D, leftSolid,  true) + ...
        segmentLengthAnalytic(S, D, rightSolid, false);

    dirs = D - S;
    dist = sqrt(sum(dirs.^2, 2));
    W    = max(dirs(:,1)./dist, 0) ./ (dist.^1.15);
    T    = exp(-alpha * L);

    wSum = max(sum(W), 1e-12);
    result.transmission    = sum(W.*T)        / wSum;
    result.avgPathLength   = sum(W.*L)        / wSum;
    result.blockedFraction = sum(W.*(T<0.5))  / wSum;

    % Subsample rays for display only (cap at ~200)
    nTotal = nS * nD;
    step   = max(1, floor(nTotal / 200));
    idx    = (1:step:nTotal)';
    nKeep  = numel(idx);
    rays(nKeep).s = []; rays(nKeep).d = []; rays(nKeep).T = []; rays(nKeep).L = []; rays(nKeep).w = [];
    for k = 1:nKeep
        i = idx(k);
        rays(k).s = S(i,:);
        rays(k).d = D(i,:);
        rays(k).T = T(i);
        rays(k).L = L(i);
        rays(k).w = W(i);
    end
    result.rays = rays;
end

% ======================================================================
function pts = makeSourcePoints(center, ry, rz, ny, nz)
    [IY, IZ] = ndgrid(1:ny, 1:nz);
    Y = center(2) - ry + (2*ry)*(IY-1)/(ny-1);
    Z = center(3) - rz + (2*rz)*(IZ-1)/(nz-1);
    pts = [repmat(center(1), ny*nz, 1), Y(:), Z(:)];
end

function pts = makeDetectorPoints(center, hy, hz, ny, nz)
    [IY, IZ] = ndgrid(1:ny, 1:nz);
    Y = center(2) - hy/2 + hy*(IY-1)/(ny-1);
    Z = center(3) - hz/2 + hz*(IZ-1)/(nz-1);
    pts = [repmat(center(1), ny*nz, 1), Y(:), Z(:)];
end

% ======================================================================
% Geometry helpers
% ======================================================================
function V = leftWedgeVertices(solid)
    x0   = solid.xFront;
    xBot = solid.xFront + solid.thicknessBottom;
    xTop = solid.xFront + solid.thicknessTop;
    y0=solid.yMin; y1=solid.yMax; z0=solid.zMin; z1=solid.zMax;
    V = [x0   y0 z0; x0   y1 z0; x0   y1 z1; x0   y0 z1;
         xBot y0 z0; xBot y1 z0; xTop y1 z1; xTop y0 z1];
end

function V = rightWedgeVertices(solid)
    x0    = solid.xFront;
    xNear = solid.xFront + solid.thicknessNear;
    xFar  = solid.xFront + solid.thicknessFar;
    y0=solid.yMin; y1=solid.yMax; z0=solid.zMin; z1=solid.zMax;
    V = [x0    y0 z0; x0   y1 z0; x0   y1 z1; x0    y0 z1;
         xNear y0 z0; xFar y1 z0; xFar y1 z1; xNear y0 z1];
end

function drawBlock(ax, xc, yc, zc, dx, dy, dz, c)
    x0=xc-dx/2; x1=xc+dx/2; y0=yc-dy/2; y1=yc+dy/2; z0=zc-dz/2; z1=zc+dz/2;
    V = [x0 y0 z0; x1 y0 z0; x1 y1 z0; x0 y1 z0;
         x0 y0 z1; x1 y0 z1; x1 y1 z1; x0 y1 z1];
    F = [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8];
    patch(ax, 'Vertices', V, 'Faces', F, 'FaceColor', c, 'EdgeColor', 'k', 'FaceAlpha', 1, 'LineWidth', 1);
end

% ======================================================================
% Sidebar UI helpers
% ======================================================================
function card = makeMetricCard(parent, pos, symbolText, valueText, descText)
    card.panel  = uipanel(parent, 'BackgroundColor', [1 1 1], 'Position', pos);
    card.symbol = uilabel(card.panel, 'Text', symbolText, 'FontName', 'Cambria Math', ...
        'FontSize', 15, 'FontWeight', 'bold', 'FontColor', [0.08 0.10 0.14], 'Position', [12 26 195 24]);
    card.value  = uilabel(card.panel, 'Text', valueText,  'FontName', 'Cambria Math', ...
        'FontSize', 15, 'FontColor', [0.12 0.16 0.22], 'Position', [215 26 100 24]);
    card.desc   = uilabel(card.panel, 'Text', descText,   'FontName', 'Helvetica', ...
        'FontSize', 12, 'FontColor', [0.38 0.43 0.50], 'Position', [12 6 400 18]);
end

function card = makeMiniMetricCard(parent, pos, symbolText, valueText)
    card.panel  = uipanel(parent, 'BackgroundColor', [1 1 1], 'Position', pos);
    card.symbol = uilabel(card.panel, 'Text', symbolText, 'FontName', 'Cambria Math', ...
        'FontSize', 12, 'FontWeight', 'bold', 'FontColor', [0.08 0.10 0.14], 'Position', [6 10 130 20]);
    card.value  = uilabel(card.panel, 'Text', valueText,  'FontName', 'Cambria Math', ...
        'FontSize', 12, 'FontColor', [0.12 0.16 0.22], 'Position', [138 10 70 20]);
end

function setMetricCard(card, symbolText, valueNum, descText)
    card.symbol.Text = symbolText;
    card.value.Text  = sprintf('%.4f', valueNum);
    card.desc.Text   = descText;
end

function setMiniMetricCard(card, symbolText, valueNum)
    card.symbol.Text = symbolText;
    card.value.Text  = sprintf('%.4f', valueNum);
end