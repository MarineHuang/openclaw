import { html, nothing } from "lit";
import { resolveChannelConfigValue } from "./channel-config-extras.ts";
import type { ChannelsProps } from "./channels.types.ts";

export function renderFeishuCard(params: { props: ChannelsProps }) {
  const { props } = params;
  const status = props.snapshot?.channels?.feishu as Record<string, unknown> | undefined;
  const configured = typeof status?.configured === "boolean" ? status.configured : undefined;
  const running = typeof status?.running === "boolean" ? status.running : undefined;
  const connected = typeof status?.connected === "boolean" ? status.connected : undefined;
  const lastError = typeof status?.lastError === "string" ? status.lastError : undefined;

  const channelConfig = resolveChannelConfigValue(props.configForm, "feishu");
  // Use setup result (freshly created bot) if available, otherwise fall back to saved config
  const appIdValue =
    props.feishuSetupResult?.appId ??
    (typeof channelConfig?.appId === "string" ? channelConfig.appId : "");
  const appSecretValue =
    props.feishuSetupResult?.appSecret ??
    (typeof channelConfig?.appSecret === "string" ? channelConfig.appSecret : "");
  const disabled = props.configSaving || props.configSchemaLoading;

  const pairingRequests = props.feishuPairingRequests ?? [];
  const pairingBusy = props.feishuPairingBusy;
  const pairingError = props.feishuPairingError;

  const setupBusy = props.feishuSetupBusy;
  const setupQr = props.feishuSetupQrDataUrl;
  const setupMsg = props.feishuSetupMessage;
  const setupDone = !!props.feishuSetupResult;

  function patchAppId(value: string) {
    props.onConfigPatch(["channels", "feishu", "appId"], value);
    props.onConfigPatch(["channels", "feishu", "enabled"], true);
  }

  function patchAppSecret(value: string) {
    props.onConfigPatch(["channels", "feishu", "appSecret"], value);
    props.onConfigPatch(["channels", "feishu", "enabled"], true);
  }

  // When setup result arrives, also patch the config form automatically
  if (props.feishuSetupResult) {
    const { appId, appSecret } = props.feishuSetupResult;
    if (appId && typeof channelConfig?.appId !== "string") {
      patchAppId(appId);
    }
    if (appSecret && typeof channelConfig?.appSecret !== "string") {
      patchAppSecret(appSecret);
    }
  }

  return html`
    <div class="card">
      <div class="card-title">飞书 / Lark</div>
      <div class="card-sub">飞书官方插件频道配置。</div>

      <!-- Method 1: QR code scan -->
      <div class="callout" style="margin-top: 12px; font-size: 13px; line-height: 1.8;">
        <div><strong>配置方式一：扫码创建机器人（需要联网）</strong></div>
        ${
          setupQr
            ? html`
              <div style="margin: 10px 0; text-align: center;">
                <img
                  src="${setupQr}"
                  alt="飞书扫码二维码"
                  style="width: 180px; height: 180px; border: 1px solid var(--color-border, #ddd); border-radius: 6px;"
                />
                <div style="margin-top: 6px; color: var(--color-muted, #888);">
                  用飞书 App 扫码，等待机器人创建完成…
                </div>
                <button
                  class="btn"
                  style="margin-top: 8px;"
                  ?disabled=${setupBusy}
                  @click=${() => props.onFeishuSetupPoll()}
                >
                  ${setupBusy ? "查询中…" : "刷新状态"}
                </button>
              </div>
            `
            : html`
              <div style="margin-top: 6px; color: var(--color-muted, #888);">
                点击按钮向飞书服务器请求授权，在页面中显示二维码，用飞书 App 扫码即可自动创建机器人并获取凭证。
              </div>
              <button
                class="btn primary"
                style="margin-top: 8px;"
                ?disabled=${setupBusy || !props.connected}
                @click=${() => props.onFeishuSetupStart()}
              >
                ${setupBusy ? "生成中…" : "获取二维码"}
              </button>
            `
        }
        ${
          setupMsg
            ? html`<div class="callout ${setupDone ? "" : "danger"}" style="margin-top: 8px; font-size: 12px;">
                ${setupMsg}
              </div>`
            : nothing
        }
      </div>

      <!-- Method 2: Manual credentials -->
      <div style="margin-top: 12px; font-size: 13px; line-height: 1.6; color: var(--color-muted, #888);">
        <strong style="color: inherit;">配置方式二：手动填写凭证（可离线）</strong>
        — 前往
        <a href="https://open.feishu.cn/app" target="_blank" rel="noopener">飞书开放平台</a>
        创建自建应用，获取 App ID 和 App Secret 后填入下方。
      </div>

      <!-- Status -->
      <div class="status-list" style="margin-top: 12px;">
        <div>
          <span class="label">已配置</span>
          <span>${configured == null ? "n/a" : configured ? "是" : "否"}</span>
        </div>
        <div>
          <span class="label">运行中</span>
          <span>${running == null ? "n/a" : running ? "是" : "否"}</span>
        </div>
        <div>
          <span class="label">已连接</span>
          <span>${connected == null ? "n/a" : connected ? "是" : "否"}</span>
        </div>
      </div>

      ${
        lastError
          ? html`<div class="callout danger" style="margin-top: 12px;">${lastError}</div>`
          : nothing
      }

      <!-- Pairing requests -->
      <div style="margin-top: 16px;">
        <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 8px;">
          <strong style="font-size: 13px;">待配对用户</strong>
          <button
            class="btn"
            style="font-size: 12px; padding: 2px 8px;"
            ?disabled=${pairingBusy || !props.connected}
            @click=${() => props.onFeishuPairingList()}
          >
            ${pairingBusy ? "刷新中…" : "刷新"}
          </button>
        </div>
        ${
          pairingError
            ? html`<div class="callout danger" style="font-size: 12px; margin-bottom: 8px;">${pairingError}</div>`
            : nothing
        }
        ${
          pairingRequests.length === 0
            ? html`
                <div style="font-size: 12px; color: var(--color-muted, #888)">
                  暂无待配对请求。点击刷新查看最新状态。
                </div>
              `
            : html`
              <div style="font-size: 12px;">
                ${pairingRequests.map(
                  (req) => html`
                    <div style="display: flex; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px solid var(--color-border, #eee);">
                      <span style="font-family: monospace; font-weight: bold; letter-spacing: 1px;">${req.code}</span>
                      <span style="flex: 1; color: var(--color-muted, #888); overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${req.id}">${req.id}</span>
                      <button
                        class="btn primary"
                        style="font-size: 11px; padding: 2px 8px; white-space: nowrap;"
                        ?disabled=${pairingBusy}
                        @click=${() => props.onFeishuPairingApprove(req.code)}
                      >
                        批准
                      </button>
                    </div>
                  `,
                )}
              </div>
            `
        }
      </div>

      <!-- Credentials form -->
      <div style="margin-top: 16px;">
        <div class="cfg-field">
          <label class="cfg-field__label">App ID</label>
          <div class="cfg-input-wrap">
            <input
              type="text"
              class="cfg-input"
              placeholder="cli_xxxxxxxxxxxxxxxx"
              .value=${appIdValue}
              ?disabled=${disabled}
              @input=${(e: Event) => patchAppId((e.target as HTMLInputElement).value)}
            />
          </div>
        </div>

        <div class="cfg-field" style="margin-top: 8px;">
          <label class="cfg-field__label">App Secret</label>
          <div class="cfg-input-wrap">
            <input
              type="password"
              class="cfg-input"
              placeholder="••••"
              .value=${appSecretValue}
              ?disabled=${disabled}
              @input=${(e: Event) => patchAppSecret((e.target as HTMLInputElement).value)}
            />
          </div>
        </div>

        <div class="row" style="margin-top: 12px;">
          <button
            class="btn primary"
            ?disabled=${disabled || !props.configFormDirty}
            @click=${() => props.onConfigSave()}
          >
            ${props.configSaving ? "Saving…" : "Save"}
          </button>
          <button
            class="btn"
            ?disabled=${disabled}
            @click=${() => props.onConfigReload()}
          >
            Reload
          </button>
        </div>
      </div>
    </div>
  `;
}
