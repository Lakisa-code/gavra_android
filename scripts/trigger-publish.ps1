<#
Trigger a GitHub tag/release to run the publish workflow. Requires Git + gh auth on your machine.

USAGE: .\scripts\trigger-publish.ps1 -TagName v1.0.0 -Message "Auto publish"
#>

param(
    [string]$TagName = "v$(Get-Date -Format yyyyMMddHHmmss)",
    [string]$Message = "Automated publish from CI"
)

$current = git rev-parse --abbrev-ref HEAD
Write-Host "Current branch: $current"
Write-Host "Creating tag $TagName and pushing to origin..."

git tag -a $TagName -m "$Message"
git push origin $TagName

Write-Host "Tag pushed. The publish workflow will be triggered for tag $TagName."
