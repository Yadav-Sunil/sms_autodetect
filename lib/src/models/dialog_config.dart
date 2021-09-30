part of sms_autodetect;

class DialogConfig {
  /// title of the [AlertDialog] while pasting the code. Default to [Paste Code]
  final String? dialogTitle;

  /// content of the [AlertDialog] while pasting the code. Default to ["Do you want to paste this code "]
  final String? dialogContent;

  /// Affirmative action text for the [AlertDialog]. Default to "Paste"
  final String? affirmativeText;

  /// Negative action text for the [AlertDialog]. Default to "Cancel"
  final String? negativeText;

  /// The default dialog theme, should it be iOS or other(including web and Android)
  final Platforms platform;

  DialogConfig._internal({
    this.dialogContent,
    this.dialogTitle,
    this.affirmativeText,
    this.negativeText,
    this.platform = Platforms.other,
  });

  factory DialogConfig(
      {String? affirmativeText,
      String? dialogContent,
      String? dialogTitle,
      String? negativeText,
      Platforms? platform}) {
    return DialogConfig._internal(
      affirmativeText: affirmativeText == null ? "Paste" : affirmativeText,
      dialogContent: dialogContent == null
          ? "Do you want to paste this code "
          : dialogContent,
      dialogTitle: dialogTitle == null ? "Paste Code" : dialogTitle,
      negativeText: negativeText == null ? "Cancel" : negativeText,
      platform: platform == null ? Platforms.other : platform,
    );
  }
}
