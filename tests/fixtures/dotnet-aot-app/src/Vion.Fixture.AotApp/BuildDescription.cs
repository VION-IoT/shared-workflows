using System.Runtime.InteropServices;

namespace Vion.Fixture.AotApp;

/// <summary>
///     Reports what the running build is, so a published executable can say which target it was
///     built for.
/// </summary>
public static class BuildDescription
{
    public static string ForCurrentProcess() =>
        $"rid={RuntimeInformation.RuntimeIdentifier} arch={RuntimeInformation.ProcessArchitecture}";
}
