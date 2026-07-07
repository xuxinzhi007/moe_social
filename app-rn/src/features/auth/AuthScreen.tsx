import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  Animated,
  Easing,
  Linking,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from 'react-native';

import { ActionButton } from '../../components/ActionButton';
import { AuthInput } from '../../components/AuthInput';
import {
  checkEmailExists,
  getFeishuAuthorizeUrl,
  getWechatAuthorizeUrl,
  loginWithPassword,
  messageOf,
  registerWithPassword,
  resetPassword,
  sendResetCode,
  verifyResetCode,
} from '../../services/authService';
import { loadLastLoginAccount } from '../../services/tokenStorage';
import { useAppStore } from '../../store/appStore';
import { radii, spacing } from '../../theme/tokens';
import {
  emailDomainCompletionCandidates,
  validateAccount,
  validateConfirmPassword,
  validateEmail,
  validatePassword,
  validateUsername,
  validateVerifyCode,
} from '../../utils/validators';

type AuthMode = 'login' | 'register' | 'forgot' | 'verify' | 'reset';

const modeTitleMap: Record<AuthMode, string> = {
  login: '欢迎回来',
  register: '创建新账号',
  forgot: '找回账号',
  verify: '验证邮箱',
  reset: '设置新密码',
};

const modeCopyMap: Record<AuthMode, string> = {
  login: '支持邮箱、Moe 号或用户名登录，并自动记住上次成功登录的账号。',
  register: '注册成功后会直接登录，沿用当前后端的会话接口与 Moe 号下发逻辑。',
  forgot: '先确认邮箱存在，再发送验证码，流程和当前 Flutter 版本保持一致。',
  verify: '输入邮箱收到的 6 位验证码，验证完成后即可进入密码重置流程。',
  reset: '为当前账号设置新的登录密码，完成后将返回登录入口。',
};

const trustSignals = [
  { label: '已接入', value: '邮箱密码' },
  { label: '授权', value: '微信 / 飞书' },
  { label: '状态', value: '可继续迁移' },
];

export function AuthScreen() {
  const { apiClient, completeSession } = useAppStore();
  const { width, height } = useWindowDimensions();
  const blob = useRef(new Animated.Value(0)).current;
  const headerEnter = useRef(new Animated.Value(0)).current;
  const cardEnter = useRef(new Animated.Value(0)).current;

  const [mode, setMode] = useState<AuthMode>('login');
  const [loading, setLoading] = useState(false);
  const [notice, setNotice] = useState('');
  const [account, setAccount] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [verifyCodeValue, setVerifyCodeValue] = useState('');
  const [verifiedCode, setVerifiedCode] = useState('');
  const [attemptedSubmit, setAttemptedSubmit] = useState(false);
  const [emailSuggestions, setEmailSuggestions] = useState<string[]>([]);

  const isCompact = width < 430 || height < 900;
  const isSmallPhone = width <= 390 || height <= 844;
  const shouldCompactInput = isCompact;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(headerEnter, {
        toValue: 1,
        duration: 420,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.timing(cardEnter, {
        toValue: 1,
        duration: 560,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
    ]).start();

    Animated.loop(
      Animated.sequence([
        Animated.timing(blob, {
          toValue: 1,
          duration: 5200,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
        Animated.timing(blob, {
          toValue: 0,
          duration: 5200,
          easing: Easing.inOut(Easing.sin),
          useNativeDriver: true,
        }),
      ]),
    ).start();
  }, [blob, cardEnter, headerEnter]);

  useEffect(() => {
    loadLastLoginAccount()
      .then((lastAccount) => {
        if (lastAccount) {
          setAccount(lastAccount);
        }
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    setAttemptedSubmit(false);
    setNotice('');
    setEmailSuggestions([]);
  }, [mode]);

  useEffect(() => {
    if (mode !== 'login' && mode !== 'register' && mode !== 'forgot') {
      return;
    }

    const seed = mode === 'login' ? account : email;
    setEmailSuggestions(emailDomainCompletionCandidates(seed));
  }, [account, email, mode]);

  const errors = useMemo(() => {
    if (mode === 'login') {
      return {
        account: validateAccount(account),
        password: validatePassword(password),
      };
    }

    if (mode === 'register') {
      return {
        username: validateUsername(username),
        email: validateEmail(email),
        password: validatePassword(password),
        confirmPassword: validateConfirmPassword(confirmPassword, password),
      };
    }

    if (mode === 'forgot') {
      return {
        email: validateEmail(email),
      };
    }

    if (mode === 'verify') {
      return {
        verifyCode: validateVerifyCode(verifyCodeValue),
      };
    }

    return {
      password: validatePassword(password),
      confirmPassword: validateConfirmPassword(confirmPassword, password),
    };
  }, [account, confirmPassword, email, mode, password, username, verifyCodeValue]);

  function fieldError(value: string, error?: string) {
    if (!error) {
      return undefined;
    }

    if (attemptedSubmit || value.trim().length > 0) {
      return error;
    }

    return undefined;
  }

  function syncEmailForReset(value: string) {
    const normalized = value.trim().toLowerCase();
    setEmail(normalized);
    return normalized;
  }

  async function submitLogin() {
    setAttemptedSubmit(true);
    if (errors.account || errors.password) {
      return;
    }

    setLoading(true);
    setNotice('');
    try {
      const session = await loginWithPassword(apiClient, account, password);
      await completeSession(session, account.trim());
    } catch (error) {
      setNotice(messageOf(error));
    } finally {
      setLoading(false);
    }
  }

  async function submitRegister() {
    setAttemptedSubmit(true);
    if (errors.username || errors.email || errors.password || errors.confirmPassword) {
      return;
    }

    setLoading(true);
    setNotice('');
    try {
      const result = await registerWithPassword(apiClient, username, email, password);
      if (result.moeNo) {
        Alert.alert('注册成功', `你的 Moe 号是 ${result.moeNo}`);
      }
      await completeSession(result.session, email.trim().toLowerCase());
    } catch (error) {
      setNotice(messageOf(error));
    } finally {
      setLoading(false);
    }
  }

  async function submitForgot() {
    setAttemptedSubmit(true);
    if (errors.email) {
      return;
    }

    setLoading(true);
    setNotice('');
    try {
      const normalizedEmail = syncEmailForReset(email);
      await checkEmailExists(apiClient, normalizedEmail);
      await sendResetCode(apiClient, normalizedEmail);
      setNotice('验证码已发送，请查收邮箱并输入 6 位验证码。');
      setMode('verify');
    } catch (error) {
      setNotice(messageOf(error));
    } finally {
      setLoading(false);
    }
  }

  async function submitVerify() {
    setAttemptedSubmit(true);
    if (errors.verifyCode) {
      return;
    }

    setLoading(true);
    setNotice('');
    try {
      await verifyResetCode(apiClient, email, verifyCodeValue);
      setVerifiedCode(verifyCodeValue.trim());
      setNotice('验证码校验成功，请设置一个新的登录密码。');
      setMode('reset');
    } catch (error) {
      setNotice(messageOf(error));
    } finally {
      setLoading(false);
    }
  }

  async function submitReset() {
    setAttemptedSubmit(true);
    if (errors.password || errors.confirmPassword) {
      return;
    }

    setLoading(true);
    setNotice('');
    try {
      await resetPassword(apiClient, email, verifiedCode, password);
      setNotice('密码已重置，请使用新密码重新登录。');
      setPassword('');
      setConfirmPassword('');
      setVerifyCodeValue('');
      setVerifiedCode('');
      setMode('login');
    } catch (error) {
      setNotice(messageOf(error));
    } finally {
      setLoading(false);
    }
  }

  async function openWechatLogin() {
    try {
      const url = await getWechatAuthorizeUrl(apiClient);
      await Linking.openURL(url);
      setNotice('已打开微信授权页面。当前 RN 版先走浏览器授权，后续再补原生回跳。');
    } catch (error) {
      setNotice(messageOf(error));
    }
  }

  async function openFeishuLogin() {
    try {
      const url = await getFeishuAuthorizeUrl(apiClient);
      await Linking.openURL(url);
      setNotice('已打开飞书授权页面。当前 RN 版先走浏览器授权，后续再补原生回跳。');
    } catch (error) {
      setNotice(messageOf(error));
    }
  }

  function selectSuggestion(value: string) {
    if (mode === 'login') {
      setAccount(value);
    } else {
      setEmail(value);
    }
    setEmailSuggestions([]);
  }

  function modePillLabel() {
    if (mode === 'verify' || mode === 'reset') {
      return '找回流程';
    }
    if (mode === 'register') {
      return '新用户入口';
    }
    return '账号登录';
  }

  function renderFooter() {
    if (mode === 'login') {
      return (
        <View style={styles.footerRow}>
          <Text style={styles.footerMuted}>还没有账号？</Text>
          <Pressable onPress={() => setMode('register')}>
            <Text style={styles.footerLink}>立即注册</Text>
          </Pressable>
        </View>
      );
    }

    if (mode === 'register') {
      return (
        <View style={styles.footerRow}>
          <Text style={styles.footerMuted}>已经有账号了？</Text>
          <Pressable onPress={() => setMode('login')}>
            <Text style={styles.footerLink}>返回登录</Text>
          </Pressable>
        </View>
      );
    }

    return (
      <View style={styles.footerRow}>
        <Text style={styles.footerMuted}>想起密码了？</Text>
        <Pressable onPress={() => setMode('login')}>
          <Text style={styles.footerLink}>返回登录</Text>
        </Pressable>
      </View>
    );
  }

  function renderModeTabs() {
    const tabs: Array<{ key: AuthMode; label: string }> = [
      { key: 'login', label: '登录' },
      { key: 'register', label: '注册' },
      { key: 'forgot', label: '找回' },
    ];

    return (
      <View style={styles.tabs}>
        {tabs.map((tab) => {
          const active = tab.key === mode || (tab.key === 'forgot' && (mode === 'verify' || mode === 'reset'));
          return (
            <Pressable
              key={tab.key}
              onPress={() => setMode(tab.key)}
              style={[styles.tab, active ? styles.tabActive : null]}
            >
              <Text style={[styles.tabText, active ? styles.tabTextActive : null]}>{tab.label}</Text>
            </Pressable>
          );
        })}
      </View>
    );
  }

  function renderSocialActions() {
    if (mode !== 'login' && mode !== 'register') {
      return null;
    }

    return (
      <View style={styles.socialWrap}>
        <Text style={styles.socialHint}>也可以继续使用微信或飞书账号进入 Moe Social</Text>
        <View style={styles.socialActions}>
          <Pressable
            onPress={() => void openWechatLogin()}
            style={({ pressed }) => [styles.socialCard, styles.socialWechat, pressed ? styles.pressed : null]}
          >
            <Text style={styles.socialTag}>WeChat</Text>
            <Text style={styles.socialTitle}>微信登录 / 注册</Text>
            <Text style={styles.socialCopy}>适合延续现有社交关系与移动端授权路径。</Text>
          </Pressable>
          <Pressable
            onPress={() => void openFeishuLogin()}
            style={({ pressed }) => [styles.socialCard, styles.socialFeishu, pressed ? styles.pressed : null]}
          >
            <Text style={styles.socialTag}>Feishu</Text>
            <Text style={styles.socialTitle}>飞书登录 / 注册</Text>
            <Text style={styles.socialCopy}>适合企业协作、内测用户和绑定工作身份。</Text>
          </Pressable>
        </View>
      </View>
    );
  }

  function renderSuggestions() {
    if (!emailSuggestions.length || (mode !== 'login' && mode !== 'register' && mode !== 'forgot')) {
      return null;
    }

    return (
      <View style={styles.suggestionWrap}>
        {emailSuggestions.map((item) => (
          <Pressable
            key={item}
            onPress={() => selectSuggestion(item)}
            style={({ pressed }) => [styles.suggestionChip, pressed ? styles.pressed : null]}
          >
            <Text style={styles.suggestionText}>{item}</Text>
          </Pressable>
        ))}
      </View>
    );
  }

  function renderProgressRail() {
    const steps = ['账号', '验证', '重置'];
    const activeIndex = mode === 'verify' ? 1 : mode === 'reset' ? 2 : 0;

    return (
      <View style={styles.progressRail}>
        {steps.map((step, index) => (
          <View key={step} style={styles.progressItem}>
            <View style={[styles.progressDot, index <= activeIndex ? styles.progressDotActive : null]} />
            <Text style={[styles.progressLabel, index <= activeIndex ? styles.progressLabelActive : null]}>
              {step}
            </Text>
          </View>
        ))}
      </View>
    );
  }

  const blobLeftX = blob.interpolate({
    inputRange: [0, 1],
    outputRange: [-16, 20],
  });

  const blobLeftY = blob.interpolate({
    inputRange: [0, 1],
    outputRange: [-20, 18],
  });

  const blobRightY = blob.interpolate({
    inputRange: [0, 1],
    outputRange: [18, -16],
  });

  const blobBottomX = blob.interpolate({
    inputRange: [0, 1],
    outputRange: [-12, 10],
  });

  const headerTranslateY = headerEnter.interpolate({
    inputRange: [0, 1],
    outputRange: [18, 0],
  });

  const cardTranslateY = cardEnter.interpolate({
    inputRange: [0, 1],
    outputRange: [24, 0],
  });

  return (
    <View style={styles.page}>
      <Animated.View
        style={[
          styles.blob,
          styles.blobLeft,
          { transform: [{ translateX: blobLeftX }, { translateY: blobLeftY }] },
        ]}
      />
      <Animated.View
        style={[
          styles.blob,
          styles.blobRight,
          { transform: [{ translateY: blobRightY }] },
        ]}
      />
      <Animated.View
        style={[
          styles.blob,
          styles.blobBottom,
          { transform: [{ translateX: blobBottomX }] },
        ]}
      />

      <ScrollView
        contentContainerStyle={[styles.scrollContent, isCompact ? styles.scrollContentCompact : null]}
        showsVerticalScrollIndicator={false}
      >
        <Animated.View
          style={[
            styles.hero,
            isSmallPhone ? styles.heroCompact : null,
            { opacity: headerEnter, transform: [{ translateY: headerTranslateY }] },
          ]}
        >
          <View style={[styles.heroBadgeShell, isSmallPhone ? styles.heroBadgeShellCompact : null]}>
            <View style={[styles.heroBadge, isSmallPhone ? styles.heroBadgeCompact : null]}>
              <Text style={[styles.heroBadgeText, isSmallPhone ? styles.heroBadgeTextCompact : null]}>MS</Text>
            </View>
          </View>
          <View style={styles.heroTextWrap}>
            <Text style={[styles.heroEyebrow, isSmallPhone ? styles.heroEyebrowCompact : null]}>
              NEXT GEN AUTH EXPERIENCE
            </Text>
            <Text style={[styles.heroTitle, isSmallPhone ? styles.heroTitleCompact : null]}>Moe Social</Text>
            <Text style={[styles.heroSubtitle, isSmallPhone ? styles.heroSubtitleCompact : null]}>
              先把账号门面做完整，再把后面的首页、聊天和 AI 世界一点点迁稳。
            </Text>
          </View>
        </Animated.View>

        <Animated.View
          style={[
            styles.cardWrap,
            { opacity: cardEnter, transform: [{ translateY: cardTranslateY }] },
          ]}
        >
          <View style={[styles.authCard, isCompact ? styles.authCardCompact : null]}>
            <View style={styles.cardTop}>
              <View style={styles.brandMini}>
                <View style={styles.brandMiniBadge}>
                  <Text style={styles.brandMiniBadgeText}>MS</Text>
                </View>
                <View style={styles.brandMiniTextWrap}>
                  <Text style={styles.brandMiniTitle}>Moe Social</Text>
                  <Text style={styles.brandMiniSubtitle}>更完整的账号体系，从这里重新接回来</Text>
                </View>
                <View style={styles.modePill}>
                  <Text style={styles.modePillText}>{modePillLabel()}</Text>
                </View>
              </View>
              {renderModeTabs()}
            </View>

            {mode === 'verify' || mode === 'reset' ? renderProgressRail() : null}

            <View style={styles.headingBlock}>
              <Text style={[styles.headline, isCompact ? styles.headlineCompact : null]}>{modeTitleMap[mode]}</Text>
              <Text style={[styles.copy, isCompact ? styles.copyCompact : null]}>
                {mode === 'verify' && email
                  ? `验证码已发送到 ${email}，请输入 6 位验证码继续。`
                  : mode === 'reset' && email
                    ? `正在为 ${email} 设置新的登录密码。`
                    : modeCopyMap[mode]}
              </Text>
            </View>

            <View style={[styles.featureStrip, isCompact ? styles.featureStripCompact : null]}>
              <View style={styles.featureItemAccent}>
                <Text style={styles.featureLabel}>上次账号</Text>
                <Text style={styles.featureValue}>{account.trim() || '未记录'}</Text>
              </View>
              {trustSignals.map((item) => (
                <View key={item.label} style={styles.featureItem}>
                  <Text style={styles.featureLabel}>{item.label}</Text>
                  <Text style={styles.featureValue}>{item.value}</Text>
                </View>
              ))}
            </View>

            <View style={[styles.form, isCompact ? styles.formCompact : null]}>
              {mode === 'login' ? (
                <>
                  <AuthInput
                    label="账号"
                    placeholder="请输入邮箱、Moe 号或用户名"
                    value={account}
                    onChangeText={setAccount}
                    error={fieldError(account, errors.account)}
                    returnKeyType="next"
                    compact={shouldCompactInput}
                  />
                  {renderSuggestions()}
                  <AuthInput
                    label="密码"
                    placeholder="请输入密码"
                    value={password}
                    onChangeText={setPassword}
                    secureTextEntry
                    error={fieldError(password, errors.password)}
                    returnKeyType="done"
                    compact={shouldCompactInput}
                  />
                  <Pressable onPress={() => setMode('forgot')}>
                    <Text style={styles.inlineLink}>忘记密码？</Text>
                  </Pressable>
                  <ActionButton label={loading ? '登录中...' : '登录'} onPress={() => void submitLogin()} />
                </>
              ) : null}

              {mode === 'register' ? (
                <>
                  <AuthInput
                    label="用户名"
                    placeholder="请输入用户名"
                    value={username}
                    onChangeText={setUsername}
                    autoCapitalize="none"
                    error={fieldError(username, errors.username)}
                    returnKeyType="next"
                    compact={shouldCompactInput}
                  />
                  <AuthInput
                    label="邮箱"
                    placeholder="请输入邮箱"
                    value={email}
                    onChangeText={setEmail}
                    keyboardType="email-address"
                    error={fieldError(email, errors.email)}
                    returnKeyType="next"
                    compact={shouldCompactInput}
                  />
                  {renderSuggestions()}
                  <AuthInput
                    label="密码"
                    placeholder="至少 6 位"
                    value={password}
                    onChangeText={setPassword}
                    secureTextEntry
                    error={fieldError(password, errors.password)}
                    returnKeyType="next"
                    compact={shouldCompactInput}
                  />
                  <AuthInput
                    label="确认密码"
                    placeholder="请再次输入密码"
                    value={confirmPassword}
                    onChangeText={setConfirmPassword}
                    secureTextEntry
                    error={fieldError(confirmPassword, errors.confirmPassword)}
                    returnKeyType="done"
                    compact={shouldCompactInput}
                  />
                  <ActionButton label={loading ? '注册中...' : '立即注册'} onPress={() => void submitRegister()} />
                </>
              ) : null}

              {mode === 'forgot' ? (
                <>
                  <AuthInput
                    label="邮箱"
                    placeholder="请输入注册邮箱"
                    value={email}
                    onChangeText={setEmail}
                    keyboardType="email-address"
                    error={fieldError(email, errors.email)}
                    returnKeyType="done"
                    compact={shouldCompactInput}
                  />
                  {renderSuggestions()}
                  <ActionButton label={loading ? '发送中...' : '发送验证码'} onPress={() => void submitForgot()} />
                </>
              ) : null}

              {mode === 'verify' ? (
                <>
                  <AuthInput
                    label="验证码"
                    placeholder="请输入 6 位验证码"
                    value={verifyCodeValue}
                    onChangeText={setVerifyCodeValue}
                    keyboardType="number-pad"
                    error={fieldError(verifyCodeValue, errors.verifyCode)}
                    returnKeyType="done"
                    compact={shouldCompactInput}
                  />
                  <View style={styles.inlineActions}>
                    <ActionButton label={loading ? '验证中...' : '验证邮箱'} onPress={() => void submitVerify()} />
                    <ActionButton label="重新发送" onPress={() => void submitForgot()} secondary />
                  </View>
                </>
              ) : null}

              {mode === 'reset' ? (
                <>
                  <AuthInput
                    label="新密码"
                    placeholder="请输入新密码"
                    value={password}
                    onChangeText={setPassword}
                    secureTextEntry
                    error={fieldError(password, errors.password)}
                    returnKeyType="next"
                    compact={shouldCompactInput}
                  />
                  <AuthInput
                    label="确认密码"
                    placeholder="请再次输入新密码"
                    value={confirmPassword}
                    onChangeText={setConfirmPassword}
                    secureTextEntry
                    error={fieldError(confirmPassword, errors.confirmPassword)}
                    returnKeyType="done"
                    compact={shouldCompactInput}
                  />
                  <ActionButton label={loading ? '提交中...' : '确认重置'} onPress={() => void submitReset()} />
                </>
              ) : null}
            </View>

            {notice ? (
              <View style={styles.notice}>
                <Text style={styles.noticeText}>{notice}</Text>
              </View>
            ) : null}

            {renderSocialActions()}
            {renderFooter()}
          </View>
        </Animated.View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  page: {
    flex: 1,
    backgroundColor: '#FDF9F4',
  },
  scrollContent: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: 18,
    paddingTop: 24,
    paddingBottom: 28,
  },
  scrollContentCompact: {
    justifyContent: 'flex-start',
    paddingTop: 16,
    paddingBottom: 18,
  },
  blob: {
    position: 'absolute',
    borderRadius: 999,
  },
  blobLeft: {
    top: -90,
    left: -90,
    width: 340,
    height: 340,
    backgroundColor: 'rgba(255, 198, 176, 0.42)',
  },
  blobRight: {
    top: 210,
    right: -72,
    width: 250,
    height: 250,
    backgroundColor: 'rgba(255, 225, 161, 0.30)',
  },
  blobBottom: {
    left: -88,
    bottom: -84,
    width: 250,
    height: 250,
    backgroundColor: 'rgba(182, 222, 243, 0.42)',
  },
  hero: {
    alignItems: 'center',
    gap: 14,
    marginBottom: 18,
  },
  heroCompact: {
    gap: 10,
    marginBottom: 12,
  },
  heroBadgeShell: {
    padding: 12,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.74)',
    shadowColor: '#9E7256',
    shadowOpacity: 0.16,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 10 },
  },
  heroBadgeShellCompact: {
    padding: 9,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
  },
  heroBadge: {
    width: 84,
    height: 84,
    borderRadius: 42,
    backgroundColor: '#FFF7F2',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(238, 172, 143, 0.18)',
  },
  heroBadgeCompact: {
    width: 64,
    height: 64,
    borderRadius: 32,
  },
  heroBadgeText: {
    color: '#D66F4D',
    fontWeight: '900',
    fontSize: 30,
  },
  heroBadgeTextCompact: {
    fontSize: 24,
  },
  heroTextWrap: {
    alignItems: 'center',
    gap: 6,
  },
  heroEyebrow: {
    color: '#C97C5D',
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
  },
  heroEyebrowCompact: {
    fontSize: 10,
  },
  heroTitle: {
    color: '#30241E',
    fontSize: 36,
    fontWeight: '900',
    letterSpacing: 0.3,
  },
  heroTitleCompact: {
    fontSize: 30,
  },
  heroSubtitle: {
    color: '#856B60',
    fontSize: 14,
    textAlign: 'center',
    lineHeight: 21,
    paddingHorizontal: 10,
  },
  heroSubtitleCompact: {
    fontSize: 12,
    lineHeight: 18,
    paddingHorizontal: 18,
  },
  cardWrap: {
    width: '100%',
    maxWidth: 560,
    alignSelf: 'center',
  },
  authCard: {
    backgroundColor: 'rgba(255,255,255,0.96)',
    borderRadius: 34,
    padding: 18,
    gap: 16,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.84)',
    shadowColor: '#D8A081',
    shadowOpacity: 0.16,
    shadowRadius: 24,
    shadowOffset: { width: 0, height: 12 },
  },
  authCardCompact: {
    borderRadius: 28,
    padding: 16,
    gap: 14,
  },
  cardTop: {
    gap: 12,
  },
  brandMini: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  brandMiniBadge: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: '#FFF1E8',
    alignItems: 'center',
    justifyContent: 'center',
  },
  brandMiniBadgeText: {
    color: '#D7724B',
    fontWeight: '900',
    fontSize: 18,
  },
  brandMiniTextWrap: {
    flex: 1,
    gap: 2,
  },
  brandMiniTitle: {
    color: '#303042',
    fontSize: 16,
    fontWeight: '800',
  },
  brandMiniSubtitle: {
    color: '#9A7B6D',
    fontSize: 12,
  },
  modePill: {
    borderRadius: 999,
    backgroundColor: '#FFF5EE',
    paddingHorizontal: 10,
    paddingVertical: 7,
  },
  modePillText: {
    color: '#B16A49',
    fontSize: 11,
    fontWeight: '800',
  },
  tabs: {
    flexDirection: 'row',
    gap: 6,
    padding: 4,
    borderRadius: 999,
    backgroundColor: '#F8EDE5',
  },
  tab: {
    flex: 1,
    minHeight: 40,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabActive: {
    backgroundColor: '#FFFFFF',
    shadowColor: '#EAC2A8',
    shadowOpacity: 0.28,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
  },
  tabText: {
    color: '#AB8F83',
    fontWeight: '800',
    fontSize: 15,
  },
  tabTextActive: {
    color: '#3C2E28',
  },
  progressRail: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: spacing.sm,
  },
  progressItem: {
    flex: 1,
    alignItems: 'center',
    gap: 6,
  },
  progressDot: {
    width: '100%',
    height: 6,
    borderRadius: 999,
    backgroundColor: '#F1DDD0',
  },
  progressDotActive: {
    backgroundColor: '#D86F4A',
  },
  progressLabel: {
    color: '#B08B79',
    fontSize: 11,
    fontWeight: '700',
  },
  progressLabelActive: {
    color: '#A95E40',
  },
  headingBlock: {
    gap: 6,
  },
  headline: {
    color: '#332821',
    fontWeight: '900',
    fontSize: 27,
  },
  headlineCompact: {
    fontSize: 23,
  },
  copy: {
    color: '#8A7469',
    fontSize: 14,
    lineHeight: 20,
  },
  copyCompact: {
    fontSize: 13,
    lineHeight: 18,
  },
  featureStrip: {
    flexDirection: 'row',
    gap: 10,
    padding: 12,
    borderRadius: 22,
    backgroundColor: '#FFF6EF',
  },
  featureStripCompact: {
    flexDirection: 'column',
  },
  featureItem: {
    flex: 1,
    gap: 2,
  },
  featureItemAccent: {
    flex: 1.2,
    gap: 2,
  },
  featureLabel: {
    color: '#B08B79',
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  featureValue: {
    color: '#4A352C',
    fontSize: 13,
    fontWeight: '800',
  },
  form: {
    gap: 14,
  },
  formCompact: {
    gap: 10,
  },
  suggestionWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: -4,
  },
  suggestionChip: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 999,
    backgroundColor: '#FFF4EA',
    borderWidth: 1,
    borderColor: '#F4D9C8',
  },
  suggestionText: {
    color: '#A46E55',
    fontSize: 12,
    fontWeight: '700',
  },
  inlineLink: {
    alignSelf: 'flex-end',
    color: '#D06E48',
    fontSize: 13,
    fontWeight: '700',
    marginTop: -2,
  },
  socialWrap: {
    gap: 10,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: '#F1E2D7',
  },
  socialHint: {
    color: '#9D8479',
    fontSize: 12,
    textAlign: 'center',
  },
  socialActions: {
    gap: 10,
  },
  socialCard: {
    borderRadius: 24,
    padding: 14,
    borderWidth: 1,
    gap: 6,
    backgroundColor: 'rgba(255,255,255,0.98)',
  },
  socialWechat: {
    borderColor: 'rgba(18, 194, 100, 0.24)',
  },
  socialFeishu: {
    borderColor: 'rgba(46, 108, 255, 0.24)',
  },
  socialTag: {
    color: '#A38B80',
    fontSize: 11,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  socialTitle: {
    color: '#342821',
    fontSize: 15,
    fontWeight: '800',
  },
  socialCopy: {
    color: '#8A7469',
    fontSize: 12,
    lineHeight: 18,
  },
  inlineActions: {
    gap: spacing.sm,
  },
  notice: {
    backgroundColor: '#FFF7F1',
    borderRadius: radii.md,
    borderWidth: 1,
    borderColor: '#F3D8C7',
    padding: 10,
  },
  noticeText: {
    color: '#6B5145',
    fontSize: 13,
    lineHeight: 18,
  },
  footerRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 6,
    paddingTop: 2,
  },
  footerMuted: {
    color: '#A38B80',
    fontSize: 13,
  },
  footerLink: {
    color: '#D06E48',
    fontSize: 13,
    fontWeight: '800',
  },
  pressed: {
    opacity: 0.92,
  },
});
