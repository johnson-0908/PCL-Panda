namespace PCLCS
{
    /// <summary>
    /// Independent local palettes for this fork, not upstream's private theme effects.
    /// No activation, account, donation state, or file access is involved.
    /// </summary>
    public sealed class PandaThemePalette
    {
        public int Id { get; private set; }
        public int Hue { get; private set; }
        public int Saturation { get; private set; }
        public int Delta { get; private set; }
        public int LightAdjustment { get; private set; }

        // Hue, saturation, title-bar gradient span, lightness adjustment.
        private static readonly int[,] Presets =
        {
            { 210, 85,  0,   0 },
            { 175, 70, 10,  -4 },
            { 125, 55, 10,  -7 },
            {  50, 90,  8, -12 },
            {  27, 45,  0, -10 },
            { 210,  0,  0, -12 },
            { 325, 65,  8,   0 },
            { 275, 65, 12,   0 },
            {  40, 65,  6,  -8 },
            {  25, 90, 12,  -4 },
            {   0, 70,  6,  -3 },
            { 220, 70, 18,  -8 },
            { 190, 75, 90,   0 },
            {  45, 75, 35,   0 }
        };

        public static PandaThemePalette Resolve(int id, int customHue = 180,
            int customSaturation = 80, int customDelta = 90, int customLight = 20)
        {
            if (id < 0 || id > 14) id = 0;
            if (id == 14)
            {
                return new PandaThemePalette
                {
                    Id = id,
                    Hue = Clamp(customHue, 0, 360) % 360,
                    Saturation = Clamp(customSaturation, 0, 100),
                    Delta = Clamp(customDelta, 0, 180) - 90,
                    LightAdjustment = Clamp(customLight, 0, 40) - 20
                };
            }
            return new PandaThemePalette
            {
                Id = id,
                Hue = Presets[id, 0],
                Saturation = Presets[id, 1],
                Delta = Presets[id, 2],
                LightAdjustment = Presets[id, 3]
            };
        }

        private static int Clamp(int value, int minimum, int maximum)
        {
            return System.Math.Max(minimum, System.Math.Min(maximum, value));
        }
    }
}
