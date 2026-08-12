using System.Runtime.InteropServices;

namespace Vion.Fixture.WindowsService.Tests;

[TestClass]
public sealed class BuildDescriptionTests
{
    /// <summary>
    ///     The proof that the lane really produced a 64-bit Windows build, asserted from inside a
    ///     running test rather than by inspecting the publish directory.
    /// </summary>
    [TestMethod]
    public void TheBuildIsWindowsX64()
    {
        Assert.IsTrue(BuildDescription.IsWindows, "the fixture must build and run as Windows");
        Assert.AreEqual(Architecture.X64, BuildDescription.ProcessArchitecture);
        Assert.AreEqual("win-x64", BuildDescription.RuntimeIdentifier);
    }

    /// <summary>
    ///     A test that fails would fail the lane — this pins that the caller-supplied test command
    ///     is actually executing assertions and not merely starting a process that exits 0.
    /// </summary>
    [TestMethod]
    public void TheDescriptionNamesTheRuntimeIdentifier()
    {
        StringAssert.Contains(BuildDescription.ForCurrentProcess(), "rid=win-x64");
    }
}
