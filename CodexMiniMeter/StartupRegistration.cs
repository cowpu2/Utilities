using Microsoft.Win32;

namespace CodexMiniMeter;

internal static class StartupRegistration
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string EntryName = "CodexMiniMeter";

    public static bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(EntryName) is string;
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey)
            ?? throw new InvalidOperationException("Cannot open the Windows per-user Run key.");
        if (enabled)
            key.SetValue(EntryName, $"\"{Application.ExecutablePath}\"", RegistryValueKind.String);
        else
            key.DeleteValue(EntryName, throwOnMissingValue: false);
    }
}
