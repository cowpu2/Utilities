# Codex Mini Meter (Windows) -- VS Code extension auto-detection

A compact, always-on-top meter displaying two Codex usage allowance percentages:

`5h 72%  |  Wk 43%` (example values; percentage **remaining** by default).

Two small notification-area icons show the same five-hour and weekly numbers. Hide the widget if you prefer icons alone.

## What changed in this version

**No standalone Codex download, Node.js, npm, or copying codex.exe is required.** The monitor now automatically locates the `codex.exe` bundled with your existing OpenAI Codex extension in VS Code. Its typical Windows path is:

```text
%USERPROFILE%\.vscode\extensions\openai.chatgpt-<version>-win32-x64\bin\windows-x86_64\codex.exe
```

- Checks `%USERPROFILE%\.vscode\extensions` and `%USERPROFILE%\.vscode-insiders\extensions`.
- Also checks `VSCODE_EXTENSIONS` when you have configured a custom extensions directory.
- Selects the highest installed extension version **with a real codex.exe**; ignores incomplete updates.
- **Re-detects on every refresh** (every five minutes), so VS Code extension upgrades do not require you to change a path, copy a file, or restart the meter.
- Fallbacks if the VS Code executable cannot be found: `CODEX_CLI_PATH`, a `codex.exe` next to the meter, OpenAI's standalone Codex install, `codex.exe` on PATH, then `codex.cmd` on PATH.
- Right-click the widget/tray icon, then select **Codex executable > Show detected executable path** to verify what it is actually using.
- You can select a specific `codex.exe` manually with **Codex executable > Select executable...**, or clear that override with **Use automatic detection**.

The VS Code Codex extension normally manages its own login and the bundled CLI can use the same Codex account authentication. If you use another VS Code profile or account that doesn't share authentication state, the meter may still need troubleshooting; merely finding `codex.exe` does not guarantee the account is authenticated.

## Requirements

- Windows 10 or 11 x64.
- OpenAI Codex extension installed in desktop VS Code and signed into your ChatGPT account.
- .NET 10 SDK for **building** the project. The published app itself is self-contained and doesn't need the .NET SDK.
- Internet connectivity for Codex to retrieve current account usage limits.

The meter does **not** require an OpenAI API key.

## Build on Windows

1. Extract the source ZIP to a local folder.
2. Double-click `BUILD.cmd` (or run it in a VS Code terminal). No PowerShell scripts are used.
3. If the script reports that the SDK is missing, install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) and run `BUILD.cmd` again.
4. Run `publish\CodexMiniMeter.exe`.
5. Move the `publish` directory to a permanent location, such as `%LOCALAPPDATA%\Programs\CodexMiniMeter`, before selecting **Start with Windows**.

Do **not** copy `codex.exe` into the `publish` directory. The app will find the copy already supplied with VS Code.

For developers, you can run `dotnet run -- --self-test` from the source folder to check the JSON parser and extension discovery/version-selection tests. This does not confirm that your VS Code sign-in works.

## Use

- Drag the widget to position it; its position is saved.
- Right-click either notification icon or the widget for settings and a **Refresh now** action.
- Select **Show compact widget** to hide/show the floating display while retaining tray icons.
- Select **Show usage consumed** if you prefer used rather than remaining percentages.
- Select **Start with Windows** for current-user startup (no administrator access required).
- Select **Codex executable > Show detected executable path** to see which CLI will be used.
- Refresh is automatic every five minutes. A failed request shows `--` rather than stale data.

If the notification icons are hidden behind the taskbar's `^` overflow, go to Windows Taskbar settings and enable their visibility.

## Meaning and limitations

The meter uses Codex's app-server protocol: it launches the selected `codex.exe app-server`, initializes JSON-RPC, and requests `account/rateLimits/read`. It reads `usedPercent` for the general Codex bucket; **remaining = 100 - usedPercent**. Windows are identified by duration (300 minutes and 10080 minutes), not by their `primary` / `secondary` labels.

These are percentage limits, **not literal token counts**. Missing windows display `--`, not an invented zero. The Codex app-server interface may change with extension updates. Compare discrepancies with the [official usage dashboard](https://chatgpt.com/codex/settings/usage).

## Privacy and uninstall

- Does not read your prompts, code, conversation history, browser cookies, or `auth.json`, and does not store tokens. The bundled Codex CLI handles its own existing login.
- Saves display preferences, position, and optionally a manually chosen executable path in `%LOCALAPPDATA%\CodexMiniMeter\settings.json`.
- To uninstall, uncheck **Start with Windows**, close the meter, and delete the app folder. You may also remove the settings folder.

## Troubleshooting

**Both show `--`:** Right-click > **Codex executable > Show detected executable path**. If it reports a file inside your `openai.chatgpt-...-win32-x64` extension, discovery worked. Verify you're signed into the Codex extension and have internet access. The selected executable must support `account/rateLimits/read` and be able to use the extension's authentication state. You can open Command Prompt and run:

```cmd
"C:\Users\YOUR_USER\.vscode\extensions\openai.chatgpt-VERSION-win32-x64\bin\windows-x86_64\codex.exe" login status
```

Replace the example with the exact path shown in the meter. If it reports signed out, try signing into Codex in VS Code and restarting the meter. If you have multiple separate accounts, the monitor may read the one used by that CLI, which might not be the account you intended.

**No executable found:** Check that the Codex extension is actually installed locally rather than only in a Remote SSH, WSL, or container extension host. For an unusual extension directory, use **Select executable...** or set `VSCODE_EXTENSIONS` before launching the meter.

**Manual choice no longer works:** Use **Codex executable > Use automatic detection** to resume following VS Code updates. Manual selections do not auto-switch versions.

**Startup stopped after moving the app:** Uncheck and recheck **Start with Windows** from the new location.

## References

- [Official Codex extension](https://marketplace.visualstudio.com/items?itemName=OpenAI.chatgpt)
- [Codex App Server documentation](https://developers.openai.com/codex/app-server)
- [OpenAI: Using Codex with your ChatGPT plan](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan)
