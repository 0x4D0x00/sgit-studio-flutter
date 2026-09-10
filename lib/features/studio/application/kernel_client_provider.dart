import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_factory.dart';

/// 内核通道 provider。让各仓储共用同一条连接（wasm 侧本来也只有一条）。
final kernelClientProvider = Provider((ref) => createKernelClient());
