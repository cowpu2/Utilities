using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace CodexMiniMeter;

internal sealed class MeterWidget : Form
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool ReleaseCapture();

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    private static extern IntPtr SendMessage(IntPtr hwnd, int message, IntPtr wparam, IntPtr lparam);

    private const int WmNcLButtonDown = 0x00A1;
    private const int HtCaption = 2;
    private const int WmExitSizeMove = 0x0232;
    private readonly Font _labelFont = new("Segoe UI", 9f, FontStyle.Regular);
    private readonly Font _valueFont = new("Segoe UI", 12f, FontStyle.Bold);
    private readonly ToolTip _tooltip = new();
    private string _five = "--";
    private string _weekly = "--";
    private string _detail = "Connecting to Codex...";

    public event EventHandler? FinishedMoving;

    public MeterWidget(ContextMenuStrip menu)
    {
        FormBorderStyle = FormBorderStyle.None;
        ClientSize = new Size(216, 43);
        BackColor = Color.FromArgb(30, 34, 40);
        ForeColor = Color.White;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        DoubleBuffered = true;
        Opacity = 0.97;
        ContextMenuStrip = menu;
        _tooltip.SetToolTip(this, _detail);
        ApplyRoundedRegion();
    }

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            var cp = base.CreateParams;
            cp.ExStyle |= 0x00000080 | 0x08000000; // TOOLWINDOW | NOACTIVATE
            return cp;
        }
    }

    public void SetReading(UsageSnapshot? usage, bool showUsed, string? error)
    {
        _five = MeterText.Percent(usage?.FiveHour, showUsed);
        _weekly = MeterText.Percent(usage?.Weekly, showUsed);
        var mode = showUsed ? "used" : "remaining";
        _detail = error is not null
            ? $"Codex: {error}"
            : usage is null ? "No Codex data yet."
            : $"5h: {_five} {mode}, resets {MeterText.Reset(usage.FiveHour)}\n"
            + $"Week: {_weekly} {mode}, resets {MeterText.Reset(usage.Weekly)}\n"
            + $"Updated {usage.FetchedAt.LocalDateTime:t}";
        _tooltip.SetToolTip(this, _detail);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using var outline = new Pen(Color.FromArgb(85, 96, 109), 1);
        using var divider = new Pen(Color.FromArgb(78, 89, 101), 1);
        using var borderPath = RoundedRect(new Rectangle(0, 0, Width - 1, Height - 1), 10);
        g.DrawPath(outline, borderPath);
        g.DrawLine(divider, 108, 8, 108, 35);

        var flags = TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding
            | TextFormatFlags.SingleLine;
        TextRenderer.DrawText(g, "5h", _labelFont, new Rectangle(10, 7, 30, 30),
            Color.FromArgb(172, 188, 204), flags);
        TextRenderer.DrawText(g, _five, _valueFont, new Rectangle(39, 6, 68, 32),
            Color.White, flags);
        TextRenderer.DrawText(g, "Wk", _labelFont, new Rectangle(119, 7, 29, 30),
            Color.FromArgb(172, 188, 204), flags);
        TextRenderer.DrawText(g, _weekly, _valueFont, new Rectangle(151, 6, 63, 32),
            Color.White, flags);
    }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        base.OnMouseDown(e);
        if (e.Button == MouseButtons.Left)
        {
            ReleaseCapture();
            SendMessage(Handle, WmNcLButtonDown, (IntPtr)HtCaption, IntPtr.Zero);
        }
    }

    protected override void WndProc(ref Message m)
    {
        base.WndProc(ref m);
        if (m.Msg == WmExitSizeMove)
            FinishedMoving?.Invoke(this, EventArgs.Empty);
    }

    private void ApplyRoundedRegion()
    {
        using var path = RoundedRect(new Rectangle(0, 0, Width, Height), 10);
        Region = new Region(path);
    }

    private static GraphicsPath RoundedRect(Rectangle rectangle, int radius)
    {
        var path = new GraphicsPath();
        var size = radius * 2;
        path.AddArc(rectangle.X, rectangle.Y, size, size, 180, 90);
        path.AddArc(rectangle.Right - size, rectangle.Y, size, size, 270, 90);
        path.AddArc(rectangle.Right - size, rectangle.Bottom - size, size, size, 0, 90);
        path.AddArc(rectangle.X, rectangle.Bottom - size, size, size, 90, 90);
        path.CloseFigure();
        return path;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _labelFont.Dispose();
            _valueFont.Dispose();
            _tooltip.Dispose();
        }
        base.Dispose(disposing);
    }
}
