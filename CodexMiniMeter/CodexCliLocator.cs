namespace CodexMiniMeter;

internal sealed record CodexCliLocation(string FileName, string Source, bool IsCommandLauncher = false);

/// <summary>
/// Finds the Codex CLI that ships inside the user's installed VS Code Codex
/// extension. Re-evaluated before every refresh, so extension upgrades do not
/// leave a stale absolute path in the meter's settings.
/// </summary>
internal static class CodexCliLocator
{
    public static CodexCliLocation Locate(string? userSelectedExecutable = null)
    {
        if (!string.IsNullOrWhiteSpace(userSelectedExecutable))
        {
            var selected = Environment.ExpandEnvironmentVariables(userSelectedExecutable.Trim().Trim('"'));
            if (!File.Exists(selected))
                throw new FileNotFoundException(
                    "The manually selected Codex executable no longer exists. " +
                    "Use 'Codex executable > Use automatic detection' to locate the VS Code extension again.",
                    selected);
            return new CodexCliLocation(selected, "Manually selected executable");
        }

        var bundled = FindVsCodeBundled(GetExtensionRoots());
        if (bundled is not null)
            return bundled;

        // Respect standalone installations as fallbacks, but prefer the VS Code
        // extension so the user's existing installation requires no changes.
        var envOverride = Environment.GetEnvironmentVariable("CODEX_CLI_PATH");
        if (!string.IsNullOrWhiteSpace(envOverride))
        {
            var path = Environment.ExpandEnvironmentVariables(envOverride.Trim().Trim('"'));
            if (File.Exists(path))
                return new CodexCliLocation(path, "CODEX_CLI_PATH environment variable");
        }

        var adjacent = Path.Combine(AppContext.BaseDirectory, "codex.exe");
        if (File.Exists(adjacent))
            return new CodexCliLocation(adjacent, "Next to CodexMiniMeter.exe");

        var installed = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "Programs", "OpenAI", "Codex", "bin", "codex.exe");
        if (File.Exists(installed))
            return new CodexCliLocation(installed, "Standalone Codex installer");

        var onPath = FindOnPath("codex.exe");
        if (onPath is not null)
            return new CodexCliLocation(onPath, "Windows PATH");

        var cmd = FindOnPath("codex.cmd");
        if (cmd is not null)
            return new CodexCliLocation(cmd, "npm command launcher on PATH", true);

        throw new FileNotFoundException(
            "Codex executable not found. Install the OpenAI Codex extension in desktop VS Code " +
            "or choose an executable from 'Codex executable > Select executable...'. " +
            "The meter checks %USERPROFILE%\\.vscode\\extensions and VS Code Insiders.");
    }

    // Internal so the self-test can exercise discovery using throwaway directories,
    // without needing an actual VS Code installation in the build environment.
    internal static CodexCliLocation? FindVsCodeBundled(IEnumerable<string> extensionRoots)
    {
        var candidates = new List<(string Executable, Version Version, DateTime LastWriteUtc)>();
        foreach (var root in extensionRoots.Where(s => !string.IsNullOrWhiteSpace(s))
                     .Distinct(StringComparer.OrdinalIgnoreCase))
        {
            try
            {
                if (!Directory.Exists(root))
                    continue;
                foreach (var extensionDirectory in Directory.EnumerateDirectories(
                             root, "openai.chatgpt-*", SearchOption.TopDirectoryOnly))
                {
                    var name = Path.GetFileName(extensionDirectory);
                    const string prefix = "openai.chatgpt-";
                    const string suffix = "-win32-x64";
                    if (!name.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) ||
                        !name.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                        continue;

                    var versionString = name[prefix.Length..^suffix.Length];
                    if (!Version.TryParse(versionString, out var version))
                        continue;

                    var executable = Path.Combine(extensionDirectory,
                        "bin", "windows-x86_64", "codex.exe");
                    if (File.Exists(executable))
                        candidates.Add((executable, version,
                            Directory.GetLastWriteTimeUtc(extensionDirectory)));
                }
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // A stale, inaccessible, or concurrently updating extension
                // directory must not prevent checking other installation roots.
            }
        }

        var newest = candidates.OrderByDescending(c => c.Version)
            .ThenByDescending(c => c.LastWriteUtc).FirstOrDefault();
        return newest.Executable is null ? null : new CodexCliLocation(
            newest.Executable, "Bundled with VS Code Codex extension");
    }

    private static IEnumerable<string> GetExtensionRoots()
    {
        var configured = Environment.GetEnvironmentVariable("VSCODE_EXTENSIONS");
        if (!string.IsNullOrWhiteSpace(configured))
            yield return Environment.ExpandEnvironmentVariables(configured.Trim().Trim('"'));

        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (!string.IsNullOrEmpty(home))
        {
            yield return Path.Combine(home, ".vscode", "extensions");
            yield return Path.Combine(home, ".vscode-insiders", "extensions");
        }
    }

    private static string? FindOnPath(string fileName)
    {
        var path = Environment.GetEnvironmentVariable("PATH");
        if (string.IsNullOrWhiteSpace(path))
            return null;
        foreach (var directory in path.Split(Path.PathSeparator))
        {
            var trimmed = directory.Trim().Trim('"');
            if (trimmed.Length == 0)
                continue;
            try
            {
                var candidate = Path.Combine(trimmed, fileName);
                if (File.Exists(candidate))
                    return candidate;
            }
            catch (Exception ex) when (ex is ArgumentException or NotSupportedException)
            {
                // Ignore malformed PATH entries.
            }
        }
        return null;
    }
}
