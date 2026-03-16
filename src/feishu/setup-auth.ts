/**
 * Feishu bot registration flow via the OAuth Device Authorization API.
 *
 * Endpoint: POST https://accounts.feishu.cn/oauth/v1/app/registration
 * Content-Type: application/x-www-form-urlencoded
 *
 * Steps:
 *   begin  → returns verification_uri_complete + device_code + interval + expire_in
 *   poll   → returns client_id + client_secret when user completes scan
 */

const BASE_URL = "https://accounts.feishu.cn";
const ENDPOINT = "/oauth/v1/app/registration";

export type FeishuSetupBeginResult = {
  verification_uri_complete: string;
  device_code: string;
  interval: number; // polling interval in seconds
  expire_in: number; // session expiry in seconds
};

export type FeishuSetupPollResult =
  | { status: "pending" }
  | { status: "slow_down"; newInterval: number }
  | { status: "done"; appId: string; appSecret: string; openId?: string }
  | { status: "error"; code: string; description?: string };

async function postForm(action: string, extra: Record<string, string> = {}): Promise<unknown> {
  const body = new URLSearchParams({ action, ...extra });
  const res = await fetch(`${BASE_URL}${ENDPOINT}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) {
    throw new Error(`Feishu registration API error: ${res.status} ${res.statusText}`);
  }
  return res.json();
}

export async function feishuSetupBegin(): Promise<FeishuSetupBeginResult> {
  // Check supported auth methods first
  const initData = (await postForm("init")) as { supported_auth_methods?: string[] };
  if (!initData.supported_auth_methods?.includes("client_secret")) {
    throw new Error("Feishu registration: client_secret auth not supported in this environment");
  }

  const data = (await postForm("begin", {
    archetype: "PersonalAgent",
    auth_method: "client_secret",
    request_user_info: "open_id",
  })) as FeishuSetupBeginResult;

  if (!data.verification_uri_complete || !data.device_code) {
    throw new Error("Feishu registration: unexpected response from begin");
  }
  return data;
}

export async function feishuSetupPoll(
  deviceCode: string,
  currentInterval: number,
): Promise<FeishuSetupPollResult> {
  let raw: Record<string, unknown>;
  try {
    raw = (await postForm("poll", { device_code: deviceCode })) as Record<string, unknown>;
  } catch (err) {
    return { status: "error", code: "network_error", description: String(err) };
  }

  if (typeof raw.client_id === "string" && typeof raw.client_secret === "string") {
    const userInfo = raw.user_info as Record<string, unknown> | undefined;
    return {
      status: "done",
      appId: raw.client_id,
      appSecret: raw.client_secret,
      openId: typeof userInfo?.open_id === "string" ? userInfo.open_id : undefined,
    };
  }

  if (raw.error) {
    const code = typeof raw.error === "string" ? raw.error : JSON.stringify(raw.error);
    if (code === "authorization_pending") {
      return { status: "pending" };
    }
    if (code === "slow_down") {
      return { status: "slow_down", newInterval: currentInterval + 5 };
    }
    return { status: "error", code, description: raw.error_description as string | undefined };
  }

  return { status: "pending" };
}
