const vscode = require('vscode');

// Panel visibility is remembered per folder, so a folder opened for the first
// time starts with the terminal hidden. Reveal the terminal view on every
// window open; the view creates a terminal itself if none was restored.
// extensionKind "ui" keeps this running locally, so Remote-SSH windows get it
// without installing anything on the server.
async function activate() {
  await vscode.commands.executeCommand('terminal.focus');
  // Hand keyboard focus back to the editor area.
  await vscode.commands.executeCommand('workbench.action.focusActiveEditorGroup');
}

module.exports = { activate, deactivate() {} };
