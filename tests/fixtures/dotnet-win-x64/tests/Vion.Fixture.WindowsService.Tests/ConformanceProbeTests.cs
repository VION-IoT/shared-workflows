namespace Vion.Fixture.WindowsService.Tests;

[TestClass]
public sealed class ConformanceProbeTests
{
    private const string FirstVariable = "VION_FIXTURE_PROBE_ONE";
    private const string SecondVariable = "VION_FIXTURE_PROBE_TWO";

    [TestCleanup]
    public void ClearProbeVariables()
    {
        foreach (var name in new[] { ConformanceProbe.RequiredVariablesVariable, FirstVariable, SecondVariable })
        {
            Environment.SetEnvironmentVariable(name, null);
        }
    }

    [TestMethod]
    public void ItPassesWhenEveryDeclaredVariableIsSet()
    {
        Environment.SetEnvironmentVariable(ConformanceProbe.RequiredVariablesVariable,
                                           $"{FirstVariable},{SecondVariable}");
        Environment.SetEnvironmentVariable(FirstVariable, "https://mender.example.invalid");
        Environment.SetEnvironmentVariable(SecondVariable, "00000-00000-00001-vion-beckhoff-cx5130");

        using var output = new StringWriter();
        Assert.AreEqual(0, ConformanceProbe.Run(output));
    }

    [TestMethod]
    public void ItFailsWhenADeclaredVariableIsMissing()
    {
        Environment.SetEnvironmentVariable(ConformanceProbe.RequiredVariablesVariable,
                                           $"{FirstVariable},{SecondVariable}");
        Environment.SetEnvironmentVariable(FirstVariable, "https://mender.example.invalid");

        using var output = new StringWriter();
        Assert.AreEqual(1, ConformanceProbe.Run(output));
        StringAssert.Contains(output.ToString(), $"{SecondVariable}: MISSING");
    }

    /// <summary>
    ///     The probe reports presence, never content — one of the variables it checks carries the
    ///     device identity, which reaches the job as a secret.
    /// </summary>
    [TestMethod]
    public void ItNeverPrintsAVariableValue()
    {
        const string deviceIdentity = "00000-00000-00001-vion-beckhoff-cx5130";
        Environment.SetEnvironmentVariable(ConformanceProbe.RequiredVariablesVariable, FirstVariable);
        Environment.SetEnvironmentVariable(FirstVariable, deviceIdentity);

        using var output = new StringWriter();
        ConformanceProbe.Run(output);
        Assert.IsFalse(output.ToString().Contains(deviceIdentity, StringComparison.Ordinal));
    }
}
