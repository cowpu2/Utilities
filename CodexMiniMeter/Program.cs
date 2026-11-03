using System.Threading;

namespace CodexMiniMeter;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Contains("--self-test", StringComparer.OrdinalIgnoreCase))
        {
            try
            {
                SelfTests.Run();
                MessageBox.Show("All parser self-tests passed.", "Codex Mini Meter");
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.ToString(), "Self-test failure", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Environment.ExitCode = 1;
            }
            return;
        }

        using var mutex = new Mutex(true, @"Local\CodexMiniMeter-9E40CA28", out var firstInstance);
        if (!firstInstance)
            return;

        ApplicationConfiguration.Initialize();
        Application.Run(new TrayApplicationContext());
    }
}
