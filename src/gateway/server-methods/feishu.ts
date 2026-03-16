import { notifyPairingApproved } from "../../channels/plugins/pairing.js";
import { loadConfig } from "../../config/config.js";
import { feishuSetupBegin, feishuSetupPoll } from "../../feishu/setup-auth.js";
import {
  approveChannelPairingCode,
  listChannelPairingRequests,
} from "../../pairing/pairing-store.js";
import { renderQrPngBase64 } from "../../web/qr-image.js";
import { ErrorCodes, errorShape } from "../protocol/index.js";
import type { GatewayRequestHandlers } from "./types.js";

// In-memory state for the active bot registration session (one at a time)
type SetupSession = {
  deviceCode: string;
  interval: number; // seconds
};
let activeSetupSession: SetupSession | null = null;

export const feishuHandlers: GatewayRequestHandlers = {
  // Initiate bot registration — returns QR code data URL for scanning
  "feishu.setup.start": async ({ respond }) => {
    try {
      const begin = await feishuSetupBegin();
      activeSetupSession = { deviceCode: begin.device_code, interval: begin.interval };
      const base64 = await renderQrPngBase64(begin.verification_uri_complete);
      respond(
        true,
        {
          qrDataUrl: `data:image/png;base64,${base64}`,
          interval: begin.interval,
          expireIn: begin.expire_in,
          message: "用飞书 App 扫描二维码，创建机器人",
        },
        undefined,
      );
    } catch (err) {
      respond(false, undefined, errorShape(ErrorCodes.UNAVAILABLE, String(err)));
    }
  },

  // Poll registration status — returns appId/appSecret on success
  "feishu.setup.poll": async ({ respond }) => {
    const session = activeSetupSession;
    if (!session) {
      respond(
        false,
        undefined,
        errorShape(
          ErrorCodes.INVALID_REQUEST,
          "No active setup session. Call feishu.setup.start first.",
        ),
      );
      return;
    }
    try {
      const result = await feishuSetupPoll(session.deviceCode, session.interval);
      if (result.status === "pending") {
        respond(true, { pending: true }, undefined);
      } else if (result.status === "slow_down") {
        activeSetupSession = { ...session, interval: result.newInterval };
        respond(true, { pending: true }, undefined);
      } else if (result.status === "done") {
        activeSetupSession = null;
        respond(
          true,
          {
            pending: false,
            appId: result.appId,
            appSecret: result.appSecret,
            openId: result.openId,
          },
          undefined,
        );
      } else {
        activeSetupSession = null;
        respond(
          false,
          undefined,
          errorShape(ErrorCodes.UNAVAILABLE, `${result.code}: ${result.description ?? ""}`),
        );
      }
    } catch (err) {
      respond(false, undefined, errorShape(ErrorCodes.UNAVAILABLE, String(err)));
    }
  },

  // List pending pairing requests for the feishu channel
  "feishu.pairing.list": async ({ respond }) => {
    try {
      const requests = await listChannelPairingRequests("feishu");
      respond(true, { requests }, undefined);
    } catch (err) {
      respond(false, undefined, errorShape(ErrorCodes.UNAVAILABLE, String(err)));
    }
  },

  // Approve a feishu pairing code and notify the requester
  "feishu.pairing.approve": async ({ params, respond }) => {
    const code = typeof params.code === "string" ? params.code.trim() : "";
    if (!code) {
      respond(false, undefined, errorShape(ErrorCodes.INVALID_REQUEST, "code is required"));
      return;
    }
    try {
      const approved = await approveChannelPairingCode({ channel: "feishu", code });
      if (!approved) {
        respond(
          false,
          undefined,
          errorShape(ErrorCodes.INVALID_REQUEST, `No pending pairing request for code: ${code}`),
        );
        return;
      }
      // Send approval notification on feishu (best-effort)
      try {
        const cfg = loadConfig();
        await notifyPairingApproved({ channelId: "feishu", id: approved.id, cfg });
      } catch {
        // Notification failure does not fail the approval
      }
      respond(true, { id: approved.id }, undefined);
    } catch (err) {
      respond(false, undefined, errorShape(ErrorCodes.UNAVAILABLE, String(err)));
    }
  },
};
