#!/usr/bin/env pwsh
# The failing caller's script in proof-publish-nuget.yml's `gating` job: the exit code a verify
# script gives when it rejects the packages. 3, not 1, so the job can tell this code from a failure
# of its own.
Write-Host 'Rejecting the packages, as a verify script that found a defect would.'
exit 3
