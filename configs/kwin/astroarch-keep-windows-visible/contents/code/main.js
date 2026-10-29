// When the screen shrinks (an RDP client window made smaller, a virtual output resized), KWin
// leaves normal windows where they were and they can end up out of reach. Move each one back
// inside the work area of its screen, and shrink it if it no longer fits.

function keepVisible(window) {
    if (!window.normalWindow || window.fullScreen || !window.moveable) {
        return;
    }
    const output = window.output || workspace.activeScreen;
    const area = workspace.clientArea(KWin.MaximizeArea, output, workspace.currentDesktop);
    const g = window.frameGeometry;
    let width = g.width;
    let height = g.height;
    if (window.resizeable) {
        width = Math.min(width, area.width);
        height = Math.min(height, area.height);
    }
    const x = Math.max(area.x, Math.min(g.x, area.x + area.width - width));
    const y = Math.max(area.y, Math.min(g.y, area.y + area.height - height));
    if (x !== g.x || y !== g.y || width !== g.width || height !== g.height) {
        window.frameGeometry = {x: x, y: y, width: width, height: height};
    }
}

function keepAllVisible() {
    workspace.windowList().forEach(keepVisible);
}

workspace.screensChanged.connect(keepAllVisible);
workspace.virtualScreenGeometryChanged.connect(keepAllVisible);
