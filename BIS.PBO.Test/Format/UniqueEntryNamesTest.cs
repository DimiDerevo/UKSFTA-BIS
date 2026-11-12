using Xunit;

namespace BIS.PBO.Test.Format
{
    public class UniqueEntryNamesTest
    {
        [Fact]
        public void Allocate_ExtensionOnlyNames_GetPlaceholderStems()
        {
            var names = new UniqueEntryNames();
            Assert.Equal("data\\UI\\UI_001.paa", names.Allocate("data\\UI\\.paa"));
            Assert.Equal("data\\UI\\UI_002.paa", names.Allocate("data\\UI\\.paa"));
            Assert.Equal("file_001.p3d", names.Allocate(".p3d"));
            Assert.Equal("file_002.p3d", names.Allocate(".p3d"));
        }

        [Fact]
        public void Allocate_DuplicateNames_GetNumericSuffix_CaseInsensitive()
        {
            var names = new UniqueEntryNames();
            Assert.Equal("data/_co.paa", names.Allocate("data/_co.paa"));
            Assert.Equal("data/_CO_2.paa", names.Allocate("data/_CO.paa"));
            Assert.Equal("data\\_co_3.paa", names.Allocate("data\\_co.paa"));
        }

        [Fact]
        public void Allocate_PlaceholderSkipsReservedNames()
        {
            var names = new UniqueEntryNames();
            names.Reserve("ui/ui_001.paa");
            Assert.Equal("ui/ui_002.paa", names.Allocate("ui/.paa"));
        }

        [Fact]
        public void Allocate_LeadingSeparator_IsRemoved()
        {
            var names = new UniqueEntryNames();
            Assert.Equal("beards.p3d", names.Allocate("/beards.p3d"));
            Assert.Equal("beards_2.p3d", names.Allocate("\\beards.p3d"));
        }

        [Fact]
        public void Allocate_UnknownDirectory_UsesFileStem()
        {
            var names = new UniqueEntryNames();
            Assert.Equal("_unknown\\file_001.bin", names.Allocate("_unknown\\.bin"));
        }
    }
}
