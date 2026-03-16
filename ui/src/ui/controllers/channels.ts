import { ChannelsStatusSnapshot } from "../types.ts";
import type { ChannelsState, FeishuPairingRequest, FeishuSetupResult } from "./channels.types.ts";

export type { ChannelsState, FeishuPairingRequest, FeishuSetupResult };

export async function loadChannels(state: ChannelsState, probe: boolean) {
  if (!state.client || !state.connected) {
    return;
  }
  if (state.channelsLoading) {
    return;
  }
  state.channelsLoading = true;
  state.channelsError = null;
  try {
    const res = await state.client.request<ChannelsStatusSnapshot | null>("channels.status", {
      probe,
      timeoutMs: 8000,
    });
    state.channelsSnapshot = res;
    state.channelsLastSuccess = Date.now();
  } catch (err) {
    state.channelsError = String(err);
  } finally {
    state.channelsLoading = false;
  }
}

export async function startWhatsAppLogin(state: ChannelsState, force: boolean) {
  if (!state.client || !state.connected || state.whatsappBusy) {
    return;
  }
  state.whatsappBusy = true;
  try {
    const res = await state.client.request<{ message?: string; qrDataUrl?: string }>(
      "web.login.start",
      {
        force,
        timeoutMs: 30000,
      },
    );
    state.whatsappLoginMessage = res.message ?? null;
    state.whatsappLoginQrDataUrl = res.qrDataUrl ?? null;
    state.whatsappLoginConnected = null;
  } catch (err) {
    state.whatsappLoginMessage = String(err);
    state.whatsappLoginQrDataUrl = null;
    state.whatsappLoginConnected = null;
  } finally {
    state.whatsappBusy = false;
  }
}

export async function waitWhatsAppLogin(state: ChannelsState) {
  if (!state.client || !state.connected || state.whatsappBusy) {
    return;
  }
  state.whatsappBusy = true;
  try {
    const res = await state.client.request<{ message?: string; connected?: boolean }>(
      "web.login.wait",
      {
        timeoutMs: 120000,
      },
    );
    state.whatsappLoginMessage = res.message ?? null;
    state.whatsappLoginConnected = res.connected ?? null;
    if (res.connected) {
      state.whatsappLoginQrDataUrl = null;
    }
  } catch (err) {
    state.whatsappLoginMessage = String(err);
    state.whatsappLoginConnected = null;
  } finally {
    state.whatsappBusy = false;
  }
}

export async function startFeishuSetup(state: ChannelsState) {
  if (!state.client || !state.connected || state.feishuSetupBusy) {
    return;
  }
  state.feishuSetupBusy = true;
  state.feishuSetupResult = null;
  state.feishuSetupMessage = null;
  state.feishuSetupQrDataUrl = null;
  try {
    const res = await state.client.request<{
      qrDataUrl?: string;
      interval?: number;
      expireIn?: number;
      message?: string;
    }>("feishu.setup.start", {});
    state.feishuSetupQrDataUrl = res.qrDataUrl ?? null;
    state.feishuSetupMessage = res.message ?? null;
    state.feishuSetupInterval = typeof res.interval === "number" ? res.interval : 5;
  } catch (err) {
    state.feishuSetupMessage = String(err);
    state.feishuSetupQrDataUrl = null;
  } finally {
    state.feishuSetupBusy = false;
  }
}

export async function pollFeishuSetup(state: ChannelsState) {
  if (!state.client || !state.connected || state.feishuSetupBusy) {
    return;
  }
  state.feishuSetupBusy = true;
  try {
    const res = await state.client.request<{
      pending?: boolean;
      appId?: string;
      appSecret?: string;
      openId?: string;
    }>("feishu.setup.poll", {});
    if (!res.pending && res.appId && res.appSecret) {
      state.feishuSetupResult = {
        appId: res.appId,
        appSecret: res.appSecret,
        openId: res.openId,
      } as FeishuSetupResult;
      state.feishuSetupQrDataUrl = null;
      state.feishuSetupMessage = "机器人创建成功！凭证已自动填入。";
    }
    // If still pending, leave qrDataUrl/message as-is
  } catch (err) {
    state.feishuSetupMessage = `扫码失败：${String(err)}`;
    state.feishuSetupQrDataUrl = null;
  } finally {
    state.feishuSetupBusy = false;
  }
}

export async function listFeishuPairing(state: ChannelsState) {
  if (!state.client || !state.connected || state.feishuPairingBusy) {
    return;
  }
  state.feishuPairingBusy = true;
  state.feishuPairingError = null;
  try {
    const res = await state.client.request<{ requests?: FeishuPairingRequest[] }>(
      "feishu.pairing.list",
      {},
    );
    state.feishuPairingRequests = Array.isArray(res.requests) ? res.requests : [];
  } catch (err) {
    state.feishuPairingError = String(err);
  } finally {
    state.feishuPairingBusy = false;
  }
}

export async function approveFeishuPairing(state: ChannelsState, code: string) {
  if (!state.client || !state.connected || state.feishuPairingBusy) {
    return;
  }
  state.feishuPairingBusy = true;
  state.feishuPairingError = null;
  try {
    await state.client.request("feishu.pairing.approve", { code });
    // Refresh list after approval
    const res = await state.client.request<{ requests?: FeishuPairingRequest[] }>(
      "feishu.pairing.list",
      {},
    );
    state.feishuPairingRequests = Array.isArray(res.requests) ? res.requests : [];
  } catch (err) {
    state.feishuPairingError = String(err);
  } finally {
    state.feishuPairingBusy = false;
  }
}

export async function logoutWhatsApp(state: ChannelsState) {
  if (!state.client || !state.connected || state.whatsappBusy) {
    return;
  }
  state.whatsappBusy = true;
  try {
    await state.client.request("channels.logout", { channel: "whatsapp" });
    state.whatsappLoginMessage = "Logged out.";
    state.whatsappLoginQrDataUrl = null;
    state.whatsappLoginConnected = null;
  } catch (err) {
    state.whatsappLoginMessage = String(err);
  } finally {
    state.whatsappBusy = false;
  }
}
