using System.Diagnostics;

namespace CodexMiniMeter;

internal sealed class TrayApplicationContext : ApplicationContext
{
    private static readonly Uri UsageUrl = new("https://chatgpt.com/codex/settings/usage");
    private readonly AppSettings _settings = AppSettings.Load();
    private readonly CancellationTokenSource _exit = new();
    private readonly ContextMenuStrip _menu = new();
    private readonly ToolStripMenuItem _showWidgetItem;
    private readonly ToolStripMenuItem _showUsedItem;
    private readonly ToolStripMenuItem _startupItem;
    private readonly NotifyIcon _fiveHourIcon = new();
    private readonly NotifyIcon _weeklyIcon = new();
    private readonly MeterWidget _widget;
    private readonly System.Windows.Forms.Timer _timer = new();
    private UsageSnapshot? _lastUsage;
    private string? _lastError;
    private bool _isRefreshing;
    private bool _closing;

    public TrayApplicationContext()
    {
        _showWidgetItem = new ToolStripMenuItem("Show compact widget")
        {
            Checked = _settings.ShowWidget,
            CheckOnClick = false
        };
        _showWidgetItem.Click += (_, _) => SetWidgetVisible(!_settings.ShowWidget);

        _showUsedItem = new ToolStripMenuItem("Show usage consumed (instead of remaining)")
        {
            Checked = _settings.ShowUsed,
            CheckOnClick = false
        };
        _showUsedItem.Click += (_, _) =>
        {
            _settings.ShowUsed = !_settings.ShowUsed;
            _showUsedItem.Checked = _settings.ShowUsed;
            _settings.Save();
            UpdateDisplays();
        };

        _startupItem = new ToolStripMenuItem("Start with Windows")
        {
            Checked = StartupRegistration.IsEnabled(),
            CheckOnClick = false
        };
        _startupItem.Click += (_, _) => ToggleStartup();

        var executableMenu = new ToolStripMenuItem("Codex executable");
        var chooseExecutable = new ToolStripMenuItem("Select executable...");
        chooseExecutable.Click += async (_, _) =>
        {
            using var dialog = new OpenFileDialog
            {
                Title = "Select the Codex CLI executable",
                Filter = "Codex executable (codex.exe)|codex.exe|Executable files (*.exe)|*.exe",
                CheckFileExists = true,
                FileName = "codex.exe"
            };
            if (dialog.ShowDialog() != DialogResult.OK)
                return;
            _settings.CodexExecutablePath = dialog.FileName;
            _settings.Save();
            await RefreshAsync();
        };
        var autodetectExecutable = new ToolStripMenuItem("Use automatic detection");
        autodetectExecutable.Click += async (_, _) =>
        {
            _settings.CodexExecutablePath = null;
            _settings.Save();
            await RefreshAsync();
        };
        var showExecutable = new ToolStripMenuItem("Show detected executable path");
        showExecutable.Click += (_, _) =>
        {
            try
            {
                var location = CodexCliLocator.Locate(_settings.CodexExecutablePath);
                MessageBox.Show($"Source: {location.Source}\n\n{location.FileName}",
                    "Codex executable in use", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Codex executable not found",
                    MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        };
        executableMenu.DropDownItems.AddRange(new ToolStripItem[]
        {
            showExecutable, autodetectExecutable, chooseExecutable
        });

        var refresh = new ToolStripMenuItem("Refresh now");
        refresh.Click += async (_, _) => await RefreshAsync();
        var openUsage = new ToolStripMenuItem("Open official usage dashboard");
        openUsage.Click += (_, _) =>
        {
            try { Process.Start(new ProcessStartInfo(UsageUrl.AbsoluteUri) { UseShellExecute = true }); }
            catch (Exception ex) { MessageBox.Show(ex.Message, "Cannot open browser"); }
        };
        var exit = new ToolStripMenuItem("Exit");
        exit.Click += (_, _) => ExitApplication();

        _menu.Items.AddRange(new ToolStripItem[]
        {
            _showWidgetItem, _showUsedItem, _startupItem,
            new ToolStripSeparator(), executableMenu, refresh, openUsage,
            new ToolStripSeparator(), exit
        });

        _widget = new MeterWidget(_menu);
        var bounds = Screen.PrimaryScreen?.WorkingArea ?? Screen.FromPoint(Cursor.Position).WorkingArea;
        var defaultPosition = new Point(bounds.Right - _widget.Width - 16,
            bounds.Bottom - _widget.Height - 12);
        var savedPosition = new Point(_settings.WidgetX ?? defaultPosition.X,
            _settings.WidgetY ?? defaultPosition.Y);
        if (!Screen.AllScreens.Any(s => s.WorkingArea.IntersectsWith(
                new Rectangle(savedPosition, _widget.Size))))
            savedPosition = defaultPosition;
        _widget.Location = savedPosition;
        _widget.FinishedMoving += (_, _) =>
        {
            _settings.WidgetX = _widget.Left;
            _settings.WidgetY = _widget.Top;
            _settings.Save();
        };
        if (_settings.ShowWidget)
            _widget.Show();

        _fiveHourIcon.ContextMenuStrip = _menu;
        _weeklyIcon.ContextMenuStrip = _menu;
        _fiveHourIcon.MouseClick += TrayClick;
        _weeklyIcon.MouseClick += TrayClick;
        UpdateDisplays();
        _fiveHourIcon.Visible = true;
        _weeklyIcon.Visible = true;

        // Let the Windows message loop start before the first async refresh.
        // Otherwise a hidden widget might be updated from a worker thread.
        _timer.Interval = 150;
        _timer.Tick += async (_, _) =>
        {
            _timer.Interval = 2 * 60 * 1000;
            await RefreshAsync();
        };
        _timer.Start();
    }

    private void TrayClick(object? sender, MouseEventArgs e)
    {
        if (e.Button == MouseButtons.Left)
            SetWidgetVisible(true);
    }

    private void SetWidgetVisible(bool visible)
    {
        _settings.ShowWidget = visible;
        _showWidgetItem.Checked = visible;
        if (visible) _widget.Show();
        else _widget.Hide();
        _settings.Save();
    }

    private void ToggleStartup()
    {
        try
        {
            StartupRegistration.SetEnabled(!StartupRegistration.IsEnabled());
            _startupItem.Checked = StartupRegistration.IsEnabled();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Unable to update Windows startup", MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
        }
    }

    private async Task RefreshAsync()
    {
        if (_isRefreshing || _closing)
            return;
        _isRefreshing = true;
        try
        {
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(_exit.Token);
            deadline.CancelAfter(TimeSpan.FromSeconds(25));
            _lastUsage = await CodexRateLimitReader.ReadAsync(_settings.CodexExecutablePath, deadline.Token);
            _lastError = null;
        }
        catch (OperationCanceledException) when (!_closing)
        {
            _lastError = "Timed out reading Codex. Check network and CLI sign-in.";
            _lastUsage = null; // Do not present stale measurements as current.
        }
        catch (Exception ex) when (!_closing)
        {
            _lastError = ex.Message;
            _lastUsage = null;
        }
        finally
        {
            _isRefreshing = false;
            if (!_closing)
                UpdateDisplays();
        }
    }

    private void UpdateDisplays()
    {
        _widget.SetReading(_lastUsage, _settings.ShowUsed, _lastError);
        var five = MeterText.Percent(_lastUsage?.FiveHour, _settings.ShowUsed);
        var week = MeterText.Percent(_lastUsage?.Weekly, _settings.ShowUsed);
        var label = _settings.ShowUsed ? "used" : "remaining";
        _fiveHourIcon.Text = $"5h {five} {label}; resets {MeterText.Reset(_lastUsage?.FiveHour)}";
        _weeklyIcon.Text = $"Week {week} {label}; resets {MeterText.Reset(_lastUsage?.Weekly)}";

        var newFive = TrayIconFactory.Make(_lastUsage?.FiveHour, _settings.ShowUsed, false);
        var newWeek = TrayIconFactory.Make(_lastUsage?.Weekly, _settings.ShowUsed, true);
        var oldFive = _fiveHourIcon.Icon;
        var oldWeek = _weeklyIcon.Icon;
        _fiveHourIcon.Icon = newFive;
        _weeklyIcon.Icon = newWeek;
        oldFive?.Dispose();
        oldWeek?.Dispose();
    }

    private void ExitApplication()
    {
        _closing = true;
        _exit.Cancel();
        _timer.Stop();
        _settings.WidgetX = _widget.Left;
        _settings.WidgetY = _widget.Top;
        _settings.Save();
        _fiveHourIcon.Visible = false;
        _weeklyIcon.Visible = false;
        ExitThread();
    }

    protected override void ExitThreadCore()
    {
        _closing = true;
        _exit.Cancel();
        _timer.Stop();
        _timer.Dispose();
        _fiveHourIcon.Visible = false;
        _weeklyIcon.Visible = false;
        _fiveHourIcon.Icon?.Dispose();
        _weeklyIcon.Icon?.Dispose();
        _fiveHourIcon.Dispose();
        _weeklyIcon.Dispose();
        _widget.Dispose();
        _menu.Dispose();
        _exit.Dispose();
        base.ExitThreadCore();
    }
}
