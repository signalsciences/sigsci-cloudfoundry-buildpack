echo "running sigsci buildpack detect step on windows"

if ($env:OS -eq "Windows_NT") {
    exit 0
} else {
    exit 1
}
