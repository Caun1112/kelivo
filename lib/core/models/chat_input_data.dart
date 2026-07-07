class DocumentAttachment {
  final String path; // absolute file path
  final String fileName;
  final String mime; // e.g. application/pdf, text/plain

  const DocumentAttachment({
    required this.path,
    required this.fileName,
    required this.mime,
  });
}

class ChatTargetModel {
  final String providerKey;
  final String modelId;

  const ChatTargetModel({required this.providerKey, required this.modelId});

  String get key => '$providerKey::$modelId';

  @override
  bool operator ==(Object other) {
    return other is ChatTargetModel &&
        other.providerKey == providerKey &&
        other.modelId == modelId;
  }

  @override
  int get hashCode => Object.hash(providerKey, modelId);
}

class ChatInputData {
  final String text;
  final List<String> imagePaths; // absolute file paths or data URLs
  final List<DocumentAttachment> documents; // selected files
  final bool allowImagesApiRouting;
  final List<ChatTargetModel> targetModels;

  const ChatInputData({
    required this.text,
    this.imagePaths = const [],
    this.documents = const [],
    this.allowImagesApiRouting = true,
    this.targetModels = const [],
  });
}

enum ChatInputSubmissionResult { sent, queued, rejected }

class QueuedChatInput {
  final String conversationId;
  final ChatInputData input;

  const QueuedChatInput({required this.conversationId, required this.input});
}
