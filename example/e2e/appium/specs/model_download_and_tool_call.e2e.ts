import { $, expect } from '@wdio/globals';

describe('model download and tool call flow', () => {
  it('downloads, selects model, and runs tool call', async () => {
    const openSettings = await $('~open-settings-button');
    await openSettings.click();

    const modelRow = await $('~model-row-gemma4_e4b_it');
    await expect(modelRow).toExist();

    const status = await $('~model-status-gemma4_e4b_it');
    const statusText = (await status.getText()).toLowerCase();

    if (statusText.includes('not downloaded') || statusText.includes('failed')) {
      const download = await $('~model-download-gemma4_e4b_it');
      await download.click();
    }

    await browser.waitUntil(async () => {
      const value = (await (await $('~model-status-gemma4_e4b_it')).getText()).toLowerCase();
      return value.includes('downloaded');
    }, { timeout: 180000, interval: 1500, timeoutMsg: 'model did not download in time' });

    const select = await $('~model-select-gemma4_e4b_it');
    await select.click();

    const backButton = await $('~Navigate up');
    await backButton.click();

    const activeModelLabel = await $('~active-model-label');
    await expect(activeModelLabel).toHaveText(expect.not.stringContaining('none'));

    const runButton = await $('~run-tool-call-button');
    await runButton.click();

    const result = await $('~tool-call-result');
    await browser.waitUntil(async () => {
      const text = await result.getText();
      return text.includes('"success": true');
    }, { timeout: 120000, interval: 1000, timeoutMsg: 'tool call result not successful' });
  });
});
