using System.ComponentModel;
using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace CodexMiniMeter;

/// <summary>
/// Requests Codex account limits through the local app-server protocol.
/// Finds the VS Code extension executable afresh for each refresh, rather than
/// storing a version-specific CLI path. Never opens auth.json or transcripts.
/// </summary>
internal static class CodexRateLimitReader
{
    public static async Task<UsageSnapshot> ReadAsync(
        string? selectedExecutable, CancellationToken cancellationToken)
    {
        var location = CodexCliLocator.Locate(selectedExecutable);
        using var process = new Process { StartInfo = CreateStartInfo(location) };
        try
        {
            try
            {
                if (!process.Start())
                    throw new InvalidOperationException("Could not start Codex app-server.");
            }
            catch (Win32Exception ex)
            {
                throw new InvalidOperationException(
                    $"Could not launch Codex from: {location.FileName}. " +
                    "If VS Code is updating, retry in a moment, or choose another executable from the tray menu.", ex);
            }

            // Drain stderr to avoid deadlocks. It might contain sensitive local
            // diagnostics and is intentionally not displayed or saved.
            _ = process.StandardError.ReadToEndAsync(cancellationToken);

            await SendAsync(process, new
            {
                id = 1,
                method = "initialize",
                @params = new { clientInfo = new { name = "codex-mini-meter", version = "1.2.0" } }
            }, cancellationToken);
            await ReceiveAsync(process, 1, cancellationToken);

            await SendAsync(process, new { method = "initialized" }, cancellationToken);
            await SendAsync(process, new { id = 2, method = "account/rateLimits/read" }, cancellationToken);

            var json = await ReceiveAsync(process, 2, cancellationToken);
            return RateLimitParser.ParseResponse(json);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new TimeoutException("The Codex usage request timed out.");
        }
        finally
        {
            try
            {
                if (process.Id != 0 && !process.HasExited)
                    process.Kill(entireProcessTree: true);
            }
            catch (InvalidOperationException) { }
            catch (Win32Exception) { }
        }
    }

    private static ProcessStartInfo CreateStartInfo(CodexCliLocation location)
    {
        if (!location.IsCommandLauncher)
        {
            var direct = MakeStartInfo(location.FileName);
            direct.ArgumentList.Add("app-server");
            return direct;
        }

        // Legacy npm fallback. Run through cmd.exe; never invoke PowerShell.
        var cmd = MakeStartInfo("cmd.exe");
        cmd.ArgumentList.Add("/d");
        cmd.ArgumentList.Add("/s");
        cmd.ArgumentList.Add("/c");
        cmd.ArgumentList.Add($"\"\"{location.FileName}\" app-server\"");
        return cmd;
    }

    private static ProcessStartInfo MakeStartInfo(string executable) => new()
    {
        FileName = executable,
        UseShellExecute = false,
        RedirectStandardInput = true,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        StandardInputEncoding = new UTF8Encoding(false),
        StandardOutputEncoding = Encoding.UTF8,
        StandardErrorEncoding = Encoding.UTF8,
        CreateNoWindow = true,
        WindowStyle = ProcessWindowStyle.Hidden,
    };

    private static async Task SendAsync(Process process, object message, CancellationToken cancellationToken)
    {
        var json = JsonSerializer.Serialize(message);
        await process.StandardInput.WriteLineAsync(json.AsMemory(), cancellationToken);
        await process.StandardInput.FlushAsync(cancellationToken);
    }

    private static async Task<string> ReceiveAsync(Process process, int id, CancellationToken cancellationToken)
    {
        while (true)
        {
            string? line = await process.StandardOutput.ReadLineAsync(cancellationToken);
            if (line is null)
                throw new InvalidOperationException(
                    "Codex CLI ended without responding. Verify that you are signed into " +
                    "the Codex extension with your ChatGPT account.");

            try
            {
                using var doc = JsonDocument.Parse(line);
                var root = doc.RootElement;
                if (root.ValueKind == JsonValueKind.Object
                    && root.TryGetProperty("id", out var responseId)
                    && responseId.ValueKind == JsonValueKind.Number
                    && responseId.TryGetInt32(out var value)
                    && value == id)
                    return line;
            }
            catch (JsonException)
            {
                // Some CLI versions output a launcher banner; skip non-JSON.
            }
        }
    }
}
