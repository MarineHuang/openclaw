import type { GatewayBrowserClient } from "../gateway.ts";
import type { ChannelsStatusSnapshot } from "../types.ts";

export type FeishuSetupResult = {
  appId: string;
  appSecret: string;
  openId?: string;
};

export type FeishuPairingRequest = {
  id: string;
  code: string;
  createdAt: string;
  lastSeenAt: string;
  meta?: Record<string, string>;
};

export type ChannelsState = {
  client: GatewayBrowserClient | null;
  connected: boolean;
  channelsLoading: boolean;
  channelsSnapshot: ChannelsStatusSnapshot | null;
  channelsError: string | null;
  channelsLastSuccess: number | null;
  whatsappLoginMessage: string | null;
  whatsappLoginQrDataUrl: string | null;
  whatsappLoginConnected: boolean | null;
  whatsappBusy: boolean;
  feishuSetupBusy: boolean;
  feishuSetupQrDataUrl: string | null;
  feishuSetupMessage: string | null;
  feishuSetupInterval: number; // polling interval in seconds
  feishuSetupResult: FeishuSetupResult | null;
  feishuPairingRequests: FeishuPairingRequest[];
  feishuPairingBusy: boolean;
  feishuPairingError: string | null;
};
