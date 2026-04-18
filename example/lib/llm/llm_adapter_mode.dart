enum LlmAdapterMode { mock, gemma4 }

class LlmAdapterModeConfig {
  static LlmAdapterMode fromEnvironment() {
    const raw = String.fromEnvironment('LLM_ADAPTER', defaultValue: 'mock');
    return switch (raw.toLowerCase()) {
      'gemma' ||
      'gemma4' ||
      'gemma_4' ||
      'gemma-4' ||
      'gemma4b' ||
      'gemma_4b' ||
      'gemma-e4b' => LlmAdapterMode.gemma4,
      _ => LlmAdapterMode.mock,
    };
  }
}
