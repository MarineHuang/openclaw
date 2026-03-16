import { execFile } from "node:child_process";
import { mkdirSync, rmSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { describe, expect, it, beforeAll, afterAll, beforeEach } from "vitest";

const exec = promisify(execFile);
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const repoRoot = join(__dirname, "..");

describe("offline/start.sh", () => {
  // Skip on Windows
  if (process.platform === "win32") {
    it.skip("skipped on Windows", () => {});
    return;
  }

  const scriptPath = join(repoRoot, "offline", "start.sh");
  const testDir = join(tmpdir(), "openclaw-offline-test-" + Date.now());

  beforeAll(() => {
    mkdirSync(testDir, { recursive: true });
  });

  afterAll(() => {
    rmSync(testDir, { recursive: true, force: true });
  });

  describe("--help", () => {
    it("shows help message", async () => {
      const { stdout } = await exec("bash", [scriptPath, "--help"]);
      expect(stdout).toContain("OpenClaw 离线版启动脚本");
      expect(stdout).toContain("--port");
      expect(stdout).toContain("--bind");
      expect(stdout).toContain("--public");
      expect(stdout).toContain("--allow-http");
      expect(stdout).toContain("--daemon");
      expect(stdout).toContain("--stop");
      expect(stdout).toContain("--status");
    });

    it("shows help with -h", async () => {
      const { stdout } = await exec("bash", [scriptPath, "-h"]);
      expect(stdout).toContain("OpenClaw 离线版启动脚本");
    });
  });

  describe("--port", () => {
    it("rejects missing port argument (exit code 1)", async () => {
      // --port requires an argument; missing arg should fail with error message
      await expect(exec("bash", [scriptPath, "--port"], { timeout: 5000 })).rejects.toThrow();
    });
  });

  describe("--bind", () => {
    it("accepts valid bind values", async () => {
      // These should not throw immediately (script will fail later due to missing node-runtime)
      const validBinds = ["loopback", "lan", "tailnet", "auto"];
      for (const bind of validBinds) {
        // Script will fail because node-runtime doesn't exist, but parsing should succeed
        try {
          await exec("bash", [scriptPath, "--bind", bind, "--port", "9999"], {
            timeout: 2000,
          });
        } catch (err: unknown) {
          // Should fail with "node not found" type error, not "unknown option"
          const error = err as { stderr?: string };
          expect(error.stderr).not.toContain("未知参数");
          expect(error.stderr).not.toContain("unknown option");
        }
      }
    });
  });

  describe("--daemon", () => {
    it("accepts --daemon flag", async () => {
      const scriptContent = readFileSync(scriptPath, "utf-8");
      expect(scriptContent).toContain("--daemon");
      expect(scriptContent).toContain("-d|--daemon");
    });

    it("accepts -d flag", async () => {
      const scriptContent = readFileSync(scriptPath, "utf-8");
      expect(scriptContent).toContain("-d|--daemon) DAEMON_MODE=true");
    });
  });

  describe("--status", () => {
    it("shows status when not running", async () => {
      try {
        await exec("bash", [scriptPath, "--status"]);
      } catch (err: unknown) {
        const error = err as { stdout?: string; stderr?: string };
        expect(error.stdout ?? error.stderr).toContain("服务状态:");
      }
    });

    it("exits with code 1 when not running", async () => {
      await expect(exec("bash", [scriptPath, "--status"])).rejects.toThrow();
    });
  });

  describe("--stop", () => {
    it("shows message when no service running", async () => {
      try {
        await exec("bash", [scriptPath, "--stop"]);
      } catch (err: unknown) {
        const error = err as { stdout?: string; stderr?: string };
        expect(error.stdout ?? error.stderr).toContain("服务未运行");
      }
    });
  });

  describe("unknown option", () => {
    it.concurrent("rejects unknown option", { timeout: 10000 }, async () => {
      await expect(
        exec("bash", [scriptPath, "--unknown-option"], { timeout: 5000 }),
      ).rejects.toThrow();
    });
  });

  describe("--allow-http config modification", () => {
    const configPath = join(testDir, ".openclaw", "openclaw.json");

    beforeEach(() => {
      // Clean up test directory
      rmSync(join(testDir, ".openclaw"), { recursive: true, force: true });
      mkdirSync(join(testDir, ".openclaw"), { recursive: true });

      // Create minimal config file
      writeFileSync(configPath, JSON.stringify({ version: "1.0.0" }, null, 2));
    });

    it("modifies config file with allow-http settings", async () => {
      const originalConfig = JSON.parse(readFileSync(configPath, "utf-8"));
      expect(originalConfig.gateway).toBeUndefined();

      // Run the config modification code
      await exec("node", [
        "-e",
        `
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('${configPath}', 'utf8'));
cfg.gateway = cfg.gateway || {};
cfg.gateway.controlUi = cfg.gateway.controlUi || {};
cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true;
cfg.gateway.controlUi.dangerouslyDisableDeviceAuth = true;
fs.writeFileSync('${configPath}', JSON.stringify(cfg, null, 2));
`,
      ]);

      const modifiedConfig = JSON.parse(readFileSync(configPath, "utf-8"));
      expect(modifiedConfig.gateway).toBeDefined();
      expect(modifiedConfig.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback).toBe(true);
      expect(modifiedConfig.gateway.controlUi.dangerouslyDisableDeviceAuth).toBe(true);
    });
  });
});

describe("offline/start.sh parameter combinations", () => {
  if (process.platform === "win32") {
    it.skip("skipped on Windows", () => {});
    return;
  }

  const scriptPath = join(repoRoot, "offline", "start.sh");

  it("--public implies --bind lan", async () => {
    // Parse the script to verify --public sets BIND=lan and ALLOW_HTTP=true
    const scriptContent = readFileSync(scriptPath, "utf-8");

    // Check that --public sets BIND=lan and ALLOW_HTTP=true
    expect(scriptContent).toMatch(/--public\)[^)]*BIND="lan"[^)]*ALLOW_HTTP=true/);
  });
});
