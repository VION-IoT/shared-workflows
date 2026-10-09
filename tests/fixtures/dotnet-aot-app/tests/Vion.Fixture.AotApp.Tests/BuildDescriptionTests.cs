using System.Runtime.InteropServices;

namespace Vion.Fixture.AotApp.Tests;

[TestClass]
public sealed class BuildDescriptionTests
{
    /// <summary>
    ///     The workflow runs this on Linux in build-test-style and on Windows in test-win-x64; it
    ///     holds on both.
    /// </summary>
    [TestMethod]
    public void TheDescriptionNamesTheRunningArchitecture()
    {
        StringAssert.Contains(BuildDescription.ForCurrentProcess(),
                              $"arch={RuntimeInformation.ProcessArchitecture}");
    }
}
