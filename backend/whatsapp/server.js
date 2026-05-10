import cors from 'cors';
import dotenv from 'dotenv';
import express from 'express';

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json({ limit: '1mb' }));

const port = Number(process.env.PORT || 8787);

function isConfigured(value) {
  return value && value.trim().length > 0 && value !== 'replace_me';
}

function cleanPhoneNumber(value) {
  return String(value || '').replace(/[^\d]/g, '');
}

function buildTemplateComponents(bodyParameters) {
  if (!Array.isArray(bodyParameters) || bodyParameters.length === 0) {
    return [];
  }

  return [
    {
      type: 'body',
      parameters: bodyParameters.map((value) => ({
        type: 'text',
        text: String(value),
      })),
    },
  ];
}

app.get('/health', (req, res) => {
  res.json({
    ok: true,
    message: 'Text Helper WhatsApp backend is running on 192.168.1.229:8787.',
    mode: isConfigured(process.env.WHATSAPP_PHONE_NUMBER_ID) &&
      isConfigured(process.env.WHATSAPP_ACCESS_TOKEN)
      ? 'real'
      : 'dry-run',
    time: new Date().toISOString(),
  });
});

app.post('/whatsapp/send-template', async (req, res) => {
  const graphApiVersion = process.env.WHATSAPP_GRAPH_API_VERSION || 'v21.0';
  const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
  const accessToken = process.env.WHATSAPP_ACCESS_TOKEN;

  const to = cleanPhoneNumber(req.body.to);
  const templateName = String(req.body.templateName || '').trim();
  const languageCode = String(req.body.languageCode || 'en_US').trim();
  const bodyParameters = Array.isArray(req.body.bodyParameters)
    ? req.body.bodyParameters
    : [];

  if (!to) {
    return res.status(400).json({
      ok: false,
      error: 'Recipient phone number is required.',
    });
  }

  if (!templateName) {
    return res.status(400).json({
      ok: false,
      error: 'Template name is required.',
    });
  }

  const configured =
    isConfigured(phoneNumberId) &&
    isConfigured(accessToken);

  if (!configured) {
    return res.json({
      ok: true,
      dryRun: true,
      message: `DRY RUN: would send template ${templateName} to ${to}. Add real WhatsApp Business credentials in backend/whatsapp/.env to send for real.`,
      providerMessageId: `dry-run-${Date.now()}`,
      request: {
        to,
        templateName,
        languageCode,
        bodyParameters,
      },
    });
  }

  const payload = {
    messaging_product: 'whatsapp',
    to,
    type: 'template',
    template: {
      name: templateName,
      language: {
        code: languageCode,
      },
    },
  };

  const components = buildTemplateComponents(bodyParameters);

  if (components.length > 0) {
    payload.template.components = components;
  }

  const url = `https://graph.facebook.com/${graphApiVersion}/${phoneNumberId}/messages`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const text = await response.text();

    let decoded;

    try {
      decoded = JSON.parse(text);
    } catch {
      decoded = { raw: text };
    }

    if (!response.ok) {
      return res.status(response.status).json({
        ok: false,
        error: 'WhatsApp Business API rejected the request.',
        status: response.status,
        detail: decoded,
      });
    }

    const providerMessageId =
      decoded?.messages?.[0]?.id ||
      decoded?.message_id ||
      null;

    return res.json({
      ok: true,
      message: 'WhatsApp Business template sent.',
      providerMessageId,
      detail: decoded,
    });
  } catch (error) {
    return res.status(500).json({
      ok: false,
      error: error.message || String(error),
    });
  }
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Text Helper WhatsApp backend listening on http://0.0.0.0:${port}`);
});