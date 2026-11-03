namespace CodexMiniMeter;

internal static class SelfTests
{
    public static void Run()
    {
        var normal = """
        {"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":28,"windowDurationMins":300,"resetsAt":1793450000},"secondary":{"usedPercent":57,"windowDurationMins":10080,"resetsAt":1793970000}}}}
        """;
        var a = RateLimitParser.ParseResponse(normal);
        Check(a.FiveHour?.RemainingPercent == 72, "5h remaining percentage");
        Check(a.Weekly?.RemainingPercent == 43, "weekly remaining percentage");
        Check(MeterText.Percent(a.FiveHour, false) == "72%", "5h display");
        Check(MeterText.Percent(a.Weekly, true) == "57%", "weekly used display");

        var swapped = """
        {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":70,"windowDurationMins":10080,"resetsAt":1794000000},"secondary":null}}}
        """;
        var b = RateLimitParser.ParseResponse(swapped);
        Check(b.FiveHour is null, "absent 5h must not be invented");
        Check(b.Weekly?.RemainingPercent == 30, "weekly must be classified by duration");
        Check(MeterText.Percent(b.FiveHour, false) == "--", "missing window display");

        var multiBucket = """
        {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":99,"windowDurationMins":300}},"rateLimitsByLimitId":{"codex_other":{"primary":{"usedPercent":90,"windowDurationMins":300}},"codex":{"primary":{"usedPercent":12,"windowDurationMins":300},"secondary":{"usedPercent":7,"windowDurationMins":10080}}}}}
        """;
        var c = RateLimitParser.ParseResponse(multiBucket);
        Check(c.FiveHour?.RemainingPercent == 88, "general Codex bucket priority");
        Check(c.Weekly?.RemainingPercent == 93, "general Codex weekly bucket");

        var oddDuration = """
        {"id":2,"result":{"rateLimits":{"primary":{"usedPercent":12,"windowDurationMins":60},"secondary":null}}}
        """;
        var d = RateLimitParser.ParseResponse(oddDuration);
        Check(d.FiveHour is null && d.Weekly is null, "unknown windows ignored");

        TestCliDiscovery();

        try
        {
            RateLimitParser.ParseResponse("""{"id":2,"error":{"code":-32600,"message":"authentication required"}}""");
            throw new Exception("Error response should throw.");
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("authentication")) { }
    }

    private static void TestCliDiscovery()
    {
        var root = Path.Combine(Path.GetTempPath(), "codex-meter-test-" + Guid.NewGuid().ToString("N"));
        try
        {
            // Deliberately use versions that sort incorrectly alphabetically:
            // 26.1002 must rank ahead of 26.999.
            var oldExe = Path.Combine(root, "openai.chatgpt-26.999.1-win32-x64",
                "bin", "windows-x86_64", "codex.exe");
            var newExe = Path.Combine(root, "openai.chatgpt-26.1002.1-win32-x64",
                "bin", "windows-x86_64", "codex.exe");
            Directory.CreateDirectory(Path.GetDirectoryName(oldExe)!);
            File.WriteAllText(oldExe, "test-only");
            var first = CodexCliLocator.FindVsCodeBundled(new[] { root });
            Check(first?.FileName == oldExe, "find currently installed Codex extension executable");

            Directory.CreateDirectory(Path.GetDirectoryName(newExe)!);
            File.WriteAllText(newExe, "test-only");
            var second = CodexCliLocator.FindVsCodeBundled(new[] { root });
            Check(second?.FileName == newExe, "find newest extension after upgrade");

            File.Delete(newExe);
            var fallback = CodexCliLocator.FindVsCodeBundled(new[] { root });
            Check(fallback?.FileName == oldExe, "ignore incomplete extension upgrade");
            Check(CodexCliLocator.FindVsCodeBundled(new[] { root + "-missing" }) is null,
                "handle absent VS Code installation");
        }
        finally
        {
            if (Directory.Exists(root))
                Directory.Delete(root, recursive: true);
        }
    }

    private static void Check(bool condition, string description)
    {
        if (!condition) throw new Exception($"Test failed: {description}");
    }
}
