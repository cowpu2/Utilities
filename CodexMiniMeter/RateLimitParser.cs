using System.Text.Json;

namespace CodexMiniMeter;

internal static class RateLimitParser
{
    public static UsageSnapshot ParseResponse(string response)
    {
        using var doc = JsonDocument.Parse(response);
        var root = doc.RootElement;
        if (TryObject(root, "error", out var rpcError))
        {
            var message = ReadString(rpcError, "message") ?? "Unknown app-server error.";
            throw new InvalidOperationException($"Codex returned an error: {message}");
        }

        if (!TryObject(root, "result", out var result))
            throw new FormatException("Codex did not return a rate-limit result.");

        JsonElement limits;
        if (TryObject(result, "rateLimitsByLimitId", out var buckets)
            && TryObject(buckets, "codex", out var codexBucket))
        {
            limits = codexBucket;
        }
        else if (TryObject(result, "rateLimits", out var singleBucket))
        {
            limits = singleBucket;
        }
        else
        {
            throw new FormatException("No general Codex rate-limit bucket was returned.");
        }

        UsageWindow? fiveHour = null;
        UsageWindow? weekly = null;

        foreach (var slot in new[] { "primary", "secondary" })
        {
            if (!TryObject(limits, slot, out var item))
                continue;

            if (!TryNumber(item, "windowDurationMins", out var duration)
                || !TryNumber(item, "usedPercent", out var used)
                || !double.IsFinite(used))
                continue;

            var durationMins = (int)duration;
            if (durationMins is not (300 or 10080))
                continue;

            DateTimeOffset? reset = null;
            if (TryNumber(item, "resetsAt", out var resetSeconds)
                && resetSeconds > 0 && resetSeconds < 253402300799)
            {
                reset = DateTimeOffset.FromUnixTimeSeconds((long)resetSeconds);
            }

            var window = new UsageWindow(Math.Clamp(used, 0, 100), durationMins, reset);
            if (durationMins == 300)
                fiveHour = window;
            else
                weekly = window;
        }

        return new UsageSnapshot(fiveHour, weekly, DateTimeOffset.Now);
    }

    private static bool TryObject(JsonElement parent, string name, out JsonElement child)
    {
        child = default;
        return parent.ValueKind == JsonValueKind.Object
            && parent.TryGetProperty(name, out child)
            && child.ValueKind == JsonValueKind.Object;
    }

    private static bool TryNumber(JsonElement parent, string key, out double result)
    {
        result = 0;
        return parent.ValueKind == JsonValueKind.Object
            && parent.TryGetProperty(key, out var prop)
            && prop.ValueKind == JsonValueKind.Number
            && prop.TryGetDouble(out result);
    }

    private static string? ReadString(JsonElement parent, string key) =>
        parent.TryGetProperty(key, out var prop) && prop.ValueKind == JsonValueKind.String
            ? prop.GetString() : null;
}
