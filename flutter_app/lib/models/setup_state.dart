enum SetupStep {
  checkingStatus,
  downloadingRootfs,
  extractingRootfs,
  installingNode,
  installingOpenClaw,
  configuringBypass,
  complete,
  error,
}

class SetupState {
  final SetupStep step;
  final double progress;
  final String message;
  final String? error;

  const SetupState({
    this.step = SetupStep.checkingStatus,
    this.progress = 0.0,
    this.message = '',
    this.error,
  });

  SetupState copyWith({
    SetupStep? step,
    double? progress,
    String? message,
    String? error,
  }) {
    return SetupState(
      step: step ?? this.step,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      error: error,
    );
  }

  bool get isComplete => step == SetupStep.complete;
  bool get hasError => step == SetupStep.error;

  String get stepLabel {
    switch (step) {
      case SetupStep.checkingStatus:
        return 'Comprobando estado...';
      case SetupStep.downloadingRootfs:
        return 'Descargando Ubuntu (rootfs)';
      case SetupStep.extractingRootfs:
        return 'Extrayendo rootfs';
      case SetupStep.installingNode:
        return 'Instalando Node.js';
      case SetupStep.installingOpenClaw:
        return 'Instalando OpenClaw';
      case SetupStep.configuringBypass:
        return 'Configurando parche Bionic';
      case SetupStep.complete:
        return 'Configuración completada';
      case SetupStep.error:
        return 'Error';
    }
  }

  int get stepNumber {
    switch (step) {
      case SetupStep.checkingStatus:
        return 0;
      case SetupStep.downloadingRootfs:
        return 1;
      case SetupStep.extractingRootfs:
        return 2;
      case SetupStep.installingNode:
        return 3;
      case SetupStep.installingOpenClaw:
        return 4;
      case SetupStep.configuringBypass:
        return 5;
      case SetupStep.complete:
        return 6;
      case SetupStep.error:
        return -1;
    }
  }

  static const int totalSteps = 6;
}
