import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/services/chat/chat_ports.dart';

/// 点开一条历史会话的异步流程：**本地秒回，服务器在后台补**。
///
/// 从 `ChatController.openThreadById` 拆出来。它只管「取数 + 判过期 + 回调」，
/// 不碰会话状态 —— 装配内容（[onLoaded]）和报错（[onFailed]）由控制器接，
/// 所以流程本身可以脱离 provider 单测。
///
/// ## 代次（generation）
///
/// 点开历史是异步的，用户完全可能在它回来之前点了另一条、或开了新对话。
/// 每个 await 之后都要问 [isStale]：过期了就**静默丢弃**（不装配、不报错）——
/// 往已换掉的会话里灌内容比不显示糟得多，弹一条"打不开 A"也只会让人莫名其妙。
///
/// ```text
/// 本地有 → 立刻展示，后台问服务器有没有更新（不让用户等）
/// 本地无 → 没东西可展示，只能等拉完（这一次必须等）
/// ```
class ThreadOpenFlow {
  ThreadOpenFlow({
    required ChatPorts ports,
    required bool Function(int gen) isStale,
    required void Function(String threadId, ThreadReplay replay) onLoaded,
    required void Function(Object error) onFailed,
  }) : _ports = ports,
       _isStale = isStale,
       _onLoaded = onLoaded,
       _onFailed = onFailed;

  final ChatPorts _ports;
  final bool Function(int gen) _isStale;
  final void Function(String threadId, ThreadReplay replay) _onLoaded;
  final void Function(Object error) _onFailed;

  /// 跑完整条流程。[gen] 是发起时记下的代次。
  Future<void> run(String threadId, int gen) async {
    try {
      final replay = await _ports.threadRepository.open(threadId);
      // 取数期间用户换了会话 → 这份内容已经过时，丢掉。
      if (_isStale(gen)) {
        debugPrint('[threads] $threadId 载入期间用户已换会话，丢弃这份内容');
        return;
      }
      _onLoaded(threadId, replay);
      // 不 await：本地那份已经在屏幕上，问服务器不该让用户等。
      _refreshInBackground(threadId, gen);
    } catch (e) {
      // ⚠️ **本地没有这条会话 —— 这是唯一该让用户等的情形。**
      //
      // 常见于"换台机器登录"：会话是在另一台设备上聊的，本机
      // `<cid_home>/sessions/` 里压根没有这个文件。此时直接报错是错的，
      // 那条会话明明在服务器上好好地躺着 —— 用户会以为历史丢了。
      debugPrint('[threads] 本地打不开 $threadId（$e），试着从服务器拉一次');
      if (_isStale(gen)) return;

      if (await _pullFromServer(threadId)) {
        if (_isStale(gen)) return;
        try {
          final replay = await _ports.threadRepository.open(threadId);
          if (_isStale(gen)) return;
          _onLoaded(threadId, replay);
          return; // 刚拉的就是最新，不必再刷一次
        } catch (e2) {
          // 拉回来了还是打不开 —— 按失败处理，但报**这一次**的原因：
          // 它比"本地没有"更接近真正的问题（文件损坏 / 版本不兼容）。
          debugPrint('[threads] 拉回后仍打不开 $threadId：$e2');
          if (_isStale(gen)) return;
          _onFailed(e2);
          return;
        }
      }

      // 服务器上也没有（或同步没开 / 云端模式）—— 打不开必须说，静默停在
      // 空会话上，用户会以为历史丢了。过时的失败不报（见类注释）。
      if (_isStale(gen)) return;
      _onFailed(e);
    }
  }

  /// 从服务器拉这一条会话，返回"有没有拉到东西"。
  ///
  /// ⚠️ **只在本地引擎下做**。云端模式的会话本来就在服务器上，
  /// `thread/resume` 读到的**就是**最新那份 —— 打不开就是真打不开，
  /// 把服务器文件下到本机既没用（引擎读的不是本机那份）又会误导。
  Future<bool> _pullFromServer(String threadId) async {
    if (_ports.engineMode != EngineMode.local) return false;
    return _ports.refreshThread(threadId);
  }

  /// 本地内容已经在屏幕上之后，问一下服务器这条会话有没有更新。
  ///
  /// **只在真的变了才重装**：重装会重建所有气泡、把滚动位置顶回去，
  /// 绝大多数情况下服务器没有新东西，无条件重装等于每次点开都白闪一下。
  /// **失败不管**：用户手上那份是完整的本地历史，没拉到更新不值得提示。
  Future<void> _refreshInBackground(String threadId, int gen) async {
    if (!await _pullFromServer(threadId)) return;
    if (_isStale(gen)) {
      debugPrint('[threads] $threadId 有更新，但用户已切走，不重装');
      return;
    }
    debugPrint('[threads] $threadId 从服务器拿到更新，重新装配');
    try {
      final replay = await _ports.threadRepository.open(threadId);
      if (_isStale(gen)) return; // 再查一次：取数期间也可能切走
      _onLoaded(threadId, replay);
    } catch (e) {
      // 已经显示着本地那份，重装失败就维持现状。
      debugPrint('[threads] $threadId 重装失败，保留本地内容：$e');
    }
  }
}
