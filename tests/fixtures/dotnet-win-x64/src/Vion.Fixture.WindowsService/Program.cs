namespace Vion.Fixture.WindowsService;

/// <summary>
///     Stand-in for a VION Windows service. Exists so <c>.github/workflows/dotnet-win-x64.yml</c>
///     has something real to build, test and publish self-contained, and so
///     <c>.github/workflows/mender-conformance.yml</c> has a real <c>win-x64</c> executable to run
///     as its round-trip. It deliberately carries no dependencies beyond the framework.
/// </summary>
public static class Program
{
    public static int Main(string[] arguments)
    {
        Console.WriteLine(BuildDescription.ForCurrentProcess());

        if (arguments.Length > 0 && arguments[0] == ConformanceProbe.Verb)
        {
            return ConformanceProbe.Run(Console.Out);
        }

        return 0;
    }
}
