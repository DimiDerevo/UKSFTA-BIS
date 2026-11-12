using System;
using System.Collections.Generic;

namespace BIS.PBO
{
    /// <summary>
    /// Allocates unique output paths for PBO entries.
    ///
    /// Obfuscated PBOs often use filenames made only of characters that the
    /// sanitizer strips. Such names collapse to an extension-only name
    /// (for example <c>data\ui\.paa</c>), and many entries get the same path.
    /// Without this allocator, each entry overwrites the previous one on disk.
    ///
    /// Rules:
    /// <list type="bullet">
    /// <item>An extension-only file name gets a placeholder stem made from the
    /// parent directory name and a counter: <c>data\ui\ui_001.paa</c>.</item>
    /// <item>A name that is already in use gets a numeric suffix:
    /// <c>_co.paa</c>, <c>_co_2.paa</c>, <c>_co_3.paa</c>.</item>
    /// </list>
    /// Comparison is case-insensitive, because Windows file systems are
    /// case-insensitive. The separator of the input path is kept.
    /// </summary>
    public sealed class UniqueEntryNames
    {
        private readonly HashSet<string> _used = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, int> _placeholderCounters = new(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// Marks a path as used, so that a later <see cref="Allocate"/> call
        /// does not return it.
        /// </summary>
        public void Reserve(string path) => _used.Add(Normalize(path.TrimStart('/', '\\')));

        /// <summary>True when the file name part of the path has no stem.</summary>
        public static bool HasEmptyStem(string path)
        {
            string file = GetFileName(path);
            if (file.Length == 0) return true;
            return file[0] == '.' && file.IndexOf('.', 1) < 0;
        }

        /// <summary>
        /// Returns a unique path for <paramref name="path"/> and marks it as used.
        /// </summary>
        public string Allocate(string path)
        {
            // Entry paths are relative to the PBO root. A leading separator makes
            // Path.Combine return a rooted path, which writes outside the
            // output directory.
            path = path.TrimStart('/', '\\');

            int sep = Math.Max(path.LastIndexOf('/'), path.LastIndexOf('\\'));
            string dir = sep >= 0 ? path.Substring(0, sep + 1) : "";
            string file = sep >= 0 ? path.Substring(sep + 1) : path;

            string stem;
            string ext;
            if (HasEmptyStem(path))
            {
                stem = "";
                ext = file;
            }
            else
            {
                int dot = file.LastIndexOf('.');
                stem = dot > 0 ? file.Substring(0, dot) : file;
                ext = dot > 0 ? file.Substring(dot) : "";
            }

            if (stem.Length == 0)
                return AllocatePlaceholder(dir, ext);

            string candidate = path;
            for (int n = 2; _used.Contains(Normalize(candidate)); n++)
                candidate = $"{dir}{stem}_{n}{ext}";

            _used.Add(Normalize(candidate));
            return candidate;
        }

        private string AllocatePlaceholder(string dir, string ext)
        {
            string trimmed = dir.TrimEnd('/', '\\');
            int sep = Math.Max(trimmed.LastIndexOf('/'), trimmed.LastIndexOf('\\'));
            string baseName = sep >= 0 ? trimmed.Substring(sep + 1) : trimmed;
            if (baseName.Length == 0 || baseName.StartsWith("_unknown", StringComparison.OrdinalIgnoreCase))
                baseName = "file";

            string key = Normalize(dir);
            _placeholderCounters.TryGetValue(key, out int counter);

            string candidate;
            do
            {
                counter++;
                candidate = $"{dir}{baseName}_{counter:D3}{ext}";
            }
            while (_used.Contains(Normalize(candidate)));

            _placeholderCounters[key] = counter;
            _used.Add(Normalize(candidate));
            return candidate;
        }

        private static string GetFileName(string path)
        {
            int sep = Math.Max(path.LastIndexOf('/'), path.LastIndexOf('\\'));
            return sep >= 0 ? path.Substring(sep + 1) : path;
        }

        private static string Normalize(string path) => path.Replace('\\', '/');
    }
}
