using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace CodexMiniMeter;

internal static class TrayIconFactory
{
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr handle);

    public static Icon Make(UsageWindow? window, bool showUsed, bool isWeekly)
    {
        var number = window is null ? "--"
            : Math.Round(window.Percentage(showUsed), MidpointRounding.AwayFromZero).ToString("0");
        var background = window is null ? Color.FromArgb(103, 109, 118)
            : window.RemainingPercent <= 15 ? Color.FromArgb(180, 58, 58)
            : isWeekly ? Color.FromArgb(15, 116, 101) : Color.FromArgb(39, 91, 175);

        using var bitmap = new Bitmap(64, 64);
        using (var g = Graphics.FromImage(bitmap))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
            g.Clear(Color.Transparent);
            using var brush = new SolidBrush(background);
            g.FillEllipse(brush, new Rectangle(1, 1, 62, 62));
            var fontSize = number.Length == 3 ? 26f : 34f;
            using var font = new Font("Segoe UI", fontSize, FontStyle.Bold, GraphicsUnit.Pixel);
            using var white = new SolidBrush(Color.White);
            using var layout = new StringFormat
            {
                Alignment = StringAlignment.Center,
                LineAlignment = StringAlignment.Center,
                FormatFlags = StringFormatFlags.NoWrap
            };
            g.DrawString(number, font, white, new RectangleF(0, -1, 64, 65), layout);
        }

        var nativeIcon = bitmap.GetHicon();
        try
        {
            using var temporary = Icon.FromHandle(nativeIcon);
            return (Icon)temporary.Clone();
        }
        finally
        {
            DestroyIcon(nativeIcon);
        }
    }
}
