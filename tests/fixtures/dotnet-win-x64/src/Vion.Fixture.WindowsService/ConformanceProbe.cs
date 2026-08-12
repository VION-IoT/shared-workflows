namespace Vion.Fixture.WindowsService;

/// <summary>
///     Stands in for the real Mender round-trip when proving
///     <c>.github/workflows/mender-conformance.yml</c>. It cannot round-trip anything — the
///     management API is IP-whitelisted away from GitHub-hosted runners — so it asserts the one
///     thing the template is responsible for instead: that the executable is launched with the
///     endpoint configuration and the dedicated CI device identity in its environment.
/// </summary>
public static class ConformanceProbe
{
    public const string Verb = "conformance-probe";

    /// <summary>
    ///     Comma-separated names of the variables that must be present and non-empty. Supplied by
    ///     the caller so the fixture asserts the caller's own naming rather than a name this
    ///     repository invented.
    /// </summary>
    public const string RequiredVariablesVariable = "FIXTURE_REQUIRED_VARIABLES";

    private const char VariableSeparator = ',';

    public static int Run(TextWriter output)
    {
        var declaration = Environment.GetEnvironmentVariable(RequiredVariablesVariable);
        if (string.IsNullOrWhiteSpace(declaration))
        {
            output.WriteLine($"{RequiredVariablesVariable} is not set; nothing to assert.");
            return 1;
        }

        var missing = new List<string>();
        foreach (var name in declaration.Split(VariableSeparator, StringSplitOptions.RemoveEmptyEntries |
                                                                  StringSplitOptions.TrimEntries))
        {
            // Never the value: one of these is the device identity, which arrives as a secret.
            var isSet = !string.IsNullOrEmpty(Environment.GetEnvironmentVariable(name));
            output.WriteLine($"{name}: {(isSet ? "set" : "MISSING")}");
            if (!isSet)
            {
                missing.Add(name);
            }
        }

        if (missing.Count > 0)
        {
            output.WriteLine($"conformance-probe failed: {string.Join(", ", missing)} not in the environment.");
            return 1;
        }

        output.WriteLine("conformance-probe passed: the round-trip environment is complete.");
        return 0;
    }
}
