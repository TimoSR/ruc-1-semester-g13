#!/usr/bin/env dotnet-script
#r "nuget: dotenv.net, 3.1.0"

using System;
using System.Diagnostics;
using dotenv.net;

// Load .env (current directory)
DotEnv.Fluent().WithEnvFiles(".env").WithTrimValues().WithOverwriteExistingVars().Load();

// Read env vars
var dbName      = Environment.GetEnvironmentVariable("DB_NAME");
var dbUrlAdmin  = Environment.GetEnvironmentVariable("DB_URL_ADMIN");
var dbUrlTarget = Environment.GetEnvironmentVariable("DB_URL_TARGET");

if (string.IsNullOrWhiteSpace(dbName) ||
    string.IsNullOrWhiteSpace(dbUrlAdmin) ||
    string.IsNullOrWhiteSpace(dbUrlTarget))
{
    Console.Error.WriteLine("❌ Missing DB_NAME / DB_URL_ADMIN / DB_URL_TARGET in .env");
    Environment.Exit(1);
}

int Run(string file, params string[] args)
{
    var psi = new ProcessStartInfo { FileName = file, RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false };
    foreach (var a in args) psi.ArgumentList.Add(a);
    using var p = new Process { StartInfo = psi };
    p.OutputDataReceived += (_, e) => { if (e.Data != null) Console.WriteLine(e.Data); };
    p.ErrorDataReceived  += (_, e) => { if (e.Data != null) Console.Error.WriteLine(e.Data); };
    if (!p.Start()) { Console.Error.WriteLine($"❌ Failed to start: {file}"); return 1; }
    p.BeginOutputReadLine(); p.BeginErrorReadLine(); p.WaitForExit(); return p.ExitCode;
}

string ident = dbName.Replace("\"","\"\"");   // for "Identifier"
string lit   = dbName.Replace("'","''");     // for 'literal'

Console.WriteLine($"🧨 Terminating active connections on {dbName}...");
if (Run("psql", dbUrlAdmin, "-c",
    $@"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{lit}' AND pid <> pg_backend_pid();") != 0) Environment.Exit(1);

Console.WriteLine($"💣 Dropping database {dbName}...");
if (Run("psql", dbUrlAdmin, "-c", $@"DROP DATABASE IF EXISTS ""{ident}"";") != 0) Environment.Exit(1);

Console.WriteLine($"🛠️  Creating database {dbName}...");
if (Run("psql", dbUrlAdmin, "-c", $@"CREATE DATABASE ""{ident}"";") != 0) Environment.Exit(1);

Console.WriteLine("📦 Running init.sql (includes schema and seed)...");
if (Run("psql", dbUrlTarget, "-f", "init.sql") != 0) Environment.Exit(1);

Console.WriteLine("✅ Database setup complete.");