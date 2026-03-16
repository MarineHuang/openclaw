import { html, nothing } from "lit";
import { resolveChannelConfigValue } from "./channel-config-extras.ts";
import type { ChannelsProps } from "./channels.types.ts";

export function renderQQBotCard(params: { props: ChannelsProps }) {
  const { props } = params;
  const status = props.snapshot?.channels?.qqbot as Record<string, unknown> | undefined;
  const configured = typeof status?.configured === "boolean" ? status.configured : undefined;
  const running = typeof status?.running === "boolean" ? status.running : undefined;
  const connected = typeof status?.connected === "boolean" ? status.connected : undefined;
  const lastError = typeof status?.lastError === "string" ? status.lastError : undefined;

  const channelConfig = resolveChannelConfigValue(props.configForm, "qqbot");
  // Plugin reads channels.qqbot.appId and channels.qqbot.clientSecret (not "token").
  // openclaw channels add --channel qqbot --token "appId:clientSecret" splits on ":"
  // and writes them as separate fields via applyQQBotAccountConfig.
  const appIdValue = typeof channelConfig?.appId === "string" ? channelConfig.appId : "";
  const clientSecretValue =
    typeof channelConfig?.clientSecret === "string" ? channelConfig.clientSecret : "";
  const disabled = props.configSaving || props.configSchemaLoading;

  function patchAppId(value: string) {
    props.onConfigPatch(["channels", "qqbot", "appId"], value);
    // Mirror what applyQQBotAccountConfig does: always mark channel enabled
    props.onConfigPatch(["channels", "qqbot", "enabled"], true);
  }

  function patchClientSecret(value: string) {
    props.onConfigPatch(["channels", "qqbot", "clientSecret"], value);
    props.onConfigPatch(["channels", "qqbot", "enabled"], true);
  }

  return html`
    <div class="card">
      <div class="card-title">QQ</div>
      <div class="card-sub">QQ Bot 频道配置。</div>

      <div class="callout" style="margin-top: 12px; font-size: 13px; line-height: 1.6;">
        <div><strong>如何创建 QQ 机器人：</strong></div>
        <div>1. 访问 <a href="https://q.qq.com/qqbot/openclaw/login.html" target="_blank" rel="noopener">QQ 开放平台</a>，扫码登录</div>
        <div>2. 点击「创建机器人」，获取 <strong>AppID</strong> 和 <strong>AppSecret</strong></div>
        <div>3. 在下方填入凭证，保存后重启网关</div>
        <div style="margin-top: 6px; color: var(--color-muted, #888);">手动安装命令：<code>openclaw plugins install @tencent-connect/openclaw-qqbot@latest</code></div>
      </div>

      <div class="status-list" style="margin-top: 16px;">
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

      <div style="margin-top: 16px;">
        <div class="cfg-field">
          <label class="cfg-field__label">AppID</label>
          <div class="cfg-input-wrap">
            <input
              type="text"
              class="cfg-input"
              placeholder="你的 AppID"
              .value=${appIdValue}
              ?disabled=${disabled}
              @input=${(e: Event) => patchAppId((e.target as HTMLInputElement).value)}
            />
          </div>
        </div>

        <div class="cfg-field" style="margin-top: 8px;">
          <label class="cfg-field__label">AppSecret</label>
          <div class="cfg-input-wrap">
            <input
              type="password"
              class="cfg-input"
              placeholder="••••"
              .value=${clientSecretValue}
              ?disabled=${disabled}
              @input=${(e: Event) => patchClientSecret((e.target as HTMLInputElement).value)}
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
