namespace CodexMiniMeter;

internal sealed record UsageWindow(double UsedPercent, int DurationMinutes, DateTimeOffset? ResetsAt)
{
    public double RemainingPercent => Math.Clamp(100d - UsedPercent, 0d, 100d);
    public double Percentage(bool showUsed) => showUsed ? Math.Clamp(UsedPercent, 0d, 100d) : RemainingPercent;
}

internal sealed record UsageSnapshot(UsageWindow? FiveHour, UsageWindow? Weekly, DateTimeOffset FetchedAt);

internal static class MeterText
{
    public static string Percent(UsageWindow? window, bool showUsed) =>
        window is null ? "--" : $"{Math.Round(window.Percentage(showUsed), MidpointRounding.AwayFromZero):0}%";

    public static string Reset(UsageWindow? window) => window?.ResetsAt is { } at
        ? at.LocalDateTime.ToString("ddd MMM d, h:mm tt") : "not provided";
}
