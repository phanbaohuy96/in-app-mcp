import path from 'node:path';
import type { Options } from '@wdio/types';

const apkPath = process.env.APP_APK_PATH ??
  path.resolve(__dirname, '../../build/app/outputs/flutter-apk/app-debug.apk');

export const config: Options.Testrunner = {
  runner: 'local',
  tsConfigPath: path.resolve(__dirname, 'tsconfig.json'),
  specs: [path.resolve(__dirname, 'specs/**/*.e2e.ts')],
  maxInstances: 1,
  logLevel: 'info',
  framework: 'mocha',
  reporters: ['spec'],
  mochaOpts: {
    timeout: 180000,
  },
  capabilities: [
    {
      platformName: 'Android',
      'appium:automationName': 'UiAutomator2',
      'appium:app': apkPath,
      'appium:deviceName': process.env.ANDROID_DEVICE_NAME ?? 'Android Emulator',
      'appium:autoGrantPermissions': true,
      'appium:newCommandTimeout': 180,
    },
  ],
  hostname: process.env.APPIUM_HOST ?? '127.0.0.1',
  port: Number(process.env.APPIUM_PORT ?? 4723),
  path: process.env.APPIUM_PATH ?? '/wd/hub',
};
