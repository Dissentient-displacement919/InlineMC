const installCommands = {
  linux: {
    label: "Linux / macOS",
    command: "curl -fsSL https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.sh | bash",
    scriptName: "launch.sh",
    scriptUrl: "https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.sh"
  },
  "windows-powershell": {
    label: "Windows PowerShell",
    command:
      "irm https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.ps1 | iex",
    scriptName: "launch.ps1",
    scriptUrl: "https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.ps1"
  },
  "windows-cmd": {
    label: "Windows CMD",
    command:
      'curl -L -o "%TEMP%\\inlinemc-launch.bat" https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.bat && "%TEMP%\\inlinemc-launch.bat"',
    scriptName: "launch.bat",
    scriptUrl: "https://raw.githubusercontent.com/sammwyy/inlinemc/main/launch.bat"
  }
};

function detectedOs() {
  return /windows/i.test(navigator.userAgent) ? "windows-powershell" : "linux";
}

async function copyText(value) {
  if (navigator.clipboard && window.isSecureContext) {
    await navigator.clipboard.writeText(value);
    return;
  }

  const textarea = document.createElement("textarea");
  textarea.value = value;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.append(textarea);
  textarea.select();
  document.execCommand("copy");
  textarea.remove();
}

function selectInstallTab(os) {
  const selected = installCommands[os] ? os : "linux";
  const command = installCommands[selected];
  const label = document.getElementById("command-label");
  const code = document.getElementById("install-command");
  const download = document.getElementById("script-download");

  label.textContent = command.label;
  code.textContent = command.command;
  download.textContent = command.scriptName;
  download.href = command.scriptUrl;
  download.setAttribute("download", command.scriptName);

  document.querySelectorAll("[data-os]").forEach((tab) => {
    const active = tab.dataset.os === selected;
    tab.classList.toggle("is-active", active);
    tab.setAttribute("aria-selected", String(active));
    tab.tabIndex = active ? 0 : -1;
  });
}

function setupInstallTabs() {
  const copyButton = document.getElementById("copy-command");
  const code = document.getElementById("install-command");

  document.querySelectorAll("[data-os]").forEach((tab) => {
    tab.addEventListener("click", () => selectInstallTab(tab.dataset.os));
  });

  copyButton.addEventListener("click", async () => {
    await copyText(code.textContent);
    copyButton.textContent = "Copied";
    window.setTimeout(() => {
      copyButton.textContent = "Copy";
    }, 1400);
  });

  selectInstallTab(detectedOs());
}

function sumCounts(bucket) {
  return Object.entries(bucket || {})
    .filter(([key]) => key !== "_timestamp")
    .reduce((total, [, value]) => total + Number(value || 0), 0);
}

function sortedEntries(bucket) {
  return Object.entries(bucket || {})
    .filter(([key]) => key !== "_timestamp")
    .map(([version, count]) => [version, Number(count || 0)])
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
}

function renderSummary(plan) {
  const target = document.getElementById("stats-summary");
  const total = sumCounts(plan.allTime);
  const last24h = sumCounts(plan.last24h);

  target.innerHTML = `
    <span class="summary-pill"><strong>${last24h}</strong> launches in the last 24 hours</span>
    <span class="summary-pill"><strong>${total}</strong> launches all time</span>
  `;
}

function renderCards(targetId, bucket) {
  const target = document.getElementById(targetId);
  const entries = sortedEntries(bucket);

  if (entries.length === 0) {
    target.innerHTML = '<div class="empty">No launches recorded yet.</div>';
    return;
  }

  target.replaceChildren(
    ...entries.map(([version, count]) => {
      const card = document.createElement("article");
      card.className = "stat";

      const label = document.createElement("span");
      label.textContent = version;

      const value = document.createElement("strong");
      value.textContent = String(count);

      card.append(label, value);
      return card;
    })
  );
}

function populateStats(rawStats) {
  const plan = rawStats?.plan || {};

  renderSummary(plan);
  renderCards("stats-last24h", plan.last24h || {});
  renderCards("stats-alltime", plan.allTime || {});
}

document.addEventListener("DOMContentLoaded", setupInstallTabs);
