import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/oauth_pending_store.dart';
import 'package:moe_social/utils/oauth_pkce.dart';

void main() {
  late InMemoryOauthSessionBackend backend;

  setUp(() {
    backend = InMemoryOauthSessionBackend();
    OauthPendingStore.useBackendForTest(backend);
  });

  tearDown(() => OauthPendingStore.useBackendForTest(null));

  OauthPendingAuth pending({
    String provider = 'feishu',
    String flow = '',
    String state = 'state-abc',
    DateTime? expiresAt,
  }) =>
      OauthPendingAuth(
        provider: provider,
        flow: flow,
        state: state,
        codeVerifier: 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk',
        returnUrl: 'https://app.example.com/login',
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 5)),
      );

  group('待处理授权事务', () {
    test('存取往返保留全部字段', () async {
      await OauthPendingStore.save(pending(flow: 'website'));
      final loaded = await OauthPendingStore.load('feishu');

      expect(loaded, isNotNull);
      expect(loaded!.provider, 'feishu');
      expect(loaded.flow, 'website');
      expect(loaded.state, 'state-abc');
      expect(loaded.codeVerifier, 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
      expect(loaded.returnUrl, 'https://app.example.com/login');
      expect(loaded.isExpired, isFalse);
    });

    test('verifier 是明文存不进去的：落地内容必须是可解析的 JSON', () async {
      await OauthPendingStore.save(pending());
      expect(backend.values.keys, hasLength(1));
      expect(backend.values.values.single, contains('code_verifier'));
    });

    test('写失败必须抛出来，让发起方中止授权', () async {
      // 这是「存储失败中止授权」的唯一保障点：静默降级的话用户会走完整个
      // 授权流程，回来才发现本地没有事务、换不出登录态。
      backend.failWrites = true;
      await expectLater(
        OauthPendingStore.save(pending()),
        throwsA(isA<StateError>()),
      );
    });

    test('同一 provider 的旧事务被覆盖', () async {
      await OauthPendingStore.save(pending(state: 'old'));
      await OauthPendingStore.save(pending(state: 'new'));

      final loaded = await OauthPendingStore.load('feishu');
      expect(loaded!.state, 'new');
      expect(backend.values, hasLength(1));
    });

    test('两个 provider 的事务互不遮蔽', () async {
      await OauthPendingStore.save(pending(provider: 'feishu', state: 'f1'));
      await OauthPendingStore.save(pending(provider: 'wechat', state: 'w1'));

      expect((await OauthPendingStore.load('feishu'))!.state, 'f1');
      expect((await OauthPendingStore.load('wechat'))!.state, 'w1');
    });

    test('没有事务时返回 null', () async {
      expect(await OauthPendingStore.load('feishu'), isNull);
    });

    test('过期事务被拒并清除', () async {
      await OauthPendingStore.save(
        pending(expiresAt: DateTime.now().subtract(const Duration(seconds: 1))),
      );

      expect(await OauthPendingStore.load('feishu'), isNull);
      expect(backend.values, isEmpty, reason: '过期记录应被顺手清掉');
    });

    test('损坏的记录被拒并清除，不抛异常', () async {
      // 升级后旧版本写下的记录读不出来是正常情况，应当当作「没有事务」，
      // 让用户重新发起授权，而不是让登录页崩在解析上。
      backend.values['moe_oauth_pending_feishu'] = '{not json';
      expect(await OauthPendingStore.load('feishu'), isNull);
      expect(backend.values, isEmpty);
    });

    test('记录里的 provider 与键不一致时拒绝', () async {
      backend.values['moe_oauth_pending_feishu'] =
          '{"provider":"wechat","state":"s","code_verifier":"v","expires_at":4102444800000}';
      expect(await OauthPendingStore.load('feishu'), isNull);
    });

    test('缺 state 或缺 verifier 的记录视为无效', () async {
      backend.values['moe_oauth_pending_feishu'] =
          '{"provider":"feishu","state":"","code_verifier":"v","expires_at":4102444800000}';
      expect(await OauthPendingStore.load('feishu'), isNull);

      backend.values['moe_oauth_pending_feishu'] =
          '{"provider":"feishu","state":"s","code_verifier":"","expires_at":4102444800000}';
      expect(await OauthPendingStore.load('feishu'), isNull);
    });
  });

  group('state 认领', () {
    test('state 匹配才交回事务', () async {
      await OauthPendingStore.save(pending(state: 'good'));

      expect(await OauthPendingStore.takeForState('feishu', 'good'), isNotNull);
      expect(await OauthPendingStore.takeForState('feishu', 'evil'), isNull);
    });

    test('空 state 一律拒绝', () async {
      await OauthPendingStore.save(pending(state: 'good'));
      expect(await OauthPendingStore.takeForState('feishu', ''), isNull);
      expect(await OauthPendingStore.takeForState('feishu', '   '), isNull);
    });

    test('跨 provider 的 state 不通用', () async {
      await OauthPendingStore.save(pending(provider: 'feishu', state: 'shared'));
      expect(await OauthPendingStore.takeForState('wechat', 'shared'), isNull);
    });

    test('认领后不清除，由调用方在登录请求发出后清除', () async {
      // 网络中断时 ticket 可能还没被服务端消费，留着记录才谈得上重试；
      // 是否清除由登录页在 finally 里决定。
      await OauthPendingStore.save(pending(state: 'good'));
      expect(await OauthPendingStore.takeForState('feishu', 'good'), isNotNull);
      expect(await OauthPendingStore.load('feishu'), isNotNull);

      await OauthPendingStore.clear('feishu');
      expect(await OauthPendingStore.load('feishu'), isNull);
    });
  });

  group('PKCE 配对不变量', () {
    // 客户端这一半：授权时发出去的 challenge，必须正是登录时出示的 verifier 的
    // SHA256。服务端那一半由 internal/biz/user 的用例钉住（拿 RFC 7636 附录 B
    // 的向量对做正反断言），两边共用同一个锚点，所以接缝不靠人工对齐。
    test('存进事务的 verifier 哈希后等于发出的 challenge', () async {
      final verifier = generateCodeVerifier();
      final challenge = s256CodeChallenge(verifier);

      await OauthPendingStore.save(
        OauthPendingAuth(
          provider: 'feishu',
          flow: '',
          state: 'server-state',
          codeVerifier: verifier,
          returnUrl: 'moesocial://feishu/oauth',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );

      final taken = await OauthPendingStore.takeForState('feishu', 'server-state');
      expect(taken, isNotNull);
      expect(s256CodeChallenge(taken!.codeVerifier), challenge);
    });

    test('别的 verifier 配不上本次 challenge', () async {
      final verifier = generateCodeVerifier();
      await OauthPendingStore.save(
        OauthPendingAuth(
          provider: 'feishu',
          flow: '',
          state: 'server-state',
          codeVerifier: verifier,
          returnUrl: 'moesocial://feishu/oauth',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      );

      final taken = await OauthPendingStore.takeForState('feishu', 'server-state');
      expect(
        s256CodeChallenge(taken!.codeVerifier),
        isNot(s256CodeChallenge(generateCodeVerifier())),
      );
    });
  });
}
