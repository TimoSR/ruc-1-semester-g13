#!/usr/bin/env dotnet-script
#r "nuget: dotenv.net, 3.1.0"

using System.Diagnostics;
using System.IO;
using DotEnv.Core;

// Load environment variables from `.env`
new EnvLoader().Load();

// Access variables
var dbName = Environment.GetEnvironmentVariable("DB_NAME");
var dbUrlAdmin = Environment.GetEnvironmentVariable("DB_URL_ADMIN");
var dbUrlTarget = Environment.GetEnvironmentVariable("DB_URL_TARGET");

if (string.IsNullOrWhiteSpace(dbName))
{
    Console.ForegroundColor = ConsoleColor.Red;
    Console.WriteLine("❌ Failed to load .env file or DB_NAME is missing.");
    Console.ResetColor();
    Environment.Exit(1);
}

void Run(string fileName, string args)
{
    var psi = new ProcessStartInfo
    {
        FileName = fileName,
        Arguments = args,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        UseShellExecute = false,
        CreateNoWindow = true
    };

    var process = Process.Start(psi);
    if (process == null)
        throw new Exception($"Failed to start process: {fileName}");

    process.OutputDataReceived += (_, e) => { if (e.Data != null) Console.WriteLine(e.Data); };
    process.ErrorDataReceived += (_, e) => { if (e.Data != null) Console.Error.WriteLine(e.Data); };

    process.BeginOutputReadLine();
    process.BeginErrorReadLine();
    process.WaitForExit();

    if (process.ExitCode != 0)
    {
        throw new Exception($"{fileName} exited with code {process.ExitCode}");
    }
}

// Run psql commands
Console.WriteLine($"🧨 Terminating active connections on {dbName}...");
Run("psql", $"{dbUrlAdmin} -c \"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{dbName}' AND pid <> pg_backend_pid();\"");

Console.WriteLine($"💣 Dropping database {dbName}...");
Run("psql", $"{dbUrlAdmin} -c \"DROP DATABASE IF EXISTS \\\"{dbName}\\\";\"");

Console.WriteLine($"🛠️  Creating database {dbName}...");
Run("psql", $"{dbUrlAdmin} -c \"CREATE DATABASE \\\"{dbName}\\\";\"");

Console.WriteLine("📦 Running init.sql (includes schema and seed)...");
Run("psql", $"{dbUrlTarget} -f init.sql");

Console.ForegroundColor = ConsoleColor.Green;
Console.WriteLine("✅ Database setup complete.");
Console.ResetColor();
