namespace Vion.Fixture.AotApp;

/// <summary>
///     Stand-in for a VION NativeAOT app. Exists so <c>.github/workflows/dotnet-aot-app.yml</c> has
///     something real to build, test and publish for linux-musl-x64, linux-musl-arm64 and win-x64. It
///     deliberately carries no dependencies beyond the framework.
/// </summary>
public static class Program
{
    public static int Main()
    {
        Console.WriteLine(BuildDescription.ForCurrentProcess());
        return 0;
    }
}
