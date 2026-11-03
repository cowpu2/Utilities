using System.Text.Json;

namespace CodexMiniMeter;

internal sealed class AppSettings
{
    public AppSettings() { }
    public bool ShowWidget { get; set; } = true;
    public bool ShowUsed { get; set; }
    public string? CodexExecutablePath { get; set; } // Null means automatic discovery.
    public int? WidgetX { get; set; }
    public int? WidgetY { get; set; }

    private static string FilePath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "CodexMiniMeter", "settings.json");

    public static AppSettings Load()
    {
        try
        {
            if (File.Exists(FilePath))
                return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath)) ?? new();
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException)
        {
            // A corrupted or inaccessible settings file should not block startup.
        }
        return new();
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this,
                new JsonSerializerOptions { WriteIndented = true }));
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Nonessential preferences; the live meter remains functional.
        }
    }
}
