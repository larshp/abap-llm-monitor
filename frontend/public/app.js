const providerGrid = document.getElementById("provider-grid");
const refreshStatus = document.getElementById("refresh-status");
const refreshIntervalMs = 5000;
const minimumLoadingMs = 200;

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function showRefreshStatus() {
  refreshStatus.hidden = false;
  return delay(minimumLoadingMs);
}

function levelForPercent(percent) {
  if (percent < 50) {
    return "low";
  }

  if (percent < 70) {
    return "medium";
  }

  return "high";
}

function formatNumber(value) {
  return new Intl.NumberFormat("en-US").format(value);
}

function formatCurrency(value) {
  if (!Number.isFinite(value)) {
    return "Unavailable";
  }

  return new Intl.NumberFormat("en-US", {
    currency: "USD",
    style: "currency"
  }).format(value);
}

function titleCase(value) {
  return `${value.charAt(0).toUpperCase()}${value.slice(1)}`;
}

function resetText(metric) {
  return metric.reset ? `Resets ${metric.reset}` : "";
}

function metricLabel(metric) {
  if (metric.kind === "usage") {
    return `${titleCase(metric.window)} usage limit`;
  }

  if (metric.kind === "credits") {
    return `${titleCase(metric.period)} credits`;
  }

  return "Account balance";
}

function metricValue(metric) {
  if (metric.kind === "usage") {
    return `${metric.remainingPercent}%`;
  }

  if (metric.kind === "credits") {
    return `${formatNumber(metric.used)} / ${formatNumber(metric.total)}`;
  }

  if (metric.error) {
    return "Unavailable";
  }

  return formatCurrency(metric.amount);
}

function metricDetail(metric) {
  if (metric.kind === "balance" && metric.error) {
    return metric.error;
  }

  return metric.kind === "credits" ? "used / total" : "remaining";
}

function metricMeter(metric) {
  if (metric.kind === "usage") {
    return {
      level: levelForPercent(metric.remainingPercent),
      percent: metric.remainingPercent
    };
  }

  if (metric.kind === "credits") {
    const remainingPercent = Math.round(((metric.total - metric.used) / metric.total) * 100);

    return {
      level: levelForPercent(remainingPercent),
      percent: remainingPercent
    };
  }

  return null;
}

function metricAriaLabel(provider, metric) {
  if (metric.kind === "usage") {
    return `${provider.name} ${metric.window} usage limit ${metric.remainingPercent} percent remaining`;
  }

  if (metric.kind === "credits") {
    return `${provider.name} ${metric.period} credits ${metric.used} used of ${metric.total} total, ${resetText(metric).toLowerCase()}`;
  }

  if (metric.error || !Number.isFinite(metric.amount)) {
    return `${provider.name} account balance unavailable`;
  }

  const dollars = Math.floor(metric.amount);
  const cents = Math.round((metric.amount - dollars) * 100);
  return `${provider.name} account balance ${dollars} dollars ${cents} cents remaining`;
}

function createElement(tagName, options = {}) {
  const element = document.createElement(tagName);

  if (options.className) {
    element.className = options.className;
  }

  if (options.textContent) {
    element.textContent = options.textContent;
  }

  return element;
}

function renderMeter(meterData) {
  if (!meterData) {
    return null;
  }

  const meter = createElement("div", { className: "usage-meter" });
  const fill = createElement("span", { className: `meter-${meterData.level}` });
  fill.style.width = `${meterData.percent}%`;
  meter.append(fill);
  return meter;
}

function metricKey(metric, index) {
  if (metric.kind === "usage") {
    return `${metric.kind}-${metric.window}`;
  }

  return `${metric.kind}-${index}`;
}

function updateMeter(meter, meterData) {
  if (!meter || !meterData) {
    return;
  }

  const fill = meter.querySelector("span");
  fill.className = `meter-${meterData.level}`;
  fill.style.width = `${meterData.percent}%`;
}

function updateMetric(block, provider, metric) {
  block.setAttribute("aria-label", metricAriaLabel(provider, metric));
  block.querySelector(".metric-label").textContent = metricLabel(metric);
  block.querySelector("strong").textContent = metricValue(metric);
  block.querySelector(".limit-detail").textContent = metricDetail(metric);

  const reset = block.querySelector(".reset-time");

  if (reset) {
    reset.textContent = resetText(metric);
  }

  updateMeter(block.querySelector(".usage-meter"), metricMeter(metric));
}

function renderMetric(provider, metric) {
  const block = createElement("section", { className: "limit-block" });
  block.setAttribute("aria-label", metricAriaLabel(provider, metric));
  block.append(
    createElement("span", { className: "metric-label", textContent: metricLabel(metric) }),
    createElement("strong", { textContent: metricValue(metric) }),
    createElement("span", { className: "limit-detail", textContent: metricDetail(metric) })
  );

  if (metric.reset) {
    block.append(createElement("span", { className: "reset-time", textContent: resetText(metric) }));
  }

  const meter = renderMeter(metricMeter(metric));

  if (meter) {
    block.append(meter);
  }

  return block;
}

function renderMetricWithKey(provider, metric, index) {
  const block = renderMetric(provider, metric);
  block.dataset.metricKey = metricKey(metric, index);
  return block;
}

function updateProvider(card, provider) {
  card.querySelector(".provider-logo").alt = `${provider.name} logo`;
  card.querySelector(".provider-logo").src = provider.logo;
  card.querySelector("h2").textContent = provider.name;

  const limitStack = card.querySelector(".limit-stack");
  const existingMetrics = new Map(
    [...limitStack.querySelectorAll(".limit-block")].map((block) => [block.dataset.metricKey, block])
  );

  provider.metrics.forEach((metric, index) => {
    const key = metricKey(metric, index);
    const block = existingMetrics.get(key);

    if (block) {
      updateMetric(block, provider, metric);
      return;
    }

    limitStack.append(renderMetricWithKey(provider, metric, index));
  });
}

function renderProvider(provider) {
  const card = createElement("article", { className: `provider-card ${provider.id}` });
  card.dataset.providerId = provider.id;
  const header = createElement("header", { className: "provider-header" });
  const titleWrapper = createElement("div", { className: "provider-title" });
  const logo = createElement("img", { className: "provider-logo" });
  logo.alt = `${provider.name} logo`;
  logo.src = provider.logo;
  titleWrapper.append(createElement("h2", { textContent: provider.name }));
  titleWrapper.prepend(logo);
  header.append(titleWrapper);

  const limitStack = createElement("div", { className: "limit-stack" });
  limitStack.append(...provider.metrics.map((metric, index) => renderMetricWithKey(provider, metric, index)));

  card.append(header, limitStack);
  return card;
}

function renderMetrics(metricsData) {
  if (!providerGrid.children.length) {
    providerGrid.textContent = "";
  }

  const existingProviders = new Map(
    [...providerGrid.querySelectorAll(".provider-card")].map((card) => [card.dataset.providerId, card])
  );

  metricsData.forEach((provider) => {
    const card = existingProviders.get(provider.id);

    if (card) {
      updateProvider(card, provider);
      return;
    }

    providerGrid.append(renderProvider(provider));
  });
}

async function loadMetrics() {
  const response = await fetch("/metrics.json");

  if (!response.ok) {
    throw new Error(`Unable to load metrics.json: ${response.status}`);
  }

  return response.json();
}

async function refreshMetrics() {
  const minimumLoadingDelay = showRefreshStatus();

  try {
    const metricsData = await loadMetrics();
    renderMetrics(metricsData);
  } catch (error) {
    if (!providerGrid.children.length) {
      providerGrid.textContent = "Unable to load metrics.";
    }

    console.error(error);
  } finally {
    await minimumLoadingDelay;
    refreshStatus.hidden = true;
  }
}

refreshMetrics();
setInterval(refreshMetrics, refreshIntervalMs);
