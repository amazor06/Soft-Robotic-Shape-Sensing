function opticalWedgeApp()
% OPTICALWEDGEAPP
% LED -> two adjacent wedges -> fixed detectors
%
% Updates:
% - sidebar channel semantics swapped correctly
% - math formatting fixed for MATLAB LaTeX interpreter
% - LED fixed
% - detectors fixed
% - only wedges move
% - vertical and horizontal wedge shifts included

    close all force;
    clc;

    % -----------------------------
    % Initial state
    % -----------------------------
    state.shiftZ = 0.00;   % vertical wedge shift
    state.shiftY = 0.00;   % horizontal wedge shift
    state.alpha = 2.00;
    state.rayDensity = 7;
    state.showBlocked = true;

    % -----------------------------
    % Build UI
    % -----------------------------
    fig = uifigure( ...
        'Name', 'Optical Wedge Simulator', ...
        'Color', [0.92 0.94 0.96], ...
        'Position', [60 40 1560 920]);

    % Sidebar
    side = uipanel(fig, ...
        'Title', 'Model Information', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [10 10 470 900]);

    % Main panel
    main = uipanel(fig, ...
        'Title', 'Geometry and Rays', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.94 0.95 0.97], ...
        'Position', [490 10 1060 900]);

    % Axes
    ax3d = uiaxes(main, ...
        'Position', [20 300 660 570], ...
        'Box', 'on', ...
        'XGrid', 'on', 'YGrid', 'on', 'ZGrid', 'on', ...
        'Color', [0.95 0.96 0.98], ...
        'FontName', 'Helvetica');
    title(ax3d, '3D View');
    xlabel(ax3d, 'X');
    ylabel(ax3d, 'Y');
    zlabel(ax3d, 'Z');
    view(ax3d, 12, 18);
    axis(ax3d, 'equal');

    axFront = uiaxes(main, ...
        'Position', [700 300 340 570], ...
        'Box', 'on', ...
        'XGrid', 'on', 'YGrid', 'on', ...
        'Color', [0.95 0.96 0.98], ...
        'FontName', 'Helvetica');
    title(axFront, 'Front View (mirrored to match 3D)');
    xlabel(axFront, '-Y');
    ylabel(axFront, 'Z');
    axis(axFront, 'equal');

    % Controls panel
    ctrl = uipanel(main, ...
        'Title', 'Controls', ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [20 20 1020 250]);

    % -----------------------------
    % Sidebar: titles
    % -----------------------------
    uilabel(side, ...
        'Text', 'Extracted Data', ...
        'FontSize', 22, ...
        'FontWeight', 'bold', ...
        'Position', [18 840 220 30]);

    cardsPanel = uipanel(side, ...
        'Title', '', ...
        'BorderType', 'none', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [15 460 440 355]);

    uilabel(side, ...
        'Text', 'Math Used', ...
        'FontSize', 20, ...
        'FontWeight', 'bold', ...
        'Position', [18 425 180 28]);

    % Math panel as axes so we can use rendered text
    mathPanel = uipanel(side, ...
        'Title', '', ...
        'BackgroundColor', [1 1 1], ...
        'Position', [15 15 440 395]);

    mathAx = uiaxes(mathPanel, ...
        'Position', [5 5 430 385], ...
        'XColor', 'none', 'YColor', 'none', ...
        'Box', 'off', 'Color', [1 1 1]);
    axis(mathAx, [0 1 0 1]);
    axis(mathAx, 'off');
    hold(mathAx, 'on');

    % -----------------------------
    % Metric cards
    % -----------------------------
    metricY = 285;
    cardH = 58;
    gap = 8;

    card1 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'S_R', '0.0000', 'right detector transmission'); metricY = metricY - (cardH + gap);
    card2 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'S_L', '0.0000', 'left detector transmission');  metricY = metricY - (cardH + gap);
    card3 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'ΔS', '0.0000', 'differential signal');          metricY = metricY - (cardH + gap);
    card4 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'L̄_R', '0.0000', 'average path length to right detector'); metricY = metricY - (cardH + gap);
    card5 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'L̄_L', '0.0000', 'average path length to left detector');  metricY = metricY - (cardH + gap);
    card6 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'B_R', '0.0000', 'blocked-ray fraction for right detector'); metricY = metricY - (cardH + gap);
    card7 = makeMetricCard(cardsPanel, [0 metricY 440 cardH], 'B_L', '0.0000', 'blocked-ray fraction for left detector');

    sensPanel = uipanel(cardsPanel, ...
        'Title', '', ...
        'BorderType', 'none', ...
        'BackgroundColor', [0.97 0.98 0.99], ...
        'Position', [0 0 440 92]);

    sens1 = makeMiniMetricCard(sensPanel, [0 46 215 42], '∂S_R/∂Z', '0.0000');
    sens2 = makeMiniMetricCard(sensPanel, [225 46 215 42], '∂S_L/∂Z', '0.0000');
    sens3 = makeMiniMetricCard(sensPanel, [0 0 215 42], '∂S_R/∂Y', '0.0000');
    sens4 = makeMiniMetricCard(sensPanel, [225 0 215 42], '∂S_L/∂Y', '0.0000');

    % -----------------------------
    % Controls panel widgets
    % -----------------------------
    uilabel(ctrl, ...
        'Text', 'Vertical Wedge Shift (Z)', ...
        'FontWeight', 'bold', ...
        'Position', [20 185 160 22]);
    shiftZSlider = uislider(ctrl, ...
        'Limits', [-1 1], ...
        'Value', state.shiftZ, ...
        'MajorTicks', -1:0.5:1, ...
        'Position', [190 195 260 3]);

    shiftZValue = uilabel(ctrl, ...
        'Text', sprintf('%.2f', state.shiftZ), ...
        'Position', [460 185 60 22]);

    uilabel(ctrl, ...
        'Text', 'Horizontal Wedge Shift (Y)', ...
        'FontWeight', 'bold', ...
        'Position', [20 130 170 22]);
    shiftYSlider = uislider(ctrl, ...
        'Limits', [-1 1], ...
        'Value', state.shiftY, ...
        'MajorTicks', -1:0.5:1, ...
        'Position', [190 140 260 3]);

    shiftYValue = uilabel(ctrl, ...
        'Text', sprintf('%.2f', state.shiftY), ...
        'Position', [460 130 60 22]);

    uilabel(ctrl, ...
        'Text', 'Attenuation α', ...
        'FontWeight', 'bold', ...
        'Position', [20 75 120 22]);
    alphaSlider = uislider(ctrl, ...
        'Limits', [0 10], ...
        'Value', state.alpha, ...
        'MajorTicks', 0:2:10, ...
        'Position', [190 85 260 3]);

    alphaValue = uilabel(ctrl, ...
        'Text', sprintf('%.2f', state.alpha), ...
        'Position', [460 75 60 22]);

    uilabel(ctrl, ...
        'Text', 'Ray Density', ...
        'FontWeight', 'bold', ...
        'Position', [20 20 100 22]);
    densitySlider = uislider(ctrl, ...
        'Limits', [5 11], ...
        'Value', state.rayDensity, ...
        'MajorTicks', 5:11, ...
        'MinorTicks', [], ...
        'Position', [190 30 260 3]);

    densityValue = uilabel(ctrl, ...
        'Text', sprintf('%d', state.rayDensity), ...
        'Position', [460 20 60 22]);

    blockedCheck = uicheckbox(ctrl, ...
        'Text', 'Show blocked outgoing rays', ...
        'Value', state.showBlocked, ...
        'Position', [560 185 190 22]);

    uibutton(ctrl, ...
        'Text', 'Refresh', ...
        'FontWeight', 'bold', ...
        'Position', [560 120 120 34], ...
        'ButtonPushedFcn', @(~,~) redraw());

    uibutton(ctrl, ...
        'Text', 'Reset View', ...
        'Position', [560 70 120 34], ...
        'ButtonPushedFcn', @(~,~) resetView());

    % Draw math panel once
    drawMathPanel(mathAx);

    % Callbacks
    shiftZSlider.ValueChangedFcn = @(~,~) redraw();
    shiftYSlider.ValueChangedFcn = @(~,~) redraw();
    alphaSlider.ValueChangedFcn = @(~,~) redraw();
    densitySlider.ValueChangedFcn = @(~,~) redraw();
    blockedCheck.ValueChangedFcn = @(~,~) redraw();

    redraw();

    % =========================================================
    % Nested UI logic
    % =========================================================
    function resetView()
        view(ax3d, 12, 18);
        axis(ax3d, 'equal');
    end

    function redraw()
        state.shiftZ = shiftZSlider.Value;
        state.shiftY = shiftYSlider.Value;
        state.alpha = alphaSlider.Value;
        state.rayDensity = round(densitySlider.Value);
        state.showBlocked = blockedCheck.Value;

        shiftZValue.Text = sprintf('%.2f', state.shiftZ);
        shiftYValue.Text = sprintf('%.2f', state.shiftY);
        alphaValue.Text = sprintf('%.2f', state.alpha);
        densityValue.Text = sprintf('%d', state.rayDensity);

        sim = simulateAtShift(state.shiftZ, state.shiftY, state.alpha, state.rayDensity);

        epsVal = 0.03;
        simZ1 = simulateAtShift(state.shiftZ - epsVal, state.shiftY, state.alpha, max(5, state.rayDensity - 2));
        simZ2 = simulateAtShift(state.shiftZ + epsVal, state.shiftY, state.alpha, max(5, state.rayDensity - 2));
        simY1 = simulateAtShift(state.shiftZ, state.shiftY - epsVal, state.alpha, max(5, state.rayDensity - 2));
        simY2 = simulateAtShift(state.shiftZ, state.shiftY + epsVal, state.alpha, max(5, state.rayDensity - 2));

        % SWAPPED reporting semantics
        SR = sim.left.transmission;
        SL = sim.right.transmission;
        LR = sim.left.avgPathLength;
        LL = sim.right.avgPathLength;
        BR = sim.left.blockedFraction;
        BL = sim.right.blockedFraction;

        dSRdZ = (simZ2.left.transmission - simZ1.left.transmission) / (2 * epsVal);
        dSLdZ = (simZ2.right.transmission - simZ1.right.transmission) / (2 * epsVal);
        dSRdY = (simY2.left.transmission - simY1.left.transmission) / (2 * epsVal);
        dSLdY = (simY2.right.transmission - simY1.right.transmission) / (2 * epsVal);

        diffSignal = SR - SL;

        setMetricCard(card1, 'S_R', SR, 'right detector transmission');
        setMetricCard(card2, 'S_L', SL, 'left detector transmission');
        setMetricCard(card3, 'ΔS', diffSignal, 'differential signal');
        setMetricCard(card4, 'L̄_R', LR, 'average path length to right detector');
        setMetricCard(card5, 'L̄_L', LL, 'average path length to left detector');
        setMetricCard(card6, 'B_R', BR, 'blocked-ray fraction for right detector');
        setMetricCard(card7, 'B_L', BL, 'blocked-ray fraction for left detector');

        setMiniMetricCard(sens1, '∂S_R/∂Z', dSRdZ);
        setMiniMetricCard(sens2, '∂S_L/∂Z', dSLdZ);
        setMiniMetricCard(sens3, '∂S_R/∂Y', dSRdY);
        setMiniMetricCard(sens4, '∂S_L/∂Y', dSLdY);

        % -------- 3D view --------
        cla(ax3d);
        hold(ax3d, 'on');
        grid(ax3d, 'on');
        axis(ax3d, [-5.5 5.2 -2.4 2.4 -2.0 2.0]);
        daspect(ax3d, [1 1 1]);

        drawAxes3D(ax3d);

        % LED
        [Xs,Ys,Zs] = cylinder(0.16, 28);
        Xs = Xs * 0.46 - 4.8;
        Ys = Ys * 0.46;
        Zs = Zs * 0.32 - 0.16;
        surf(ax3d, Xs, Ys, Zs, ...
            'FaceColor', [0.85 0.30 0.26], ...
            'EdgeColor', 'none', ...
            'FaceLighting', 'gouraud');

        % Wedges
        drawLeftWedge(ax3d, sim.leftSolid, [0.81 0.84 0.87]);
        drawRightWedge(ax3d, sim.rightSolid, [0.81 0.84 0.87]);

        % Fixed detectors
        drawBlock(ax3d, sim.leftDetectorCenter(1), sim.leftDetectorCenter(2), sim.leftDetectorCenter(3), ...
            0.12, sim.detHyLeft, sim.detHzLeft, [0.13 0.16 0.20]);
        drawBlock(ax3d, sim.rightDetectorCenter(1), sim.rightDetectorCenter(2), sim.rightDetectorCenter(3), ...
            0.12, sim.detHyRight, sim.detHzRight, [0.13 0.16 0.20]);

        % Rays
        plotIncomingRays(ax3d, sim.left.rays, sim.right.rays);
        plotOutgoingRays(ax3d, sim.left.rays, state.showBlocked);
        plotOutgoingRays(ax3d, sim.right.rays, state.showBlocked);

        title(ax3d, '3D View');

        % -------- Front view --------
        cla(axFront);
        hold(axFront, 'on');
        grid(axFront, 'on');
        axis(axFront, [-1.8 1.8 -1.8 1.8]);
        daspect(axFront, [1 1 1]);

        rectangle(axFront, ...
            'Position', [-sim.leftSolid.yMax, sim.leftSolid.zMin, ...
                         sim.leftSolid.yMax - sim.leftSolid.yMin, ...
                         sim.leftSolid.zMax - sim.leftSolid.zMin], ...
            'FaceColor', [0.81 0.84 0.87], ...
            'EdgeColor', [0.35 0.40 0.45], ...
            'LineWidth', 1.3);

        rectangle(axFront, ...
            'Position', [-sim.rightSolid.yMax, sim.rightSolid.zMin, ...
                         sim.rightSolid.yMax - sim.rightSolid.yMin, ...
                         sim.rightSolid.zMax - sim.rightSolid.zMin], ...
            'FaceColor', [0.81 0.84 0.87], ...
            'EdgeColor', [0.35 0.40 0.45], ...
            'LineWidth', 1.3);

        rectangle(axFront, ...
            'Position', [-sim.leftDetectorCenter(2) - sim.detHyLeft/2, ...
                         sim.leftDetectorCenter(3) - sim.detHzLeft/2, ...
                         sim.detHyLeft, sim.detHzLeft], ...
            'FaceColor', [0.13 0.16 0.20], 'EdgeColor', 'k');

        rectangle(axFront, ...
            'Position', [-sim.rightDetectorCenter(2) - sim.detHyRight/2, ...
                         sim.rightDetectorCenter(3) - sim.detHzRight/2, ...
                         sim.detHyRight, sim.detHzRight], ...
            'FaceColor', [0.13 0.16 0.20], 'EdgeColor', 'k');

        plot(axFront, 0, 0, 'o', ...
            'MarkerFaceColor', [0.85 0.30 0.26], ...
            'MarkerEdgeColor', 'k', ...
            'MarkerSize', 7);

        text(axFront, -1.65, 1.55, 'LED reference', 'FontSize', 11);
        title(axFront, 'Front View (−Y vs Z)');
    end
end

% =============================================================
% Simulation
% =============================================================
function sim = simulateAtShift(shiftZ, shiftY, alpha, rayDensity)

    ledCenter = [-4.8, 0, 0];
    sourcePts = makeSourcePoints(ledCenter, 0.24, 0.24, rayDensity, rayDensity);

    xFront = 0.0;

    % Left wedge
    leftSolid.xFront = xFront;
    leftSolid.yMin = -1.25 + shiftY;
    leftSolid.yMax =  0.00 + shiftY;
    leftSolid.zMin = -0.95 + shiftZ;
    leftSolid.zMax =  0.95 + shiftZ;
    leftSolid.thicknessBottom = 1.15;
    leftSolid.thicknessTop    = 0.30;

    % Right wedge
    rightSolid.xFront = xFront;
    rightSolid.yMin =  0.00 + shiftY;
    rightSolid.yMax =  1.35 + shiftY;
    rightSolid.zMin = -1.28 + shiftZ;
    rightSolid.zMax =  1.28 + shiftZ;
    rightSolid.thicknessNear = 0.25;
    rightSolid.thicknessFar  = 1.10;

    % Fixed detectors
    detHyLeft = 0.82;
    detHzLeft = 0.82;
    detHyRight = 0.95;
    detHzRight = 0.82;

    leftDetectorCenter = [3.8, -0.62, 0.00];
    rightDetectorCenter = [3.8, 0.68, 0.00];

    leftDetectorPts = makeDetectorPoints(leftDetectorCenter, detHyLeft, detHzLeft, rayDensity, rayDensity);
    rightDetectorPts = makeDetectorPoints(rightDetectorCenter, detHyRight, detHzRight, rayDensity, rayDensity);

    leftChannel = runDetectorSimulation(sourcePts, leftDetectorPts, alpha, leftSolid, rightSolid);
    rightChannel = runDetectorSimulation(sourcePts, rightDetectorPts, alpha, leftSolid, rightSolid);

    sim.ledCenter = ledCenter;
    sim.leftSolid = leftSolid;
    sim.rightSolid = rightSolid;
    sim.leftDetectorCenter = leftDetectorCenter;
    sim.rightDetectorCenter = rightDetectorCenter;
    sim.detHyLeft = detHyLeft;
    sim.detHzLeft = detHzLeft;
    sim.detHyRight = detHyRight;
    sim.detHzRight = detHzRight;
    sim.left = leftChannel;
    sim.right = rightChannel;
end

function result = runDetectorSimulation(sourcePts, detectorPts, alpha, leftSolid, rightSolid)

    weightedSignal = 0;
    weightedBaseline = 0;
    weightedPath = 0;
    weightedBlocked = 0;

    rays = struct('s', {}, 'd', {}, 'T', {}, 'L', {}, 'w', {});

    idx = 0;
    for i = 1:size(sourcePts,1)
        s = sourcePts(i,:);
        for j = 1:size(detectorPts,1)
            d = detectorPts(j,:);

            Lleft = segmentLengthInsideSolid(s, d, @pointInsideLeftWedge, leftSolid, 180);
            Lright = segmentLengthInsideSolid(s, d, @pointInsideRightWedge, rightSolid, 180);
            L = Lleft + Lright;

            w = lambertWeight(s, d);
            T = exp(-alpha * L);

            weightedSignal = weightedSignal + w * T;
            weightedBaseline = weightedBaseline + w;
            weightedPath = weightedPath + w * L;
            if T < 0.5
                weightedBlocked = weightedBlocked + w;
            end

            idx = idx + 1;
            rays(idx).s = s;
            rays(idx).d = d;
            rays(idx).T = T;
            rays(idx).L = L;
            rays(idx).w = w;
        end
    end

    result.transmission = weightedSignal / max(weightedBaseline, 1e-12);
    result.avgPathLength = weightedPath / max(weightedBaseline, 1e-12);
    result.blockedFraction = weightedBlocked / max(weightedBaseline, 1e-12);
    result.rays = rays;
end

function pts = makeSourcePoints(center, ry, rz, ny, nz)
    pts = zeros(ny*nz, 3);
    k = 0;
    for iy = 1:ny
        for iz = 1:nz
            y = center(2) - ry + (2*ry)*(iy-1)/(ny-1);
            z = center(3) - rz + (2*rz)*(iz-1)/(nz-1);
            k = k + 1;
            pts(k,:) = [center(1), y, z];
        end
    end
end

function pts = makeDetectorPoints(center, hy, hz, ny, nz)
    pts = zeros(ny*nz, 3);
    k = 0;
    for iy = 1:ny
        for iz = 1:nz
            y = center(2) - hy/2 + hy*(iy-1)/(ny-1);
            z = center(3) - hz/2 + hz*(iz-1)/(nz-1);
            k = k + 1;
            pts(k,:) = [center(1), y, z];
        end
    end
end

function w = lambertWeight(s, d)
    dir = d - s;
    dist = norm(dir);
    dir = dir / dist;
    cosTheta = max(dir(1), 0);
    w = cosTheta / (dist^1.15);
end

function t = leftThicknessAtZ(z, solid)
    u = clamp((z - solid.zMin)/(solid.zMax - solid.zMin), 0, 1);
    t = lerp(solid.thicknessBottom, solid.thicknessTop, u);
end

function inside = pointInsideLeftWedge(x, y, z, solid)
    if y < solid.yMin || y > solid.yMax || z < solid.zMin || z > solid.zMax
        inside = false;
        return;
    end
    xBack = solid.xFront + leftThicknessAtZ(z, solid);
    inside = x >= solid.xFront && x <= xBack;
end

function t = rightThicknessAtY(y, solid)
    u = clamp((y - solid.yMin)/(solid.yMax - solid.yMin), 0, 1);
    t = lerp(solid.thicknessNear, solid.thicknessFar, u);
end

function inside = pointInsideRightWedge(x, y, z, solid)
    if y < solid.yMin || y > solid.yMax || z < solid.zMin || z > solid.zMax
        inside = false;
        return;
    end
    xBack = solid.xFront + rightThicknessAtY(y, solid);
    inside = x >= solid.xFront && x <= xBack;
end

function L = segmentLengthInsideSolid(p0, p1, insideFn, solid, samples)
    insideCount = 0;
    for i = 1:samples
        t = (i-1)/(samples-1);
        p = p0 + t*(p1 - p0);
        if insideFn(p(1), p(2), p(3), solid)
            insideCount = insideCount + 1;
        end
    end
    L = norm(p1 - p0) * (insideCount / samples);
end

function v = clamp(v, a, b)
    v = max(a, min(b, v));
end

function y = lerp(a, b, t)
    y = a + (b - a)*t;
end

% =============================================================
% Drawing helpers
% =============================================================
function drawAxes3D(ax)
    plot3(ax, [0 1.2], [0 0], [0 0], 'r-', 'LineWidth', 1.8);
    plot3(ax, [0 0], [0 1.2], [0 0], 'g-', 'LineWidth', 1.8);
    plot3(ax, [0 0], [0 0], [0 1.2], 'b-', 'LineWidth', 1.8);
    text(ax, 1.28, 0, 0, 'X', 'Color', 'r', 'FontWeight', 'bold');
    text(ax, 0, 1.28, 0, 'Y', 'Color', 'g', 'FontWeight', 'bold');
    text(ax, 0, 0, 1.28, 'Z', 'Color', 'b', 'FontWeight', 'bold');
end

function drawLeftWedge(ax, solid, c)
    x0 = solid.xFront;
    xBot = solid.xFront + solid.thicknessBottom;
    xTop = solid.xFront + solid.thicknessTop;

    y0 = solid.yMin; y1 = solid.yMax;
    z0 = solid.zMin; z1 = solid.zMax;

    V = [
        x0  y0  z0
        x0  y1  z0
        x0  y1  z1
        x0  y0  z1
        xBot y0 z0
        xBot y1 z0
        xTop y1 z1
        xTop y0 z1
    ];

    F = [
        1 2 3 4
        1 5 6 2
        4 3 7 8
        1 4 8 5
        2 6 7 3
        5 6 7 8
    ];

    patch(ax, 'Vertices', V, 'Faces', F, ...
        'FaceColor', c, 'EdgeColor', [0.45 0.48 0.52], ...
        'FaceAlpha', 1.0, 'LineWidth', 1.0);
end

function drawRightWedge(ax, solid, c)
    x0 = solid.xFront;
    xNear = solid.xFront + solid.thicknessNear;
    xFar = solid.xFront + solid.thicknessFar;

    y0 = solid.yMin; y1 = solid.yMax;
    z0 = solid.zMin; z1 = solid.zMax;

    V = [
        x0    y0  z0
        x0    y1  z0
        x0    y1  z1
        x0    y0  z1
        xNear y0  z0
        xFar  y1  z0
        xFar  y1  z1
        xNear y0  z1
    ];

    F = [
        1 2 3 4
        1 5 6 2
        4 3 7 8
        1 4 8 5
        2 6 7 3
        5 6 7 8
    ];

    patch(ax, 'Vertices', V, 'Faces', F, ...
        'FaceColor', c, 'EdgeColor', [0.45 0.48 0.52], ...
        'FaceAlpha', 1.0, 'LineWidth', 1.0);
end

function drawBlock(ax, xc, yc, zc, dx, dy, dz, c)
    x0 = xc - dx/2; x1 = xc + dx/2;
    y0 = yc - dy/2; y1 = yc + dy/2;
    z0 = zc - dz/2; z1 = zc + dz/2;

    V = [
        x0 y0 z0
        x1 y0 z0
        x1 y1 z0
        x0 y1 z0
        x0 y0 z1
        x1 y0 z1
        x1 y1 z1
        x0 y1 z1
    ];

    F = [
        1 2 3 4
        5 6 7 8
        1 2 6 5
        2 3 7 6
        3 4 8 7
        4 1 5 8
    ];

    patch(ax, 'Vertices', V, 'Faces', F, ...
        'FaceColor', c, 'EdgeColor', 'k', ...
        'FaceAlpha', 1.0, 'LineWidth', 1.0);
end

function plotIncomingRays(ax, leftRays, rightRays)
    allRays = [leftRays, rightRays];
    for i = 1:10:numel(allRays)
        plot3(ax, ...
            [allRays(i).s(1) allRays(i).d(1)], ...
            [allRays(i).s(2) allRays(i).d(2)], ...
            [allRays(i).s(3) allRays(i).d(3)], ...
            '-', 'Color', [0.45 0.58 0.72], 'LineWidth', 0.35);
    end
end

function plotOutgoingRays(ax, rays, showBlocked)
    for i = 1:8:numel(rays)
        T = rays(i).T;
        if ~showBlocked && T < 0.6
            continue;
        end
        col = blendColor([0.95 0.82 0.45], [0.80 0.50 0.08], T);
        lw = 0.25 + 1.1 * T;

        plot3(ax, ...
            [rays(i).s(1) rays(i).d(1)], ...
            [rays(i).s(2) rays(i).d(2)], ...
            [rays(i).s(3) rays(i).d(3)], ...
            '-', 'Color', col, 'LineWidth', lw);
    end
end

function c = blendColor(c1, c2, t)
    c = (1-t)*c1 + t*c2;
end

% =============================================================
% Sidebar helpers
% =============================================================
function card = makeMetricCard(parent, pos, symbolText, valueText, descText)
    card.panel = uipanel(parent, ...
        'BackgroundColor', [1 1 1], ...
        'Position', pos);

    card.symbol = uilabel(card.panel, ...
        'Text', symbolText, ...
        'FontName', 'Cambria Math', ...
        'FontSize', 19, ...
        'FontWeight', 'bold', ...
        'FontColor', [0.08 0.10 0.14], ...
        'Position', [12 26 85 24]);

    card.value = uilabel(card.panel, ...
        'Text', valueText, ...
        'FontName', 'Cambria Math', ...
        'FontSize', 18, ...
        'FontColor', [0.12 0.16 0.22], ...
        'Position', [95 26 115 24]);

    card.desc = uilabel(card.panel, ...
        'Text', descText, ...
        'FontName', 'Helvetica', ...
        'FontSize', 12, ...
        'FontColor', [0.38 0.43 0.50], ...
        'Position', [12 6 400 18]);
end

function card = makeMiniMetricCard(parent, pos, symbolText, valueText)
    card.panel = uipanel(parent, ...
        'BackgroundColor', [1 1 1], ...
        'Position', pos);

    card.symbol = uilabel(card.panel, ...
        'Text', symbolText, ...
        'FontName', 'Cambria Math', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'FontColor', [0.08 0.10 0.14], ...
        'Position', [10 10 120 20]);

    card.value = uilabel(card.panel, ...
        'Text', valueText, ...
        'FontName', 'Cambria Math', ...
        'FontSize', 14, ...
        'FontColor', [0.12 0.16 0.22], ...
        'Position', [130 10 75 20]);
end

function setMetricCard(card, symbolText, valueNum, descText)
    card.symbol.Text = symbolText;
    card.value.Text = sprintf('%.4f', valueNum);
    card.desc.Text = descText;
end

function setMiniMetricCard(card, symbolText, valueNum)
    card.symbol.Text = symbolText;
    card.value.Text = sprintf('%.4f', valueNum);
end

function drawMathPanel(ax)
    cla(ax);
    axis(ax, [0 1 0 1]);
    axis(ax, 'off');
    hold(ax, 'on');

    entries = {
        'Beer–Lambert attenuation', ...
        'T = exp(−αL)', ...
        '', ...
        'Total path length', ...
        'L = Lleft + Lright', ...
        '', ...
        'Ray weighting', ...
        'w = cos(θ) / ‖d − s‖^1.15', ...
        '', ...
        'Detector transmission', ...
        'S = Σ(wT) / Σ(w)', ...
        '', ...
        'Average path length', ...
        'L̄ = Σ(wL) / Σ(w)', ...
        '', ...
        'Blocked-ray fraction', ...
        'B = Σ(w for T < 0.5) / Σ(w)', ...
        '', ...
        'Finite-difference sensitivity', ...
        '∂S/∂Z ≈ [S(Z + ε) − S(Z − ε)] / (2ε)', ...
        '∂S/∂Y ≈ [S(Y + ε) − S(Y − ε)] / (2ε)'
    };

    y = 0.95;
    dy = 0.047;

    for i = 1:numel(entries)
        txt = entries{i};

        if txt == ""
            y = y - dy * 0.45;
            continue;
        end

        isHeader = ~contains(txt, '=') && ~contains(txt, '≈') && ~contains(txt, '/');

        if isHeader
            text(ax, 0.03, y, txt, ...
                'FontName', 'Cambria', ...
                'FontWeight', 'bold', ...
                'FontSize', 15, ...
                'Color', [0.08 0.10 0.14], ...
                'VerticalAlignment', 'top');
        else
            text(ax, 0.06, y, txt, ...
                'FontName', 'Cambria Math', ...
                'FontSize', 16, ...
                'Color', [0.12 0.16 0.22], ...
                'VerticalAlignment', 'top');
        end

        y = y - dy;
    end
end