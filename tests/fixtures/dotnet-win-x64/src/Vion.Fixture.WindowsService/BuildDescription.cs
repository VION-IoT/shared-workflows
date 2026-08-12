using System.Runtime.InteropServices;

namespace Vion.Fixture.WindowsService;

/// <summary>
///     Reports what the running build actually is. The test asserts against this rather than
///     against a constant, so the proof fails if the lane ever publishes something other than a
///     64-bit Windows build.
/// </summary>
public static class BuildDescription
{
    public static string RuntimeIdentifier => RuntimeInformation.RuntimeIdentifier;

    public static Architecture ProcessArchitecture => RuntimeInformation.ProcessArchitecture;

    public static bool IsWindows => OperatingSystem.IsWindows();

    public static string ForCurrentProcess() =>
        $"rid={RuntimeIdentifier} arch={ProcessArchitecture} windows={IsWindows}";
}
